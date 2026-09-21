// ============================================================
// worker-auth-sync — Provision Supabase Auth account for a worker
// ============================================================
// ROOT CAUSE: login_worker() hanya menerbitkan RPC-token dan tidak pernah
// membuat akun di auth.users → auth.uid() selalu NULL → authz/RLS menolak.
//
// v3 (OPS-04, 2026-09-21) — SELF-REPAIR, BUKAN ROTASI ACAK:
//  1. Email anchor SELALU sintetis {nrp}@insightwos.internal — satu sumber,
//     konsisten dengan fast path di Home.tsx.
//  2. UPDATE auth_id ke employees_core (BASE TABLE), BUKAN view
//     employees_master yang non-updatable.
//  3. auth_id SUDAH ada → coba `mintSession(authEmail, password_user)` DULU.
//     Sukses = TIDAK menulis apa pun (jalur normal, tanpa cabut sesi). Gagal =
//     DIVERGEN → baru `updateUserById({ password_user })` (password itu sudah
//     diverifikasi `login_worker` di atas, jadi body tetap tidak dipercaya) lalu mint ulang.
//     v2 SEBELUMNYA selalu merotasi ke `randomPassword()` yang tidak diketahui siapa pun
//     → `auth.users.password` divergen permanen dari `worker_passwords` → fast path
//     `signInWithPassword` mati selamanya + setiap login wajib lewat edge (10–13 s)
//     yang di-abort klien pada 5 s → itulah OPS-04.
//  4. Bila GoTrue MENOLAK password user (kebijakan password lemah), fallback ke
//     perilaku v2 (rotasi ke password internal acak) supaya login tetap berhasil.
//  5. Akun baru (belum ada auth_id) dibuat LANGSUNG dengan password user → sinkron
//     sejak lahir. Pola ini sama dengan edge `password-reset`. Audit S6 tetap utuh:
//     password plaintext TIDAK PERNAH dikembalikan ke client — hanya SESI.
//  6. Terverifikasi (probe 2026-09-21): `updateUserById({password})` mencabut SEMUA
//     sesi akun itu (access 403 session_not_found, refresh 400 refresh_token_not_found).
//     Karena itu repair hanya dijalankan saat memang perlu → maksimal 1× per akun divergen.
// ============================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function randomPassword(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
  let out = "";
  for (const b of bytes) {
    out += alphabet[b % alphabet.length];
  }
  return out;
}

// Client anon terpisah: HANYA dipakai untuk menukar kredensial auth menjadi sesi.
// Password internal tidak pernah dikembalikan ke client (audit S6).
function authClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!
  );
}

