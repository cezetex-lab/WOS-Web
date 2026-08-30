// ============================================================
// AI Copilot — Google Gemini (FREE, no OpenAI needed)
// Simplified: DB query + Gemini format = response
// ============================================================
// 
// Environment Variables (set via Supabase Dashboard → Secrets):
//   GEMINI_API_KEY  — Google AI Studio API key (FREE)
//   SUPABASE_URL    — auto-set
//   SUPABASE_SERVICE_ROLE_KEY — auto-set
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
    const geminiKey = Deno.env.get("GEMINI_API_KEY")!;

    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // ── Step 1: Fetch relevant data from database ──
    const dbData = await fetchDatabaseData(supabase, message, context);

    // ── Step 2: Fetch relevant policy documents (simple keyword match) ──
    const docs = await fetchRelevantDocs(supabase, message, context);

    // ── Step 3: Build prompt with DB data + docs ──
    const systemPrompt = buildSystemPrompt(dbData, docs);

    // ── Step 4: Call Google Gemini ──
    const messages = [
      { role: "user", parts: [{ text: systemPrompt + "\n\nPertanyaan: " + message }] },
    ];

    // Add conversation history
    if (conversationHistory.length > 0) {
      const historyParts = conversationHistory.slice(-6).map((m: any) => ({
        role: m.role === "assistant" ? "model" : "user",
        parts: [{ text: m.content }],
      }));
      messages.unshift(...historyParts);
    }

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: messages,
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 1024,
          },
        }),
      }
    );

    if (!geminiRes.ok) {
      const err = await geminiRes.text();
      console.error("Gemini error:", err);
      return new Response(
        JSON.stringify({ error: "AI service error", details: err }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiRes.json();
    const assistantMessage = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "Maaf, tidak bisa memproses pertanyaan.";

    // ── Step 5: Log conversation ──
    try {
      await supabase.from("ai_conversations").insert({
        user_message: message,
        assistant_message: assistantMessage,
        context,
        tokens_used: geminiData.usageMetadata?.totalTokenCount || 0,
        documents_used: docs.length,
      });
    } catch (e) {
      console.warn("Failed to log:", e);
    }

    // ── Step 6: Return response ──
    return new Response(
      JSON.stringify({
        message: assistantMessage,
        sources: docs.map((d: any) => ({ title: d.title, similarity: 1.0 })),
        usage: geminiData.usageMetadata,
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

// ── Helper: Fetch data from database based on context ──
async function fetchDatabaseData(supabase: any, message: string, context: string): Promise<string> {
  const parts: string[] = [];
  const msg = message.toLowerCase();

  try {
    // Always fetch summary
    const { data: summary } = await supabase.rpc("admin_get_summary");
    if (summary) {
      parts.push(`SUMMARY:\n- Total karyawan: ${summary.total_employees || 0}\n- Mining: ${summary.mining_count || 0}\n- Estate: ${summary.estate_count || 0}\n- Mill: ${summary.mill_count || 0}\n- HQ: ${summary.hq_count || 0}\n- High performers: ${summary.high_performers || 0}\n- Low performers: ${summary.low_performers || 0}\n- Pending requests: ${summary.pending_requests || 0}`);
    }

    // Context-specific data
    if (msg.includes("kpi") || msg.includes("performa") || msg.includes("kinerja")) {
      const { data: kpi } = await supabase.from('hr_performance').select('nrp, kpi_score, periode').order('created_at', { ascending: false }).limit(20);
      if (kpi?.length) {
        const avg = kpi.reduce((s: number, k: any) => s + Number(k.kpi_score || 0), 0) / kpi.length;
        parts.push(`KPI: Rata-rata ${avg.toFixed(1)} dari ${kpi.length} data terakhir`);
      }
    }

    if (msg.includes("payroll") || msg.includes("gaji") || msg.includes("salary")) {
      const { data: payroll } = await supabase.rpc("get_worker_payroll", { p_nrp: null });
      if (payroll?.length) {
        const total = payroll.reduce((s: number, p: any) => s + Number(p.net_salary || 0), 0);
        parts.push(`PAYROLL: Total Rp ${total.toLocaleString('id-ID')} (${payroll.length} karyawan)`);
      }
    }

    if (msg.includes("kehadiran") || msg.includes("absen") || msg.includes("hadir")) {
      const { data: att } = await supabase.rpc("get_worker_status");
      if (att) {
        parts.push(`ATTENDANCE: ${JSON.stringify(att)}`);
      }
    }

    if (msg.includes("cuti") || msg.includes("leave")) {
      const { data: leave } = await supabase.rpc("admin_get_leave");
      if (leave?.length) {
        const pending = leave.filter((l: any) => l.status === "Pending").length;
        parts.push(`LEAVE: ${leave.length} total, ${pending} pending approval`);
      }
    }

    if (msg.includes("turnover") || msg.includes("resign") || msg.includes("keluar")) {
      const { data: turnover } = await supabase.rpc("get_turnover_data");
      if (turnover) {
        parts.push(`TURNOVER: ${JSON.stringify(turnover)}`);
      }
    }

    if (msg.includes("flight risk") || msg.includes("berisiko")) {
      const { data: risk } = await supabase.rpc("get_flight_risk_list");
      if (risk?.length) {
        parts.push("FLIGHT RISK:\n" + risk.slice(0, 5).map((r: any) => `- ${r.nama} (${r.nrp}): risk ${r.risk_level || 'unknown'}`).join("\n"));
      }
    }

    if (msg.includes("warning") || msg.includes("peringatan")) {
      const { data: warning } = await supabase.rpc("get_early_warning");
      if (warning?.length) {
        parts.push("EARLY WARNINGS:\n" + warning.slice(0, 5).map((w: any) => `- ${w.nrp || ''}: ${w.title || w.message || ''}`).join("\n"));
      }
    }
  } catch (e) {
    console.warn("DB fetch error:", e);
  }

  return parts.length > 0 ? parts.join("\n\n") : "Tidak ada data spesifik yang tersedia.";
}

// ── Helper: Fetch relevant policy documents (simple keyword match) ──
async function fetchRelevantDocs(supabase: any, message: string, context: string): Promise<any[]> {
  try {
    // Simple keyword search — no embeddings needed
    const keywords = message.toLowerCase().split(" ").filter((w: string) => w.length > 3);
    
    let query = supabase.from("ai_documents").select("title, content, context").limit(5);
    
    // Filter by context if specified
    if (context && context !== "general") {
      query = query.eq("context", context);
    }
    
    const { data: docs } = await query;
    
    if (!docs?.length) return [];
    
    // Score documents by keyword overlap
    const scored = docs.map((doc: any) => {
      const text = (doc.title + " " + doc.content).toLowerCase();
      const score = keywords.filter((kw: string) => text.includes(kw)).length;
      return { ...doc, score };
    }).filter((d: any) => d.score > 0).sort((a: any, b: any) => b.score - a.score);
    
    return scored.slice(0, 3);
  } catch (e) {
    return [];
  }
}

// ── Helper: Build system prompt ──
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
      prompt += `\n[${i + 1}] ${doc.title}:\n${doc.content?.substring(0, 500) || ""}`;
    });
    prompt += "\n--- AKHIR DOKUMEN ---";
  }

  return prompt;
}
