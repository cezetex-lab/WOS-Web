// password-reset Edge Function
// Actions: request, verify, reset

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

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
      const { data: user } = await adminClient.from("employees_master").select("nrp, email").eq("email", email.toLowerCase().trim()).single();
      // Always return success to prevent email enumeration
      if (!user) {
        return new Response(JSON.stringify({ ok: true, msg: "Jika email terdaftar, link reset sudah dikirim." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const tokenCode = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
      await adminClient.from("otp_store").upsert({ nrp: user.nrp, otp_code: tokenCode, purpose: "password_reset", expires_at: expiresAt, used: false }, { onConflict: "nrp,purpose" });
      console.log("[PASSWORD-RESET] Token for " + email + ": " + tokenCode);
      return new Response(JSON.stringify({ ok: true, msg: "Jika email terdaftar, link reset sudah dikirim." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

    } else if (action === "verify") {
      if (!email || !token) {
        return new Response(JSON.stringify({ ok: false, msg: "Email dan token required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: emp } = await adminClient.from("employees_master").select("nrp").eq("email", email.toLowerCase().trim()).single();
      if (!emp) {
        return new Response(JSON.stringify({ ok: false, msg: "Token tidak valid." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: otp } = await adminClient.from("otp_store").select("*").eq("nrp", emp.nrp).eq("otp_code", token).eq("purpose", "password_reset").eq("used", false).gt("expires_at", new Date().toISOString()).single();
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
      const { data: emp } = await adminClient.from("employees_master").select("nrp, auth_id").eq("email", email.toLowerCase().trim()).single();
      if (!emp) {
        return new Response(JSON.stringify({ ok: false, msg: "User tidak ditemukan." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: otp } = await adminClient.from("otp_store").select("*").eq("nrp", emp.nrp).eq("otp_code", token).eq("purpose", "password_reset").eq("used", false).gt("expires_at", new Date().toISOString()).single();
      if (!otp) {
        return new Response(JSON.stringify({ ok: false, msg: "Token tidak valid atau sudah kedaluwarsa." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (emp.auth_id) {
        const { error } = await adminClient.auth.admin.updateUserById(emp.auth_id, { password: new_password });
        if (error) {
          return new Response(JSON.stringify({ ok: false, msg: "Gagal update password: " + error.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
      }
      await adminClient.from("otp_store").update({ used: true }).eq("nrp", emp.nrp).eq("purpose", "password_reset");
      return new Response(JSON.stringify({ ok: true, msg: "Password berhasil diubah. Silakan login." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

    } else {
      return new Response(JSON.stringify({ ok: false, msg: "Invalid action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, msg: "Server error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
