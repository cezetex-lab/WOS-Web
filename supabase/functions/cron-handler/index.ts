// ============================================================
// cron-handler — Supabase Edge Function
// Handles scheduled tasks: KPI calc, early detection, etc.
// ============================================================
// Deploy: supabase functions deploy cron-handler
// Schedule: Via pg_cron or external cron service
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const { task, params } = await req.json();

    // Verify cron secret
    const cronSecret = req.headers.get("x-cron-secret");
    if (cronSecret !== Deno.env.get("CRON_SECRET")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    let result;

    switch (task) {
      // ── KPI BULANAN ──
      case "calculate_monthly_kpi": {
        const { data, error } = await supabase.rpc("calculate_monthly_kpi", {
          p_period: params?.period || new Date().toISOString().slice(0, 7),
        });
        if (error) throw error;
        result = { task: "calculate_monthly_kpi", result: data };
        break;
      }

      // ── DETEKSI DINI HARIAN ──
      case "run_early_detection": {
        const { data, error } = await supabase.rpc("run_early_detection");
        if (error) throw error;
        result = { task: "run_early_detection", result: data };
        break;
      }

      // ── AUTO-HEALING ──
      case "run_auto_healing": {
        const { data, error } = await supabase.rpc("run_auto_healing");
        if (error) throw error;
        result = { task: "run_auto_healing", result: data };
        break;
      }

      // ── PKWT EXPIRY CHECK ──
      case "check_pkwt_expiry": {
        const { data, error } = await supabase.rpc("check_pkwt_expiry", {
          p_days_before: params?.days_before || 90,
        });
        if (error) throw error;
        result = { task: "check_pkwt_expiry", result: data };
        break;
      }

      // ── ATTENDANCE SUMMARY ──
      case "generate_attendance_summary": {
        const { data, error } = await supabase.rpc("generate_attendance_summary", {
          p_date: params?.date || new Date().toISOString().slice(0, 10),
        });
        if (error) throw error;
        result = { task: "generate_attendance_summary", result: data };
        break;
      }

      // ── HEALTH SCORE ──
      case "calculate_health_score": {
        const { data, error } = await supabase.rpc("calculate_workforce_health");
        if (error) throw error;
        result = { task: "calculate_health_score", result: data };
        break;
      }

      default:
        return new Response(JSON.stringify({ error: `Unknown task: ${task}` }), { status: 400 });
    }

    // Log execution
    await supabase.from("cron_log").insert({
      task,
      params: params || {},
      result,
      executed_at: new Date().toISOString(),
      status: "success",
    });

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    // Log error
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    await supabase.from("cron_log").insert({
      task: "unknown",
      error: error.message,
      executed_at: new Date().toISOString(),
      status: "error",
    });

    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
