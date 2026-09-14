// ============================================================
// AI Copilot — Gemini + Template Fallback
// Security: auth.uid() guard, rate limit (15 queries/15 min),
//           role-isolated data, DOMPurify-safe output
// ============================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Rate limit config (DB-backed via ai_check_rate_limit, role-based)
// Worker: 15/day, Admin: 30/day, Manager: 50/day, Owner: unlimited
const RATE_LIMIT_WINDOW = 60;    // minutes for per-window check (supplement to daily DB limit)

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message, conversationHistory = [], context = "general" } = await req.json();

    // SECURITY: Input sanitization
    const sanitized = message.replace(/[<>{}]/g, "").substring(0, 2000);
    if (!sanitized || typeof sanitized !== "string") {
      return new Response(
        JSON.stringify({ error: "message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const geminiKey = Deno.env.get("GEMINI_API_KEY") || "";

    // ── AUTH: Extract user JWT ──
    const authHeader = req.headers.get("Authorization") || "";
    const userToken = authHeader.replace("Bearer ", "");
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false }
    });
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // ── AUTH GUARD: Must be authenticated ──
    let userNRP: string | null = null;
    let userBU: string | null = null;
    let userRole: string | null = null;
    let isOwnerOrAdminPusat = false;
    let roleLevel = 0;

    try {
      const { data: { user }, error: authErr } = await supabase.auth.getUser(userToken);
      if (authErr || !user) {
        return new Response(
          JSON.stringify({ error: "Autentikasi diperlukan." }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: emp } = await adminClient.from("employees_master")
        .select("nrp, business_unit_id, role_level")
        .eq("auth_id", user.id)
        .single();

      if (emp) {
        userNRP = emp.nrp;
        userBU = emp.business_unit_id;
        roleLevel = emp.role_level || 0;
        isOwnerOrAdminPusat = roleLevel >= 4;
      }

      // Check owner
      const { data: ownerCheck } = await adminClient.from("system_owner_identity")
        .select("id")
        .eq("auth_id", user.id)
        .eq("is_active", true)
        .single();
      if (ownerCheck) isOwnerOrAdminPusat = true;

      // Get role from user_roles
      const { data: roleData } = await adminClient.from("user_roles")
        .select("role")
        .eq("nrp", userNRP)
        .single();
      if (roleData) userRole = roleData.role;

    } catch (_e) {
      return new Response(
        JSON.stringify({ error: "Autentikasi gagal." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── RATE LIMIT (role-based, DB-backed) ──
    let rateLimited = false;
    let rateLimitInfo: any = null;
    try {
      const { data: rlResult } = await adminClient.rpc("ai_check_rate_limit", {
        p_nrp: userNRP,
      });
      rateLimitInfo = rlResult;
      if (rlResult && !rlResult.ok) {
        rateLimited = true;
      }
    } catch (_e) { /* ignore — first query */ }

    // ── Fetch DB data (role-isolated) ──
    const dbData = await fetchDatabaseData(adminClient, message, context, {
      userNRP, userBU, userRole, isOwnerOrAdminPusat, roleLevel
    });

    // ── If rate limited: return DB data only (no AI) ──
    if (rateLimited) {
      const dbList = formatDbDataAsList(dbData, userRole);
      const limitMsg = rateLimitInfo?.msg || "Batas penggunaan AI tercapai";
      return new Response(
        JSON.stringify({
          message: `📊 Tampilan data berdasarkan pencarian Anda.\n\n(${limitMsg}\nMenampilkan data database saja.)`,
          dbData: dbList,
          sources: [],
          usedAI: false,
          rateLimited: true,
          rateLimit: rateLimitInfo,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Fetch policy documents ──
    const docs = await fetchRelevantDocs(adminClient, message, context);

    // ── AI response ──
    let assistantMessage = "";
    let usedAI = false;

    if (geminiKey) {
      const systemPrompt = buildSystemPrompt(dbData, docs, userRole);
      assistantMessage = await callGemini(geminiKey, systemPrompt, sanitized, conversationHistory);
      if (assistantMessage && !assistantMessage.startsWith("__FALLBACK__")) {
        usedAI = true;
      } else {
        assistantMessage = assistantMessage.replace("__FALLBACK__", "");
      }
    }

    if (!usedAI) {
      assistantMessage = generateTemplateResponse(sanitized, dbData, docs, context);
    }

    // ── Log to ai_rate_limits (via RPC for atomicity) ──
    try {
      await adminClient.rpc("ai_record_query", {
        p_nrp: userNRP,
        p_tokens: 0,
      });
    } catch (_e) { /* ignore */ }

    // ── Log conversation ──
    try {
      await adminClient.from("ai_conversations").insert({
        user_message: sanitized,
        assistant_message: assistantMessage,
        context,
        tokens_used: 0,
        documents_used: docs.length,
      }).catch(() => {});
    } catch (_e) { /* ignore */ }

    // ── Return both AI message AND structured DB data ──
    const dbList = formatDbDataAsList(dbData, userRole);
    return new Response(
      JSON.stringify({
        message: assistantMessage,
        dbData: dbList,
        sources: docs.map((d: any) => ({ title: d.title, similarity: 1.0 })),
        usedAI,
        rateLimited: false,
        rateLimit: rateLimitInfo,
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
// GEMINI AI
// ══════════════════════════════════════════════════════════
async function callGemini(
  apiKey: string,
  systemPrompt: string,
  message: string,
  history: any[]
): Promise<string> {
  let fullInput = systemPrompt + "\n\nPertanyaan: " + message;

  if (history.length > 0) {
    const historyText = history.slice(-6).map((m: any) =>
      `${m.role === "assistant" ? "Assistant" : "User"}: ${m.content}`
    ).join("\n");
    fullInput = historyText + "\n\n" + fullInput;
  }

  const models = ["gemini-2.5-flash", "gemini-2.0-flash"];

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
        if (text) return text;
      }
    } catch (_e) {}
  }
  return "__FALLBACK__";
}

// ══════════════════════════════════════════════════════════
// TEMPLATE RESPONSE
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
    response = "📊 Ringkasan KPI\n\n";
    const kpiLine = lines.find((l: string) => l.includes("KPI"));
    if (kpiLine) response += kpiLine.replace("KPI: ", "") + "\n\n";
    response += "Data dari hr_performance. Skor KPI dihitung berdasarkan pencapaian target bulanan.";
  }
  else if (msg.includes("payroll") || msg.includes("gaji") || msg.includes("salary")) {
    response = "💰 Ringkasan Payroll\n\n";
    const payrollLine = lines.find((l: string) => l.includes("PAYROLL"));
    if (payrollLine) response += payrollLine.replace("PAYROLL: ", "") + "\n\n";
    response += "Total gaji bersih semua karyawan. Data dari hr_payroll.";
  }
  else if (msg.includes("kehadiran") || msg.includes("absen") || msg.includes("hadir")) {
    response = "📋 Kehadiran Karyawan\n\n";
    const attLine = lines.find((l: string) => l.includes("ATTENDANCE"));
    if (attLine) response += attLine.replace("ATTENDANCE: ", "") + "\n\n";
    response += "Data dari hr_attendance hari ini.";
  }
  else if (msg.includes("cuti") || msg.includes("leave")) {
    response = "🌴 Data Cuti\n\n";
    const leaveLine = lines.find((l: string) => l.includes("LEAVE"));
    if (leaveLine) response += leaveLine.replace("LEAVE: ", "") + "\n\n";
    response += "Kuota cuti tahun ini dari hr_leave.";
  }
  else if (msg.includes("turnover") || msg.includes("resign") || msg.includes("keluar")) {
    response = "📉 Data Turnover\n\n";
    const tLine = lines.find((l: string) => l.includes("TURNOVER"));
    if (tLine) response += tLine.replace("TURNOVER: ", "") + "\n\n";
    response += "Turnover rate = jumlah keluar / total headcount x 100%.";
  }
  else {
    response = "🤖 insightWOS AI Assistant\n\n";
    const summaryLine = lines.find((l: string) => l.includes("SUMMARY"));
    if (summaryLine) {
      response += "Ringkasan:\n" + summaryLine.replace("SUMMARY:\n", "") + "\n\n";
    } else {
      response += "Saya adalah asisten HR untuk insightWOS.\n\n";
    }
    response += "Yang bisa saya bantu:\n";
    response += "- KPI & Performa\n";
    response += "- Payroll\n";
    response += "- Kehadiran\n";
    response += "- Cuti\n";
    response += "- Turnover\n";
  }

  if (docs.length > 0) {
    response += "\n\n---\nKebijakan Terkait:\n";
    docs.forEach((doc: any, i: number) => {
      response += `\n[${i + 1}] ${doc.title}:\n${(doc.content || "").substring(0, 300)}...\n`;
    });
  }

  return response;
}

// ══════════════════════════════════════════════════════════
// FORMAT DB DATA AS STRUCTURED LIST (human-readable)
// ══════════════════════════════════════════════════════════
function formatDbDataAsList(dbData: string, userRole: string | null): any[] {
  const items: any[] = [];
  if (!dbData || dbData === "Tidak ada data spesifik yang tersedia.") return items;

  const sections = dbData.split("\n\n");
  for (const section of sections) {
    const lines = section.split("\n").filter(l => l.trim());
    if (lines.length === 0) continue;

    const header = lines[0];
    // Extract key-value pairs
    const dataLines = lines.slice(1);
    const entries: Record<string, string> = {};

    for (const line of dataLines) {
      const match = line.match(/^[-•]\s*(.+?):\s*(.+)$/);
      if (match) {
        entries[match[1].trim()] = match[2].trim();
      } else if (line.includes(":")) {
        const [key, ...vals] = line.split(":");
        if (key && vals.length) entries[key.trim()] = vals.join(":").trim();
      }
    }

    items.push({
      category: header.replace(/^[📊💰📋🌴📉🚨⚠️]\s*/, "").trim(),
      data: entries,
      raw: dataLines.join("\n"),
    });
  }

  return items;
}

// ══════════════════════════════════════════════════════════
// DATABASE FETCH (role-isolated)
// ══════════════════════════════════════════════════════════
interface UserContext {
  userNRP: string | null;
  userBU: string | null;
  userRole: string | null;
  isOwnerOrAdminPusat: boolean;
  roleLevel: number;
}

async function fetchDatabaseData(
  supabase: any,
  message: string,
  context: string,
  ctx: UserContext
): Promise<string> {
  const parts: string[] = [];
  const msg = message.toLowerCase();
  const isAdmin = ctx.isOwnerOrAdminPusat || (ctx.userRole && ctx.userRole.startsWith("admin"));

  // Worker: only own data
  if (!isAdmin && ctx.userNRP) {
    try {
      // Own KPI
      const { data: myKpi } = await supabase.from("hr_performance")
        .select("nrp, kpi_score, periode")
        .eq("nrp", ctx.userNRP)
        .order("periode", { ascending: false })
        .limit(1);
      if (myKpi?.length) {
        parts.push(`KPI ANDA: Skor ${myKpi[0].kpi_score} (${myKpi[0].periode})`);
      }

      // Own attendance today
      const today = new Date().toISOString().split("T")[0];
      const { data: myAtt } = await supabase.from("hr_attendance")
        .select("status_hadir, clock_in, clock_out")
        .eq("nrp", ctx.userNRP)
        .eq("date", today);
      if (myAtt?.length) {
        parts.push(`KEHADIRAN HARI INI: ${myAtt[0].status_hadir} (masuk: ${myAtt[0].clock_in || "-"}, keluar: ${myAtt[0].clock_out || "-"})`);
      }

      // Own leave quota
      const { data: myLeave } = await supabase.from("hr_leave")
        .select("annual_quota, annual_used")
        .eq("nrp", ctx.userNRP)
        .eq("tahun", new Date().getFullYear());
      if (myLeave?.length) {
        const l = myLeave[0];
        parts.push(`CUTI: Kuota ${l.annual_quota} hari | Terpakai ${l.annual_used} | Sisa ${l.annual_quota - l.annual_used}`);
      }

      // Own payroll
      const { data: myPay } = await supabase.from("hr_payroll")
        .select("net_salary, base_salary, periode")
        .eq("nrp", ctx.userNRP)
        .order("periode", { ascending: false })
        .limit(1);
      if (myPay?.length) {
        parts.push(`GAJI: Rp ${Number(myPay[0].net_salary || 0).toLocaleString("id-ID")} (periode ${myPay[0].periode})`);
      }
    } catch (_e) {}
    return parts.length > 0 ? parts.join("\n\n") : "Tidak ada data spesifik yang tersedia.";
  }

  // Admin: BU-scoped data
  try {
    // Summary
    const { data: summary } = await supabase.rpc("admin_get_summary");
    if (summary) {
      parts.push(`SUMMARY:\n- Total: ${summary.total_employees || 0} karyawan\n- Mining: ${summary.mining_count || 0} | Estate: ${summary.estate_count || 0} | Mill: ${summary.mill_count || 0} | HQ: ${summary.hq_count || 0}\n- High performers (KPI>=80): ${summary.high_performers || 0}\n- Low performers (KPI<60): ${summary.low_performers || 0}\n- Pending requests: ${summary.pending_requests || 0}`);
    }

    // KPI top 10
    let kpiQuery = supabase.from("hr_performance")
      .select("nrp, kpi_score, periode, employees_master(nama, divisi, business_unit_id)")
      .order("kpi_score", { ascending: false });
    if (!ctx.isOwnerOrAdminPusat && ctx.userBU) {
      kpiQuery = kpiQuery.eq("employees_master.business_unit_id", ctx.userBU);
    }
    const { data: topKpi } = await kpiQuery.limit(10);
    if (topKpi?.length) {
      const list = topKpi.map((k: any) =>
        `${k.employees_master?.nama || k.nrp} (${k.employees_master?.divisi || "?"}): ${k.kpi_score}`
      ).join(", ");
      parts.push(`TOP 10 KPI TERTINGGI: ${list}`);
    }

    // Attendance today
    const today = new Date().toISOString().split("T")[0];
    let attQuery = supabase.from("hr_attendance")
      .select("nrp, status_hadir, employees_master(nama, business_unit_id)")
      .eq("date", today);
    if (!ctx.isOwnerOrAdminPusat && ctx.userBU) {
      attQuery = attQuery.eq("employees_master.business_unit_id", ctx.userBU);
    }
    const { data: att } = await attQuery.limit(200);
    if (att?.length) {
      const hadir = att.filter((a: any) => a.status_hadir === "Hadir").length;
      const terlambat = att.filter((a: any) => a.status_hadir === "Terlambat").length;
      const absen = att.filter((a: any) => a.status_hadir === "Alpha").length;
      parts.push(`KEHADIRAN HARI INI (${today}): Hadir ${hadir} | Terlambat ${terlambat} | Absen ${absen} | Total ${att.length}`);
    }

    // Flight risk
    try {
      let riskQuery = supabase.from("hr_performance")
        .select("nrp, kpi_score, employees_master(nama, divisi, business_unit_id)")
        .lt("kpi_score", 60);
      if (!ctx.isOwnerOrAdminPusat && ctx.userBU) {
        riskQuery = riskQuery.eq("employees_master.business_unit_id", ctx.userBU);
      }
      const { data: risk } = await riskQuery.limit(10);
      if (risk?.length) {
        const list = risk.map((r: any) =>
          `${r.employees_master?.nama || r.nrp} (${r.employees_master?.divisi || "?"}): KPI ${r.kpi_score}`
        ).join(", ");
        parts.push(`FLIGHT RISK (KPI<60): ${list}`);
      }
    } catch (_e) {}

  } catch (_e) {}

  return parts.length > 0 ? parts.join("\n\n") : "Tidak ada data spesifik yang tersedia.";
}

// ══════════════════════════════════════════════════════════
// DOCUMENT SEARCH
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
function buildSystemPrompt(dbData: string, docs: any[], userRole: string | null): string {
  let prompt = `Kamu adalah AI Assistant untuk insightWOS — platform HR untuk perusahaan pertambangan, perkebunan sawit, dan pabrik PKS.

Tugasmu: Bantu pengguna dengan pertanyaan tentang data HR.

Aturan:
- Jawab dalam Bahasa Indonesia yang mudah dipahami manusia
- Singkat, langsung ke poin, gunakan format list jika cocok
- Gunakan data yang diberikan, jangan mengarang
- Jika data tidak cukup, bilang "Saya tidak memiliki data yang cukup"
- Format angka dengan ribuan (contoh: 1.500 bukan 1500)
- Jangan gunakan markdown yang rumit — cukup teks biasa dengan emoji
- Setelah menjawab pertanyaan, tampilkan juga data mentah dalam bentuk list yang rapi`;

  if (userRole && !userRole.startsWith("admin")) {
    prompt += `\n\nPengguna ini adalah worker. Tampilkan HANYA data miliknya (KPI, kehadiran, cuti, gaji). Jangan tampilkan data orang lain.`;
  }

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
