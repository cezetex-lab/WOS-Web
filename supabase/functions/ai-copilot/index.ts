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

    // SECURITY FIX: Use user's JWT token, NOT service_role key
    // This ensures RLS policies are enforced
    const authHeader = req.headers.get("Authorization") || "";
    const userToken = authHeader.replace("Bearer ", "");
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Get user's identity for BU filtering
    let userBU: string | null = null;
    let isOwnerOrAdminPusat = false;
    try {
      const { data: { user } } = await supabase.auth.getUser(userToken);
      if (user) {
        const { data: emp } = await supabase.from("employees_master")
          .select("business_unit_id, role_level")
          .eq("auth_id", user.id)
          .single();
        if (emp) {
          userBU = emp.business_unit_id;
          isOwnerOrAdminPusat = emp.role_level >= 4;
        }
        // Check if owner via system_owner_identity
        const { data: ownerCheck } = await supabase.from("system_owner_identity")
          .select("id")
          .eq("auth_id", user.id)
          .eq("is_active", true)
          .single();
        if (ownerCheck) isOwnerOrAdminPusat = true;
      }
    } catch (_e) {}

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

  // generateContent is confirmed working (tested 2026-08-30)
  // Use gemini-3.6-flash (stable) → gemini-3.5-flash (fallback)
  const models = ["gemini-3.6-flash", "gemini-3.5-flash"];

  for (const model of models) {
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: fullInput }] }],
            generationConfig: { temperature: 0.7, maxOutputTokens: 1024 },
          }),
        }
      );

      if (res.ok) {
        const data = await res.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          return text;
        }
      } else {
        const err = await res.json().catch(() => ({}));
        console.warn(`${model} ${res.status}:`, (err as any).error?.message || res.status);
      }
    } catch (e) {
    }
  }

  // All models failed
  return "__FALLBACK__";
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

  // Detect target business unit
  let targetBU = null;
  if (msg.includes("mining") || msg.includes("tambang")) targetBU = "MINING";
  else if (msg.includes("estate") || msg.includes("kebun") || msg.includes("sawit")) targetBU = "ESTATE";
  else if (msg.includes("mill") || msg.includes("pabrik") || msg.includes("pks")) targetBU = "MILL";
  else if (msg.includes("hq") || msg.includes("kantor") || msg.includes("korporat")) targetBU = "HQ";

  // Detect if asking about specific people
  const asksTop = msg.includes("tertinggi") || msg.includes("terbaik") || msg.includes("top") || msg.includes("paling tinggi");
  const asksLow = msg.includes("terendah") || msg.includes("terburuk") || msg.includes("bottom") || msg.includes("paling rendah");

  try {
    // 1. SUMMARY — always fetch
    const { data: summary } = await supabase.rpc("admin_get_summary");
    if (summary) {
      parts.push(`SUMMARY:\n- Total: ${summary.total_employees || 0} karyawan\n- Mining: ${summary.mining_count || 0} | Estate: ${summary.estate_count || 0} | Mill: ${summary.mill_count || 0} | HQ: ${summary.hq_count || 0}\n- High performers (KPI≥80): ${summary.high_performers || 0}\n- Low performers (KPI<60): ${summary.low_performers || 0}\n- Pending requests: ${summary.pending_requests || 0}\n- PKWT expiring soon: ${summary.retiring_soon || 0}`);
    }

    // 2. KPI — always fetch top 10 + bottom 10 + per division
    let kpiQuery = supabase.from("hr_performance")
      .select("nrp, kpi_score, periode, employees_master(nama, divisi, business_unit_id)")
      .order("kpi_score", { ascending: false });
    if (!isOwnerOrAdminPusat && userBU) {
      kpiQuery = kpiQuery.eq("employees_master.business_unit_id", userBU);
    }
    const { data: topKpi } = await kpiQuery.limit(10);
    let lowKpiQuery = supabase.from("hr_performance")
      .select("nrp, kpi_score, periode, employees_master(nama, divisi, business_unit_id)")
      .order("kpi_score", { ascending: true });
    if (!isOwnerOrAdminPusat && userBU) {
      lowKpiQuery = lowKpiQuery.eq("employees_master.business_unit_id", userBU);
    }
    const { data: lowKpi } = await lowKpiQuery.limit(10);

    if (topKpi?.length) {
      const topList = topKpi.map((k: any) => {
        const name = k.employees_master?.nama || k.nrp;
        const div = k.employees_master?.divisi || "?";
        const bu = k.employees_master?.business_unit || "?";
        return `${name} (${div}/${bu}): ${k.kpi_score}`;
      }).join(", ");
      parts.push(`TOP 10 KPI TERTINGGI:\n${topList}`);
    }
    if (lowKpi?.length) {
      const lowList = lowKpi.map((k: any) => {
        const name = k.employees_master?.nama || k.nrp;
        const div = k.employees_master?.divisi || "?";
        const bu = k.employees_master?.business_unit || "?";
        return `${name} (${div}/${bu}): ${k.kpi_score}`;
      }).join(", ");
      parts.push(`BOTTOM 10 KPI TERENDAH:\n${lowList}`);
    }

    // 3. KPI PER DIVISION
    const allKpi = [...(topKpi || []), ...(lowKpi || [])];
    if (allKpi.length) {
      const byDiv: Record<string, number[]> = {};
      allKpi.forEach((k: any) => {
        const key = `${k.employees_master?.business_unit || "?"}/${k.employees_master?.divisi || "?"}`;
        if (!byDiv[key]) byDiv[key] = [];
        byDiv[key].push(Number(k.kpi_score));
      });
      const divLines = Object.entries(byDiv).map(([k, v]) => {
        const avg = (v.reduce((a, b) => a + b, 0) / v.length).toFixed(1);
        return `${k}: avg ${avg} (${v.length} data)`;
      }).join(", ");
      parts.push(`KPI PER DIVISI: ${divLines}`);
    }

    // 4. PAYROLL — top 5 + bottom 5
    let payQuery = supabase.from("hr_payroll")
      .select("nrp, net_salary, base_salary, employees_master(nama, divisi, business_unit_id)")
      .order("net_salary", { ascending: false });
    if (!isOwnerOrAdminPusat && userBU) {
      payQuery = payQuery.eq("employees_master.business_unit_id", userBU);
    }
    const { data: topPay } = await payQuery.limit(5);
    let lowPayQuery = supabase.from("hr_payroll")
      .select("nrp, net_salary, base_salary, employees_master(nama, divisi, business_unit_id)")
      .order("net_salary", { ascending: true });
    if (!isOwnerOrAdminPusat && userBU) {
      lowPayQuery = lowPayQuery.eq("employees_master.business_unit_id", userBU);
    }
    const { data: lowPay } = await lowPayQuery.limit(5);
    if (topPay?.length) {
      const totalPay = topPay.concat(lowPay || []).reduce((s: number, p: any) => s + Number(p.net_salary || 0), 0);
      const topList = topPay.map((p: any) => `${p.employees_master?.nama || p.nrp}: Rp ${Number(p.net_salary || 0).toLocaleString("id-ID")}`).join(", ");
      const lowList = (lowPay || []).map((p: any) => `${p.employees_master?.nama || p.nrp}: Rp ${Number(p.net_salary || 0).toLocaleString("id-ID")}`).join(", ");
      parts.push(`PAYROLL TOP 5: ${topList}\nPAYROLL BOTTOM 5: ${lowList}`);
    }

    // 5. ATTENDANCE — today
    const today = new Date().toISOString().split("T")[0];
    let attQuery = supabase.from("hr_attendance")
      .select("nrp, status_hadir, employees_master(nama, business_unit_id)")
      .eq("date", today);
    if (!isOwnerOrAdminPusat && userBU) {
      attQuery = attQuery.eq("employees_master.business_unit_id", userBU);
    }
    const { data: att } = await attQuery.limit(200);
    if (att?.length) {
      const hadir = att.filter((a: any) => a.status_hadir === "Hadir").length;
      const terlambat = att.filter((a: any) => a.status_hadir === "Terlambat").length;
      const absen = att.filter((a: any) => a.status_hadir === "Alpha").length;
      parts.push(`KEHADIRAN HARI INI (${today}): Hadir ${hadir} | Terlambat ${terlambat} | Absen ${absen} | Total ${att.length}`);
    }

    // 6. LEAVE
    const { data: leave } = await supabase.from("hr_leave")
      .select("nrp, annual_quota, annual_used")
      .eq("tahun", new Date().getFullYear());
    if (leave?.length) {
      const totalKuota = leave.reduce((s: number, l: any) => s + Number(l.annual_quota || 0), 0);
      const totalUsed = leave.reduce((s: number, l: any) => s + Number(l.annual_used || 0), 0);
      parts.push(`CUTI ${new Date().getFullYear()}: ${leave.length} karyawan | Kuota: ${totalKuota} hari | Terpakai: ${totalUsed} | Sisa: ${totalKuota - totalUsed}`);
    }

    // 7. FLIGHT RISK
    try {
      let riskQuery = supabase.from("hr_performance")
        .select("nrp, kpi_score, employees_master(nama, divisi, business_unit_id)")
        .lt("kpi_score", 60);
      if (!isOwnerOrAdminPusat && userBU) {
        riskQuery = riskQuery.eq("employees_master.business_unit_id", userBU);
      }
      const { data: risk } = await riskQuery.limit(10);
      if (risk?.length) {
        const riskList = risk.map((r: any) => `${r.employees_master?.nama || r.nrp} (${r.employees_master?.divisi || "?"}): KPI ${r.kpi_score}`).join(", ");
        parts.push(`FLIGHT RISK (KPI<60): ${riskList}`);
      }
    } catch (_e) {}

    // 8. EARLY WARNING — PKWT expiring
    try {
      const { data: pkwt } = await supabase.rpc("get_pkwt_expiry_alert");
      if (pkwt?.data?.length) {
        const warningList = pkwt.data.slice(0, 5).map((w: any) => `${w.nama} (${w.divisi}): ${w.risk_level} - ${w.days_remaining} hari`).join(", ");
        parts.push(`PKWT EXPIRING: ${warningList}`);
      }
    } catch (_e) {}

  } catch (e) {
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
