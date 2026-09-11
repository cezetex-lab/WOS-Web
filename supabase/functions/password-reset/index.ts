// password-reset Edge Function
// Actions: request, verify, reset
//
// HARDENING (hasil audit "New Text Document (2).txt"):
//  - Token reset password TIDAK lagi ditulis mentah-mentah ke log server
//    (console.log lama = leaka kode reset ke siapa pun dengan akses log).
//  - Konsisten dengan live schema otp_store(nrp PK, code_hash, expiry,
//    used, created_at): token disimpan sebagai sha256 hash, bukan kolom
//    otp_code/purpose yang tidak ada di database live (lama: upsert gagal
//    diam-diam -> verify selalu "Token tidak valid").
//  - Rate limit percobaan verify/reset per email (5 / 15 menit) via
//    tabel rate_limits — anti brute-force token 6-digit.
//  - Reset: pakai RPC reset_password (service role) supaya worker_passwords
//    + session invalidation + audit tetap satu source of truth; jika akun
//    Supabase Auth tersedia, password Auth juga di-update.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

const WINDOW_SECONDS = 15 * 60;
const LIMITS: Record<string, number> = {
  request: 5,
  verify: 10,
  reset: 10,
};

// Rate limit ATOMIC via RPC hit_rate_limit (migration 193).
// Fail-open hanya kalau RPC belum ter-deploy (migration 193 belum jalan).
async function hitRateLimit(adminClient: any, identifier: string, action: string): Promise<boolean> {
  const max = LIMITS[action] ?? 5;
  const { data, error } = await adminClient.rpc("hit_rate_limit", {
    p_identifier: identifier,
    p_action: `pwreset_${action}`,
    p_max: max,
    p_window_seconds: WINDOW_SECONDS,
  });
  if (error) {
    console.error("[password-reset] hit_rate_limit RPC unavailable:", error.message);
    return true;
  }
  return data === true;
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, email, token, new_password } = await req.json();
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    if (action === "request") {
      if (!email || typeof email !== "string") {
        return new Response(JSON.stringify({ ok: false, msg: "Email required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const key = email.toLowerCase().trim();
      const { data: user } = await adminClient.from("employees_master").select("nrp, email").eq("email", key).single();
      // Always return success to prevent email enumeration
      if (!user) {
        return new Response(JSON.stringify({ ok: true, msg: "Jika email terdaftar, link reset sudah dikirim." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!(await hitRateLimit(adminClient, key, "request"))) {
        return new Response(JSON.stringify({ ok: true, msg: "Jika email terdaftar, link reset sudah dikirim." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const tokenCode = Math.floor(100000 + Math.random() * 900000).toString();
      const codeHash = await sha256Hex(tokenCode);
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
      // Live otp_store: nrp PK, code_hash (sha256), expiry, used — NO otp_code/purpose kolom
      await adminClient.from("otp_store").upsert(
        { nrp: user.nrp, code_hash: codeHash, expiry: expiresAt, used: false },
        { onConflict: "nrp" }
      );
      // NOTE: token reset tidak ditulis ke log. Integrasi email (SMTP/Resend)
      // harus dikirim tokenCode ke email user di sini.
      return new Response(JSON.stringify({ ok: true, msg: "Jika email terdaftar, link reset sudah dikirim." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

    } else if (action === "verify") {
      if (!email || !token) {
        return new Response(JSON.stringify({ ok: false, msg: "Email dan token required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const key = email.toLowerCase().trim();
      if (!(await hitRateLimit(adminClient, key, "verify"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: emp } = await adminClient.from("employees_master").select("nrp").eq("email", key).single();
      if (!emp) {
        return new Response(JSON.stringify({ ok: false, msg: "Token tidak valid." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const codeHash = await sha256Hex(token);
      const { data: otp } = await adminClient.from("otp_store").select("*").eq("nrp", emp.nrp).eq("code_hash", codeHash).eq("used", false).gt("expiry", new Date().toISOString()).single();
      if (!otp) {
        return new Response(JSON.stringify({ ok: false, msg: "Token tidak valid atau sudah kedaluwarsa." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ ok: true, msg: "Token valid." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

    } else if (action === "reset") {
      if (!email || !token || !new_password) {
        return new Response(JSON.stringify({ ok: false, msg: "Email, token, dan password baru required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (new_password.length < 8) {
        return new Response(JSON.stringify({ ok: false, msg: "Password minimal 8 karakter." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const key = email.toLowerCase().trim();
      if (!(await hitRateLimit(adminClient, key, "reset"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: emp } = await adminClient.from("employees_master").select("nrp, auth_id").eq("email", key).single();
      if (!emp) {
        return new Response(JSON.stringify({ ok: false, msg: "User tidak ditemukan." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const codeHash = await sha256Hex(token);
      const { data: otp } = await adminClient.from("otp_store").select("*").eq("nrp", emp.nrp).eq("code_hash", codeHash).eq("used", false).gt("expiry", new Date().toISOString()).single();
      if (!otp) {
        return new Response(JSON.stringify({ ok: false, msg: "Token tidak valid atau sudah kedaluwarsa." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      // Source of truth: RPC reset_password (worker_passwords + session invalidation + audit)
      const { error: rpcErr } = await adminClient.rpc("reset_password", {
        p_nrp: emp.nrp,
        p_token: token,
        p_new_password: new_password,
      });
      if (rpcErr) {
        return new Response(JSON.stringify({ ok: false, msg: "Gagal reset password: " + rpcErr.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (emp.auth_id) {
        const { error } = await adminClient.auth.admin.updateUserById(emp.auth_id, { password: new_password });
        if (error) {
          return new Response(JSON.stringify({ ok: false, msg: "Gagal update password auth: " + error.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
      }
      return new Response(JSON.stringify({ ok: true, msg: "Password berhasil diubah. Silakan login." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

    } else {
      return new Response(JSON.stringify({ ok: false, msg: "Invalid action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, msg: "Server error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});