// ============================================================
// mfa-service - TOTP MFA Edge Function
// ============================================================
// Actions: check, enroll, verify_activate, verify_login, disable
// ============================================================
// HARDENING (hasil audit "New Text Document (2).txt"):
//  - enroll / verify_activate / disable: butuh Supabase Auth JWT dari
//    user yang LOGIN, dan auth.uid() tersebut harus cocok dengan NRP
//    yang di-target. Ini menutup account-takeover via NRP sembarangan
//    (celah lama: siapa pun dapat enroll/disable MFA NRP lain).
//  - verify_login (pre-login, tidak punya JWT): rate-limit STRICT
//    (5 percobaan / 15 menit per NRP) via tabel rate_limits —
//    brute-force 1:1.000.000 kode TOTP jadi tidak praktikal.
//  - check: rate-limit longgar (60 / 15 menit per NRP).
// ============================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const WINDOW_SECONDS = 15 * 60;
const LIMITS: Record<string, number> = {
  check: 60,
  enroll: 5,
  verify_activate: 10,
  verify_login: 5,
  disable: 5,
};

// Rate limit ATOMIC via RPC hit_rate_limit (migration 193):
// INSERT ... ON CONFLICT DO UPDATE WHERE count < max dalam satu statement —
// tidak ada race baca-modif-tulis antara concurrent requests.
// Fail-open hanya kalau RPC itu sendiri tidak ada (deployment lama).
async function hitRateLimit(supabase: any, identifier: string, action: string): Promise<boolean> {
  const max = LIMITS[action] ?? 5;
  const { data, error } = await supabase.rpc("hit_rate_limit", {
    p_identifier: identifier,
    p_action: action,
    p_max: max,
    p_window_seconds: WINDOW_SECONDS,
  });
  if (error) {
    // RPC belum ter-deploy (migration 193 belum jalan) -> fail-open,
    // tapi log supaya terlihat di dashboard Supabase.
    console.error("[mfa-service] hit_rate_limit RPC unavailable:", error.message);
    return true;
  }
  return data === true;
}

// Verifikasi pemanggil = pemilik NRP: JWT user auth.uid() harus map ke
// employees_master.auth_id dengan nrp === p_nrp. Anon key / JWT lain -> false.
async function assertOwner(supabase: any, req: Request, nrp: string): Promise<boolean> {
  const auth = req.headers.get("Authorization") || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return false;
  const { data: userData, error } = await supabase.auth.getUser(token);
  if (error || !userData?.user) return false;
  const { data: emp, error: empErr } = await supabase
    .from("employees_master")
    .select("nrp")
    .eq("auth_id", userData.user.id)
    .maybeSingle();
  if (empErr || !emp) return false;
  return emp.nrp === nrp;
}

// TOTP Helpers (RFC 6238)

function base32Decode(input: string): Uint8Array {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const cleaned = input.replace(/[=\s]/g, "").toUpperCase();
  let bits = "";
  for (const c of cleaned) {
    const val = alphabet.indexOf(c);
    if (val === -1) continue;
    bits += val.toString(2).padStart(5, "0");
  }
  const bytes = new Uint8Array(Math.floor(bits.length / 8));
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(bits.substr(i * 8, 8), 2);
  }
  return bytes;
}

async function hmacSha1(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw", key, { name: "HMAC", hash: "SHA-1" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, data);
  return new Uint8Array(sig);
}

async function generateTOTP(secret: string): Promise<string> {
  const counter = Math.floor(Date.now() / 1000 / 30);
  const counterBytes = new Uint8Array(8);
  let tmp = counter;
  for (let i = 7; i >= 0; i--) { counterBytes[i] = tmp & 0xff; tmp = Math.floor(tmp / 256); }
  const keyBytes = base32Decode(secret);
  const hmac = await hmacSha1(keyBytes, counterBytes);
  const offset = hmac[hmac.length - 1] & 0x0f;
  const binary = (((hmac[offset] & 0x7f) << 24) | ((hmac[offset+1] & 0xff) << 16) | ((hmac[offset+2] & 0xff) << 8) | (hmac[offset+3] & 0xff)) % 1000000;
  return binary.toString().padStart(6, "0");
}

async function verifyTOTP(secret: string, code: string): Promise<boolean> {
  const counter = Math.floor(Date.now() / 1000 / 30);
  for (let i = -1; i <= 1; i++) {
    const counterBytes = new Uint8Array(8);
    let tmp = counter + i;
    for (let j = 7; j >= 0; j--) { counterBytes[j] = tmp & 0xff; tmp = Math.floor(tmp / 256); }
    const keyBytes = base32Decode(secret);
    const hmac = await hmacSha1(keyBytes, counterBytes);
    const offset = hmac[hmac.length - 1] & 0x0f;
    const binary = (((hmac[offset] & 0x7f) << 24) | ((hmac[offset+1] & 0xff) << 16) | ((hmac[offset+2] & 0xff) << 8) | (hmac[offset+3] & 0xff)) % 1000000;
    if (binary.toString().padStart(6, "0") === code) return true;
  }
  return false;
}

