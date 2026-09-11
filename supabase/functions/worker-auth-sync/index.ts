// ============================================================
// worker-auth-sync — Provision Supabase Auth account for a worker
// ============================================================
// ROOT CAUSE: login_worker() hanya menerbitkan RPC-token dan tidak pernah
// membuat akun di auth.users → auth.uid() selalu NULL → authz/RLS menolak.
//
// v2 PATCHED:
//  1. Email anchor SELALU sintetis {nrp}@insightwos.internal — satu sumber,
//     konsisten dengan fast path di Home.jsx.
//  2. UPDATE auth_id ke employees_core (BASE TABLE), BUKAN view
//     employees_master yang non-updatable.
//  3. Jika auth_id sudah ada: ambil email asli akun auth via admin,
//     rotate password, kembalikan email itu (bukan menebak dari employee).
//  4. Jika belum: createUser dengan email sintetis saja (tanpa loop candidates).
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

    // 3a. Akun auth sudah ada → rotate password, pakai email asli akun auth
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

      const { error: rotErr } = await supabase.auth.admin.updateUserById(emp.auth_id, {
        password: tempPassword,
      });
      if (rotErr) {
        return json({ ok: false, msg: "Gagal rotasi password auth: " + rotErr.message }, 500);
      }

      return json({
        ok: true,
        email: authEmail,
        temp_password: tempPassword,
        auth_id: emp.auth_id,
      });
    }

    // 3b. Belum ada → create dengan email SINTETIS (satu-satunya kandidat)
    const { data: created, error: createErr } = await supabase.auth.admin.createUser({
      email: syntheticEmail,
      password: tempPassword,
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

    return json({
      ok: true,
      email: syntheticEmail,
      temp_password: tempPassword,
      auth_id: authUserId,
    });
  } catch (err) {
    return json({ ok: false, msg: (err instanceof Error ? err.message : "Server error") }, 500);
  }
});
