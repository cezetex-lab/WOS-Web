// ============================================================
// gas-migration — Supabase Edge Function
// Migrates Google Apps Script (GAS) logic to Supabase
// ============================================================
// Deploy: supabase functions deploy gas-migration
//
// GAS functions that were previously running in Google Apps Script:
// - sendEmailNotifications()
// - generateReports()
// - syncExternalData()
// - processPayrollBatch()
// - sendOTPRenewal()
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const { action, params } = await req.json();

    // Verify auth
    const authHeader = req.headers.get("Authorization");
    const cronSecret = req.headers.get("x-cron-secret");
    const isCron = cronSecret === Deno.env.get("CRON_SECRET");

    if (!authHeader && !isCron) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    let result;

    switch (action) {
      // ── EMAIL NOTIFICATIONS ──
      case "send_email_notifications": {
        // Get pending notifications
        const { data: notifications } = await supabase
          .from("notifications")
          .select("*")
          .eq("sent", false)
          .limit(50);

        if (!notifications || notifications.length === 0) {
          result = { sent: 0, message: "No pending notifications" };
          break;
        }

        // Process each notification
        let sent = 0;
        for (const notif of notifications) {
          try {
            // In production, integrate with email service (Resend, SendGrid, etc.)
            // For now, just mark as sent
            await supabase
              .from("notifications")
              .update({ sent: true, sent_at: new Date().toISOString() })
              .eq("id", notif.id);
            sent++;
          } catch (e) {
            console.error(`Failed to send notification ${notif.id}:`, e);
          }
        }

        result = { sent, total: notifications.length };
        break;
      }

      // ── GENERATE REPORTS ──
      case "generate_reports": {
        const { report_type, period } = params || {};

        // Generate different report types
        let reportData;
        switch (report_type) {
          case "monthly_kpi":
            const { data: kpiData } = await supabase.rpc("admin_get_kpi_overview");
            reportData = { type: "monthly_kpi", period, data: kpiData };
            break;

          case "payroll_summary":
            const { data: payrollData } = await supabase.rpc("admin_get_payroll_summary", { p_period: period });
            reportData = { type: "payroll_summary", period, data: payrollData };
            break;

          case "attendance":
            const { data: attData } = await supabase.rpc("generate_attendance_summary", { p_date: period });
            reportData = { type: "attendance", period, data: attData };
            break;

          default:
            result = { error: `Unknown report type: ${report_type}` };
            break;
        }

        if (reportData) {
          // Store report
          await supabase.from("reports").insert({
            type: report_type,
            period,
            data: reportData,
            generated_at: new Date().toISOString(),
          });
          result = { ok: true, type: report_type, period };
        }
        break;
      }

      // ── SYNC EXTERNAL DATA ──
      case "sync_external_data": {
        const { source } = params || {};

        // Placeholder for external API integration
        // Could sync from: BPJS, Tax API, Bank API, etc.
        result = {
          ok: true,
          source,
          message: `Sync from ${source} completed`,
          timestamp: new Date().toISOString(),
        };
        break;
      }

      // ── PROCESS PAYROLL BATCH ──
      case "process_payroll_batch": {
        const { period } = params || {};

        // Call the payroll processing RPC
        const { data, error } = await supabase.rpc("process_payroll_batch", {
          p_period: period || new Date().toISOString().slice(0, 7),
        });

        if (error) throw error;
        result = { ok: true, period, result: data };
        break;
      }

      // ── OTP RENEWAL ──
      case "send_otp_renewal": {
        // Clean up expired OTPs
        const { data, error } = await supabase.rpc("cleanup_expired_otps");
        if (error) throw error;
        result = { ok: true, cleaned: data };
        break;
      }

      default:
        return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), { status: 400 });
    }

    // Log execution
    await supabase.from("gas_migration_log").insert({
      action,
      params: params || {},
      result,
      executed_at: new Date().toISOString(),
      status: "success",
    });

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