function randomHex(bytes: number): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(bytes))).map(b => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { action, nrp, factor_id, code, label } = await req.json();
    const h = { ...corsHeaders, "Content-Type": "application/json" };

    if (!nrp || typeof nrp !== "string") {
      return new Response(JSON.stringify({ ok: false, msg: "nrp wajib diisi" }), { status: 400, headers: h });
    }

    if (action === "check") {
      if (!(await hitRateLimit(supabase, nrp, "check"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak request. Coba lagi nanti." }), { status: 429, headers: h });
      }
      const { data } = await supabase.from("mfa_factors").select("id,enabled,verified_at,label").eq("nrp", nrp).eq("enabled", true).limit(1).single();
      return new Response(JSON.stringify({ ok: true, mfa_enabled: !!data, factor_id: data?.id || null, label: data?.label || null }), { headers: h });
    }

    if (action === "enroll") {
      if (!(await assertOwner(supabase, req, nrp))) {
        return new Response(JSON.stringify({ ok: false, msg: "Unauthorized: JWT tidak cocok dengan NRP." }), { status: 401, headers: h });
      }
      if (!(await hitRateLimit(supabase, nrp, "enroll"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak request. Coba lagi nanti." }), { status: 429, headers: h });
      }
      const { data: ex } = await supabase.from("mfa_factors").select("id").eq("nrp", nrp).eq("enabled", true).limit(1);
      if (ex && ex.length > 0) return new Response(JSON.stringify({ ok: false, msg: "MFA sudah aktif." }), { headers: h });
      const secretBytes = crypto.getRandomValues(new Uint8Array(20));
      const al = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
      let bits = ""; for (const b of secretBytes) bits += b.toString(2).padStart(8, "0");
      let secret = ""; for (let i = 0; i + 5 <= bits.length; i += 5) secret += al[parseInt(bits.substr(i, 5), 2)];
      const fid = randomHex(8);
      const url = "otpauth://totp/insightWOS:" + nrp + "?secret=" + secret + "&issuer=insightWOS&algorithm=SHA1&digits=6&period=30";
      await supabase.from("mfa_factors").delete().eq("nrp", nrp).eq("enabled", false);
      const { error } = await supabase.from("mfa_factors").insert({ id: fid, nrp, secret, issuer: "insightWOS", label: label || "insightWOS", enabled: false });
      if (error) throw error;
      return new Response(JSON.stringify({ ok: true, factor_id: fid, secret, otpauth_url: url, msg: "Scan QR code lalu verifikasi kode TOTP" }), { headers: h });
    }

    if (action === "verify_activate") {
      if (!(await assertOwner(supabase, req, nrp))) {
        return new Response(JSON.stringify({ ok: false, msg: "Unauthorized: JWT tidak cocok dengan NRP." }), { status: 401, headers: h });
      }
      if (!(await hitRateLimit(supabase, nrp, "verify_activate"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: h });
      }
      const { data: factor } = await supabase.from("mfa_factors").select("*").eq("id", factor_id).eq("nrp", nrp).eq("enabled", false).single();
      if (!factor) return new Response(JSON.stringify({ ok: false, msg: "Factor tidak ditemukan." }), { headers: h });
      if (!(await verifyTOTP(factor.secret, code))) return new Response(JSON.stringify({ ok: false, msg: "Kode TOTP salah." }), { headers: h });
      await supabase.from("mfa_factors").update({ enabled: true, verified_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq("id", factor_id);
      return new Response(JSON.stringify({ ok: true, msg: "MFA berhasil diaktifkan!", enabled: true }), { headers: h });
    }

    if (action === "verify_login") {
      // Pre-login: tidak ada JWT user — proteksi via rate limit strict
      if (!(await hitRateLimit(supabase, nrp, "verify_login"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Akun dikunci 15 menit." }), { status: 429, headers: h });
      }
      const { data: factor } = await supabase.from("mfa_factors").select("secret").eq("nrp", nrp).eq("enabled", true).limit(1).single();
      if (!factor) return new Response(JSON.stringify({ ok: true, mfa_required: false }), { headers: h });
      if (!(await verifyTOTP(factor.secret, code))) return new Response(JSON.stringify({ ok: false, msg: "Kode TOTP salah." }), { headers: h });
      return new Response(JSON.stringify({ ok: true, mfa_required: true, mfa_verified: true }), { headers: h });
    }

    if (action === "disable") {
      if (!(await assertOwner(supabase, req, nrp))) {
        return new Response(JSON.stringify({ ok: false, msg: "Unauthorized: JWT tidak cocok dengan NRP." }), { status: 401, headers: h });
      }
      if (!(await hitRateLimit(supabase, nrp, "disable"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: h });
      }
      const { data: factor } = await supabase.from("mfa_factors").select("secret").eq("nrp", nrp).eq("enabled", true).limit(1).single();
      if (!factor) return new Response(JSON.stringify({ ok: false, msg: "MFA tidak aktif." }), { headers: h });
      if (!(await verifyTOTP(factor.secret, code))) return new Response(JSON.stringify({ ok: false, msg: "Kode TOTP salah." }), { headers: h });
      await supabase.from("mfa_factors").update({ enabled: false, updated_at: new Date().toISOString() }).eq("nrp", nrp).eq("enabled", true);
      return new Response(JSON.stringify({ ok: true, msg: "MFA berhasil dinonaktifkan." }), { headers: h });
    }

    return new Response(JSON.stringify({ ok: false, msg: "Unknown action" }), { status: 400, headers: h });
  } catch (e: any) {
    return new Response(JSON.stringify({ ok: false, msg: e.message || "Error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});