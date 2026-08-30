// ============================================================
// AI Copilot — Google Gemini (Interactions API) + Template Fallback
// New endpoint: /v1beta/interactions (not generateContent)
// ============================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message, conversationHistory = [], context = "general" } = await req.json();

    if (!message || typeof message !== "string") {
      return new Response(
        JSON.stringify({ error: "message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const geminiKey = Deno.env.get("GEMINI_API_KEY") || "";

    const supabase = createClient(supabaseUrl, supabaseKey);

    // ── Step 1: Fetch relevant data from database ──
    const dbData = await fetchDatabaseData(supabase, message, context);

    // ── Step 2: Fetch relevant policy documents ──
    const docs = await fetchRelevantDocs(supabase, message, context);

    // ── Step 3: Try Gemini AI (with fallback to template) ──
    let assistantMessage = "";
    let usedAI = false;

    if (geminiKey) {
      const systemPrompt = buildSystemPrompt(dbData, docs);
      assistantMessage = await callGemini(geminiKey, systemPrompt, message, conversationHistory);
      if (assistantMessage && !assistantMessage.startsWith("__FALLBACK__")) {
        usedAI = true;
      } else {
        assistantMessage = assistantMessage.replace("__FALLBACK__", "");
      }
    }

    // ── Step 4: Template fallback (always works, no API needed) ──
    if (!usedAI) {
      assistantMessage = generateTemplateResponse(message, dbData, docs, context);
    }

    // ── Step 5: Log ──
    try {
      await supabase.from("ai_conversations").insert({
        user_message: message,
        assistant_message: assistantMessage,
        context,
        tokens_used: 0,
        documents_used: docs.length,
      }).catch(() => {});
    } catch (_e) { /* ignore */ }

    // ── Step 6: Return ──
    return new Response(
      JSON.stringify({
        message: assistantMessage,
        sources: docs.map((d: any) => ({ title: d.title, similarity: 1.0 })),
        usedAI,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("AI Copilot error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ══════════════════════════════════════════════════════════
// GEMINI — New Interactions API (not generateContent)
// ══════════════════════════════════════════════════════════
async function callGemini(
  apiKey: string,
  systemPrompt: string,
  message: string,
  history: any[]
): Promise<string> {
  // Build full prompt with history
  let fullInput = systemPrompt + "\n\nPertanyaan: " + message;

  if (history.length > 0) {
    const historyText = history.slice(-6).map((m: any) =>
      `${m.role === "assistant" ? "Assistant" : "User"}: ${m.content}`
    ).join("\n");
    fullInput = historyText + "\n\n" + fullInput;
  }

  // Try Interactions API — cycle through available models
  const models = ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-2.5-flash"];

  for (const model of models) {
    try {
      const res = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/interactions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            model: model,
            input: fullInput,
          }),
        }
      );

      if (res.ok) {
        const data = await res.json();
        const text = data.interaction?.outputText || data.outputText || data.text;
        if (text) {
          console.log(`Gemini ${model} OK`);
          return text;
        }
      } else {
        const err = await res.text();
        console.warn(`${model} (${res.status}):`, err.substring(0, 150));
      }
    } catch (e) {
      console.warn(`${model} error:`, e);
    }
  }

// ══════════════════════════════════════════════════════════
// TEMPLATE RESPONSE (no AI needed — pure DB data formatting)
// ══════════════════════════════════════════════════════════
function generateTemplateResponse(
  message: string,
  dbData: string,
  docs: any[],
  context: string
): string {
  const msg = message.toLowerCase();
  const lines = dbData.split("\n").filter((l: string) => l.trim());
  let response = "";

  if (msg.includes("kpi") || msg.includes("performa") || msg.includes("kinerja")) {
    response = "📊 **Ringkasan KPI**\n\n";
    const kpiLine = lines.find((l: string) => l.includes("KPI"));
    if (kpiLine) response += kpiLine.replace("KPI: ", "") + "\n\n";
    response += "💡 *Data dari hr_performance. Skor KPI dihitung berdasarkan pencapaian target bulanan.*";
  }
  else if (msg.includes("payroll") || msg.includes("gaji") || msg.includes("salary")) {
    response = "💰 **Ringkasan Payroll**\n\n";
    const payrollLine = lines.find((l: string) => l.includes("PAYROLL"));
    if (payrollLine) response += payrollLine.replace("PAYROLL: ", "") + "\n\n";
    response += "💡 *Total gaji bersih semua karyawan. Data dari hr_payroll.*";
  }
  else if (msg.includes("kehadiran") || msg.includes("absen") || msg.includes("hadir")) {
    response = "📋 **Kehadiran Karyawan**\n\n";
    const attLine = lines.find((l: string) => l.includes("ATTENDANCE"));
    if (attLine) response += attLine.replace("ATTENDANCE: ", "") + "\n\n";
    response += "💡 *Data dari hr_attendance hari ini.*";
  }
  else if (msg.includes("cuti") || msg.includes("leave")) {
    response = "🌴 **Data Cuti**\n\n";
    const leaveLine = lines.find((l: string) => l.includes("LEAVE"));
    if (leaveLine) response += leaveLine.replace("LEAVE: ", "") + "\n\n";
    response += "💡 *Kuota cuti tahun ini dari hr_leave.*";
  }
  else if (msg.includes("turnover") || msg.includes("resign") || msg.includes("keluar")) {
    response = "📉 **Data Turnover**\n\n";
    const tLine = lines.find((l: string) => l.includes("TURNOVER"));
    if (tLine) response += tLine.replace("TURNOVER: ", "") + "\n\n";
    response += "💡 *Turnover rate = jumlah keluar / total headcount × 100%.*";
  }
  else if (msg.includes("flight risk") || msg.includes("berisiko")) {
    response = "🚨 **Flight Risk**\n\n";
    const riskLine = lines.find((l: string) => l.includes("FLIGHT RISK"));
    if (riskLine) response += riskLine.replace("FLIGHT RISK:\n", "") + "\n\n";
    response += "💡 *Karyawan berisiko resign berdasarkan analisis data HR.*";
  }
  else if (msg.includes("warning") || msg.includes("peringatan")) {
    response = "⚠️ **Early Warning**\n\n";
    const wLine = lines.find((l: string) => l.includes("EARLY"));
    if (wLine) response += wLine.replace("EARLY WARNINGS:\n", "") + "\n\n";
    response += "💡 *Peringatan dini dari sistem monitoring HR.*";
  }
  else {
    response = "🤖 **insightWOS AI Assistant**\n\n";
    const summaryLine = lines.find((l: string) => l.includes("SUMMARY"));
    if (summaryLine) {
      response += "📊 **Ringkasan:**\n" + summaryLine.replace("SUMMARY:\n", "") + "\n\n";
    } else {
      response += "Saya adalah asisten HR untuk insightWOS.\n\n";
    }
    response += "**Yang bisa saya bantu:**\n";
    response += "• 📊 KPI & Performa — \"Bagaimana KPI divisi Mining?\"\n";
    response += "• 💰 Payroll — \"Berapa total gaji bulan ini?\"\n";
    response += "• 📋 Kehadiran — \"Bagaimana kehadiran karyawan?\"\n";
    response += "• 🌴 Cuti — \"Sisa cuti karyawan?\"\n";
    response += "• 📉 Turnover — \"Data turnover bulan ini?\"\n";
    response += "• 🚨 Flight Risk — \"Siapa karyawan berisiko resign?\"\n";
    response += "• ⚠️ Warning — \"Ada peringatan hari ini?\"\n";
  }

  if (docs.length > 0) {
    response += "\n\n---\n📚 **Kebijakan Terkait:**\n";
    docs.forEach((doc: any, i: number) => {
      response += `\n*[${i + 1}] ${doc.title}:*\n${(doc.content || "").substring(0, 300)}...\n`;
    });
  }

  return response;
}

// ══════════════════════════════════════════════════════════
// DATABASE FETCH
// ══════════════════════════════════════════════════════════
async function fetchDatabaseData(supabase: any, message: string, context: string): Promise<string> {
  const parts: string[] = [];
  const msg = message.toLowerCase();

  try {
    const { data: summary } = await supabase.rpc("admin_get_summary");
    if (summary) {
      parts.push(`SUMMARY:\n- Total karyawan: ${summary.total_employees || 0}\n- Mining: ${summary.mining_count || 0}\n- Estate: ${summary.estate_count || 0}\n- Mill: ${summary.mill_count || 0}\n- HQ: ${summary.hq_count || 0}\n- High performers: ${summary.high_performers || 0}\n- Low performers: ${summary.low_performers || 0}\n- Pending requests: ${summary.pending_requests || 0}`);
    }

    if (msg.includes("kpi") || msg.includes("performa") || msg.includes("kinerja")) {
      const { data: kpi } = await supabase.from("hr_performance").select("nrp, kpi_score, periode").order("created_at", { ascending: false }).limit(20);
      if (kpi?.length) {
        const avg = kpi.reduce((s: number, k: any) => s + Number(k.kpi_score || 0), 0) / kpi.length;
        const high = kpi.filter((k: any) => Number(k.kpi_score) >= 80).length;
        const low = kpi.filter((k: any) => Number(k.kpi_score) < 60).length;
        parts.push(`KPI: Rata-rata ${avg.toFixed(1)} dari ${kpi.length} data. High performers: ${high}, Low performers: ${low}`);
      }
    }

    if (msg.includes("payroll") || msg.includes("gaji") || msg.includes("salary")) {
      const { data: payroll } = await supabase.from("hr_payroll").select("nrp, net_salary, base_salary, periode").limit(50);
      if (payroll?.length) {
        const total = payroll.reduce((s: number, p: any) => s + Number(p.net_salary || 0), 0);
        const avg = total / payroll.length;
        parts.push(`PAYROLL: Total Rp ${total.toLocaleString("id-ID")} | Rata-rata Rp ${avg.toLocaleString("id-ID")} | ${payroll.length} karyawan`);
      }
    }

    if (msg.includes("kehadiran") || msg.includes("absen") || msg.includes("hadir")) {
      const { data: att } = await supabase.from("hr_attendance").select("nrp, status_hadir, date").eq("date", new Date().toISOString().split("T")[0]).limit(50);
      if (att?.length) {
        const hadir = att.filter((a: any) => a.status_hadir === "Hadir").length;
        const terlambat = att.filter((a: any) => a.status_hadir === "Terlambat").length;
        const absen = att.filter((a: any) => a.status_hadir === "Alpha" || a.status_hadir === "Tidak Hadir").length;
        parts.push(`ATTENDANCE Hari Ini: Hadir ${hadir} | Terlambat ${terlambat} | Absen ${absen} | Total ${att.length}`);
      }
    }

    if (msg.includes("cuti") || msg.includes("leave")) {
      const { data: leave } = await supabase.from("hr_leave").select("nrp, annual_quota, annual_used, tahun").eq("tahun", new Date().getFullYear());
      if (leave?.length) {
        const totalKuota = leave.reduce((s: number, l: any) => s + Number(l.annual_quota || 0), 0);
        const totalUsed = leave.reduce((s: number, l: any) => s + Number(l.annual_used || 0), 0);
        parts.push(`LEAVE: ${leave.length} karyawan | Kuota total: ${totalKuota} hari | Terpakai: ${totalUsed} hari | Sisa: ${totalKuota - totalUsed} hari`);
      }
    }

    if (msg.includes("turnover") || msg.includes("resign") || msg.includes("keluar")) {
      const { data: exit } = await supabase.from("hr_exit_clearance").select("nrp, resign_date, clearance_status").limit(20);
      if (exit?.length) {
        parts.push(`TURNOVER: ${exit.length} karyawan keluar | Pending clearance: ${exit.filter((e: any) => e.clearance_status === "PENDING").length}`);
      }
    }

    if (msg.includes("flight risk") || msg.includes("berisiko")) {
      try {
        const { data: risk } = await supabase.rpc("get_flight_risk_list");
        if (risk?.length) {
          parts.push("FLIGHT RISK:\n" + risk.slice(0, 5).map((r: any) => `- ${r.nama || r.nrp}: ${r.risk_level || "unknown"}`).join("\n"));
        }
      } catch (_e) { /* RPC may not exist */ }
    }

    if (msg.includes("warning") || msg.includes("peringatan")) {
      try {
        const { data: warning } = await supabase.rpc("get_early_warning");
        if (warning?.length) {
          parts.push("EARLY WARNINGS:\n" + warning.slice(0, 5).map((w: any) => `- ${w.nrp || ""}: ${w.title || w.message || ""}`).join("\n"));
        }
      } catch (_e) { /* RPC may not exist */ }
    }
  } catch (e) {
    console.warn("DB fetch error:", e);
  }

  return parts.length > 0 ? parts.join("\n\n") : "Tidak ada data spesifik yang tersedia.";
}

// ══════════════════════════════════════════════════════════
// DOCUMENT SEARCH (keyword match, no embeddings)
// ══════════════════════════════════════════════════════════
async function fetchRelevantDocs(supabase: any, message: string, context: string): Promise<any[]> {
  try {
    const keywords = message.toLowerCase().split(" ").filter((w: string) => w.length > 3);
    let query = supabase.from("ai_documents").select("title, content, context").limit(5);
    if (context && context !== "general") {
      query = query.eq("context", context);
    }
    const { data: docs } = await query;
    if (!docs?.length) return [];

    return docs
      .map((doc: any) => {
        const text = (doc.title + " " + doc.content).toLowerCase();
        const score = keywords.filter((kw: string) => text.includes(kw)).length;
        return { ...doc, score };
      })
      .filter((d: any) => d.score > 0)
      .sort((a: any, b: any) => b.score - a.score)
      .slice(0, 3);
  } catch (_e) {
    return [];
  }
}

// ══════════════════════════════════════════════════════════
// SYSTEM PROMPT
// ══════════════════════════════════════════════════════════
function buildSystemPrompt(dbData: string, docs: any[]): string {
  let prompt = `Kamu adalah AI Assistant untuk insightWOS — platform HR untuk perusahaan pertambangan, perkebunan sawit, dan pabrik PKS.

Tugasmu: Bantu admin/manager dengan pertanyaan tentang data HR.

Aturan:
- Jawab dalam Bahasa Indonesia
- Singkat, langsung ke poin
- Gunakan data yang diberikan, jangan mengarang
- Jika data tidak cukup, bilang "Saya tidak memiliki data yang cukup"
- Format angka dengan ribuan (contoh: 1.500 bukan 1500)
- Gunakan emoji jika sesuai`;

  if (dbData && dbData !== "Tidak ada data spesifik yang tersedia.") {
    prompt += `\n\n--- DATA DARI DATABASE ---\n${dbData}\n--- AKHIR DATA ---`;
  }

  if (docs.length > 0) {
    prompt += "\n\n--- DOKUMEN KEBIJAKAN PERUSAHAAN ---";
    docs.forEach((doc: any, i: number) => {
      prompt += `\n[${i + 1}] ${doc.title}:\n${(doc.content || "").substring(0, 500)}`;
    });
    prompt += "\n--- AKHIR DOKUMEN ---";
  }

  return prompt;
}