async function mintSession(email: string, password: string) {
  const { data, error } = await authClient().auth.signInWithPassword({ email, password });
  if (error || !data?.session) return null;
  return {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const body = await req.json().catch(() => ({}));
    const { nrp, nik, password } = body;

    if (!nrp || !nik || !password) {
      return json({ ok: false, msg: "nrp, nik, dan password wajib diisi" }, 400);
    }

    // 1. Verifikasi ulang kredensial via login_worker — jangan percaya body
    const { data: login, error: loginErr } = await supabase.rpc("login_worker", {
      p_nrp: nrp,
      p_nik: nik,
      p_password: password,
    });
    if (loginErr || !login?.ok) {
      return json({ ok: false, msg: "Kredensial tidak valid." }, 401);
    }

    // 2. Baca employee (view employees_master BOLEH dibaca)
    const { data: emp, error: empErr } = await supabase
      .from("employees_master")
      .select("nrp, email, auth_id, nama")
      .eq("nrp", nrp)
      .single();
    if (empErr || !emp) {
      return json({ ok: false, msg: "Employee tidak ditemukan." }, 404);
    }

    const tempPassword = randomPassword();
    const syntheticEmail = `${String(nrp).toLowerCase().trim()}@insightwos.internal`;

    // 3a. Akun auth sudah ada → SINKRONKAN ke password user (self-repair), bukan rotasi acak.
    // Pakai email asli akun auth (bukan menebak dari employee).
    if (emp.auth_id) {
      const { data: existingUser, error: getErr } =
        await supabase.auth.admin.getUserById(emp.auth_id);
      if (getErr || !existingUser?.user) {
        return json({ ok: false, msg: "Auth user tidak ditemukan." }, 404);
      }

      const authEmail = existingUser.user.email;
      if (!authEmail) {
        return json({ ok: false, msg: "Auth user tidak punya email." }, 500);
      }

      // 3a-1. Jalur NORMAL: password auth sudah sinkron dengan password worker
      // (kombinasi sama dengan fast path di Home.tsx) → sukses tanpa menulis apa pun.
      const direct = await mintSession(authEmail, password);
      if (direct) {
        return json({
          ok: true,
          email: authEmail,
          auth_id: emp.auth_id,
          session: direct,
        });
      }

      // 3a-2. DIVERGEN (bekas rotasi acak v2 / change_password /
      // admin_reset_worker_password) → sinkronkan ke password yang SUDAH diverifikasi
      // login_worker. Catatan: GoTrue mencabut semua sesi akun ini saat password
      // berubah (probe 2026-09-21) — konsekuensi yang diterima, sekali per akun.
      const { error: syncErr } = await supabase.auth.admin.updateUserById(emp.auth_id, {
        password,
      });
      if (!syncErr) {
        console.log(
          `[worker-auth-sync] repair auth password utk ${nrp} (auth_id ${emp.auth_id}) — sesi lama akun ini dicabut`,
        );
        const session = await mintSession(authEmail, password);
        if (!session) {
          return json({ ok: false, msg: "Gagal menukar sesi auth setelah sinkron password." }, 500);
        }
        return json({
          ok: true,
          email: authEmail,
          auth_id: emp.auth_id,
          session,
        });
      }

      // 3a-3. Fallback: GoTrue menolak password user (mis. kebijakan password lemah)
      // → pertahankan perilaku v2 (rotasi internal acak) supaya login tetap berhasil.
      console.log(
        `[worker-auth-sync] sinkron password auth GAGAL utk ${nrp}: ${syncErr.message} → fallback rotasi internal`,
      );
      const { error: rotErr } = await supabase.auth.admin.updateUserById(emp.auth_id, {
        password: tempPassword,
      });
      if (rotErr) {
        return json({ ok: false, msg: "Gagal rotasi password auth: " + rotErr.message }, 500);
      }

      const session = await mintSession(authEmail, tempPassword);
      if (!session) {
        return json({ ok: false, msg: "Gagal menukar sesi auth." }, 500);
      }

      return json({
        ok: true,
        email: authEmail,
        auth_id: emp.auth_id,
        session,
      });
    }

    // 3b. Belum ada → create dengan email SINTETIS + **password user** (sinkron sejak lahir)
    const { data: created, error: createErr } = await supabase.auth.admin.createUser({
      email: syntheticEmail,
      password,
      email_confirm: true,
      user_metadata: { nrp: emp.nrp, nama: emp.nama },
    });
    if (createErr || !created?.user) {
      const msg = createErr?.message || "tidak diketahui";
      return json({ ok: false, msg: "Gagal provisioning akun auth: " + msg }, 409);
    }

    const authUserId = created.user.id;

    // 4. Link auth_id ke BASE TABLE employees_core (bukan view)
    const { error: updErr } = await supabase
      .from("employees_core")
      .update({ auth_id: authUserId })
      .eq("nrp", nrp);
    if (updErr) {
      return json({ ok: false, msg: "Gagal link auth_id: " + updErr.message }, 500);
    }

    const session = await mintSession(syntheticEmail, tempPassword);
    if (!session) {
      return json({ ok: false, msg: "Gagal menukar sesi auth." }, 500);
    }

    return json({
      ok: true,
      email: syntheticEmail,
      auth_id: authUserId,
      session,
    });
  } catch (err) {
    return json({ ok: false, msg: (err instanceof Error ? err.message : "Server error") }, 500);
  }
});
