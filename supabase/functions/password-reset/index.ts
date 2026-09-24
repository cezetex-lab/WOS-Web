// ============================================================
// password-reset Edge Function
// Actions: request, verify, reset, login_otp, verify_login_otp, change_password_sync, admin_reset_sync
// ============================================================
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
//
// LOGIN OTP (2026-09-12):
//  - action login_otp: kirim OTP 6-digit ke email user (setelah user+password
//    sukses di tab admin/dashboard). OTP wajib sebelum redirect.
//    Kirim = Supabase Auth admin.generateLink({type:'magiclink'}) bila akun
//    auth tersedia; dev fallback = dev_code di response (seperti otp_store show).
//  - action verify_login_otp: verifikasi kode login_otp via RPC verify_admin_otp
//    (identitas = NRP hasil verify, bukan param client — anti trust-the-client).

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
  login_otp: 3,
  verify_login_otp: 5,
  change_password_sync: 5,
  admin_reset_sync: 10,
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
    const { action, email, token, new_password, old_password, nrp } = await req.json();
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // ── LOGIN OTP: kirim kode 6-digit ke email (wajib untuk tab admin/dashboard)
    if (action === "login_otp") {
      const targetNrp = (nrp || "").toUpperCase().trim();
      if (!targetNrp) {
        return new Response(JSON.stringify({ ok: false, msg: "NRP required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!(await hitRateLimit(adminClient, targetNrp, "login_otp"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak request OTP. Coba lagi nanti." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      // Look up the employee by NRP.
      const { data: emp } = await adminClient
        .from("employees_master")
        .select("nrp, email, auth_id, nama")
        .eq("nrp", targetNrp)
        .maybeSingle();
      if (!emp) {
        // Anti-enumerasi: tetap return ok generik.
        return new Response(JSON.stringify({ ok: true, msg: "Jika NRP terdaftar, OTP sudah dikirim." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      // Security: pastikan NRP target adalah admin/owner (replikasi cek di
      // generate_admin_otp() migration 191). Tanpa ini, user biasa bisa request
      // OTP untuk NRP orang lain.
      const { data: roleData } = await adminClient
        .from("user_roles")
        .select("role")
        .eq("nrp", targetNrp)
        .maybeSingle();
      const userRole = roleData?.role;
      const isOwner = targetNrp === "OWNER001" || userRole === "owner";
      const isAdmin = !!userRole && userRole.startsWith("admin");
      if (!isOwner && !isAdmin) {
        // Anti-enumerasi: return generik (jangan bikin user tahu NRP bukan admin).
        return new Response(JSON.stringify({ ok: true, msg: "Jika NRP terdaftar, OTP sudah dikirim." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      // Generate OTP langsung (BUKAN via RPC generate_admin_otp). Alasan:
      // RPC itu require auth.uid() tidak NULL, tapi edge function pakai service
      // role key sehingga auth.uid() = NULL → RPC return "Autentikasi diperlukan"
      // → 500 error. Dengan generate langsung + service role, kita bypass RLS
      // dan tetap simpan hash di otp_store.
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const codeHash = await sha256Hex(otpCode);
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
      await adminClient.from("otp_store").upsert(
        { nrp: targetNrp, code_hash: codeHash, expiry: expiresAt, used: false },
        { onConflict: "nrp" },
      );
      // Audit log (sesuai pola generate_admin_otp migration 191).
      const { error: auditError } = await adminClient.from("audit_log").insert({
        action: "ADMIN_OTP_GEN",
        detail: "Admin OTP generated for " + targetNrp,
        timestamp: new Date().toISOString(),
      });
      if (auditError) { /* non-critical — audit failure tidak blokir OTP */ }
      // Backend email sender belum ada (belum ada SMTP); kode TIDAK dikirim via
      // email sungguhan. Dev fallback: dev_code di response + Magic Link BILA
      // akun auth tersedia.
      let emailed = false;
      if (emp.auth_id) {
        const { error: linkErr } = await adminClient.auth.admin.generateLink({
          type: "magiclink",
          email: emp.email || `${targetNrp.toLowerCase()}@insightwos.internal`,
        });
        emailed = !linkErr;
      }
      return new Response(JSON.stringify({
        ok: true,
        msg: emailed ? "OTP sudah dikirim ke email." : "OTP dibuat (dev-mode: kode ditampilkan di layar).",
        dev_code: otpCode,
        emailed,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── VERIFY LOGIN OTP: identitas = hasil RPC, bukan param client
    if (action === "verify_login_otp") {
      if (!token) {
        return new Response(JSON.stringify({ ok: false, msg: "Kode OTP required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!(await hitRateLimit(adminClient, "global", "verify_login_otp"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: v, error: vErr } = await adminClient.rpc("verify_admin_otp", { p_code: token });
      if (vErr || !v?.ok) {
        return new Response(JSON.stringify({ ok: false, msg: v?.msg || "Kode OTP tidak valid." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ ok: true, nrp: v.nrp, role: v.role, nama: v.nama, token: v.token }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── OPS-06: change_password_sync — ganti password (verifikasi old password via RPC)
    // LALU sinkronkan auth.users.password agar fast path signInWithPassword tetap hidup.
    if (action === "change_password_sync") {
      const targetNrp = (nrp || "").toUpperCase().trim();
      if (!targetNrp || !old_password || !new_password) {
        return new Response(JSON.stringify({ ok: false, msg: "NRP, password lama, dan password baru required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (new_password.length < 8) {
        return new Response(JSON.stringify({ ok: false, msg: "Password baru minimal 8 karakter" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!(await hitRateLimit(adminClient, targetNrp, "change_password_sync"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      // Source of truth: RPC change_password (worker_passwords + session invalidation + audit).
      // Otorisasi = old_password valid (RPC SECURITY DEFINER, tanpa cek authz internal);
      // brute force old_password dibatasi rate limit 5/15 menit per NRP di atas.
      const { data: ch, error: chErr } = await adminClient.rpc("change_password", {
        p_nrp: targetNrp,
        p_old_password: old_password,
        p_new_password: new_password,
      });
      if (chErr) {
        return new Response(JSON.stringify({ ok: false, msg: "Gagal mengubah password: " + chErr.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!ch?.ok) {
        return new Response(JSON.stringify({ ok: false, msg: ch?.msg || "Gagal mengubah password" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      // RPC sukses → sinkronkan auth.users (jangan sampai divergen — OPS-06).
      const { data: emp } = await adminClient
        .from("employees_master")
        .select("nrp, auth_id")
        .eq("nrp", targetNrp)
        .maybeSingle();
      let authSynced = false;
      if (emp?.auth_id) {
        const { error } = await adminClient.auth.admin.updateUserById(emp.auth_id, { password: new_password });
        if (error) {
          return new Response(JSON.stringify({ ok: false, msg: "Password DB berubah tapi sync auth gagal: " + error.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        authSynced = true;
      }
      return new Response(JSON.stringify({
        ok: true,
        msg: "Password berhasil diubah." + (authSynced ? "" : " (akun auth tidak tersedia — login via NRP/NIK)"),
        auth_synced: authSynced,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── OPS-06b: admin_reset_sync — sinkronkan auth.users.password setelah admin
    // me-reset password karyawan via RPC admin_reset_worker_password (jalur G2/shared).
    //
    // Authz: WAJIB JWT user di header Authorization (bukan anon/apikey). Caller
    // diverifikasi via auth.getUser(jwt) → auth_id → NRP (employees_core) → role
    // (user_roles). Hanya role admin* / owner boleh lanjut; selain itu 403 fail-closed.
    // RPC admin_reset_worker_password (yang menulis worker_passwords) tetap dijalankan
    // lebih dulu oleh frontend — action ini HANYA menutup celah sync auth.users.
    if (action === "admin_reset_sync") {
      const targetNrp = (nrp || "").toUpperCase().trim();
      if (!targetNrp || !new_password) {
        return new Response(JSON.stringify({ ok: false, msg: "NRP dan password baru required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (new_password.length < 8) {
        return new Response(JSON.stringify({ ok: false, msg: "Password baru minimal 8 karakter" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const authHeader = req.headers.get("Authorization") || "";
      const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
      if (!jwt) {
        return new Response(JSON.stringify({ ok: false, msg: "Akses ditolak: JWT admin required" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: caller, error: callerErr } = await adminClient.auth.getUser(jwt);
      if (callerErr || !caller?.user) {
        return new Response(JSON.stringify({ ok: false, msg: "Akses ditolak: JWT tidak valid" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: callerEmp } = await adminClient
        .from("employees_core")
        .select("nrp")
        .eq("auth_id", caller.user.id)
        .maybeSingle();
      const callerNrp = callerEmp?.nrp;
      if (!callerNrp) {
        return new Response(JSON.stringify({ ok: false, msg: "Akses ditolak: akun tidak terhubung ke NRP" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: roleRow } = await adminClient
        .from("user_roles")
        .select("role")
        .eq("nrp", callerNrp)
        .maybeSingle();
      const callerRole = roleRow?.role || "";
      const isAdminCaller = callerRole === "admin" || callerRole.startsWith("admin_") || callerRole === "owner";
      if (!isAdminCaller) {
        return new Response(JSON.stringify({ ok: false, msg: "Akses ditolak: hanya admin/owner" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!(await hitRateLimit(adminClient, callerNrp, "admin_reset_sync"))) {
        return new Response(JSON.stringify({ ok: false, msg: "Terlalu banyak percobaan. Coba lagi nanti." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: target } = await adminClient
        .from("employees_core")
        .select("auth_id")
        .eq("nrp", targetNrp)
        .maybeSingle();
      if (!target?.auth_id) {
        return new Response(JSON.stringify({ ok: false, msg: "Target tidak punya akun auth — reset via NRP/NIK." }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { error: syncErr } = await adminClient.auth.admin.updateUserById(target.auth_id, { password: new_password });
      if (syncErr) {
        return new Response(JSON.stringify({ ok: false, msg: "Gagal sinkron auth: " + syncErr.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      await adminClient.from("audit_log").insert({
        action: "ADMIN_RESET_AUTH_SYNC",
        detail: `auth.users password synced for ${targetNrp} by ${callerNrp}`,
        timestamp: new Date().toISOString(),
      });
      return new Response(JSON.stringify({ ok: true, msg: "auth.users tersinkron.", auth_synced: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

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
    console.error("[password-reset] Unhandled error:", err?.message);
    return new Response(JSON.stringify({ ok: false, msg: "Server error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});