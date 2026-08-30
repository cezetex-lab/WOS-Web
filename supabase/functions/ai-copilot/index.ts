// ============================================================
// AI Copilot — RAG (Retrieval-Augmented Generation)
// Edge Function for insightWOS
// ============================================================
// 
// Deployment:
//   supabase functions deploy ai-copilot
//
// Environment Variables (set via Supabase Dashboard):
//   OPENAI_API_KEY       — OpenAI API key for embeddings + chat
//   SUPABASE_URL         — auto-set by Supabase
//   SUPABASE_SERVICE_ROLE_KEY — auto-set by Supabase
// ============================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // CORS preflight
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

    // Create Supabase client with service role (for vector search)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const openaiKey = Deno.env.get("OPENAI_API_KEY")!;

    const supabase = createClient(supabaseUrl, supabaseKey);

    // ── Step 1: Generate embedding for user query ──
    const embeddingRes = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "text-embedding-3-small",
        input: message,
      }),
    });

    if (!embeddingRes.ok) {
      const err = await embeddingRes.text();
      console.error("Embedding error:", err);
      return new Response(
        JSON.stringify({ error: "Failed to generate embedding", details: err }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: embeddingData } = await embeddingRes.json();
    const queryEmbedding = embeddingData[0].embedding;

    // ── Step 2: Vector search — find relevant documents ──
    const { data: matches, error: searchError } = await supabase.rpc("match_documents", {
      query_embedding: queryEmbedding,
      match_count: 8,
      filter_context: context,
    });

    if (searchError) {
      console.error("Vector search error:", searchError);
      // Continue without context if search fails
    }

    const relevantDocs = matches || [];

    // ── Step 3: Also fetch recent data for context ──
    const contextData = await fetchRecentData(supabase, context);

    // ── Step 4: Build system prompt with RAG context ──
    let systemPrompt = `Kamu adalah AI Copilot untuk insightWOS — platform Workforce Intelligence untuk manajemen SDM.

Kamu membantu admin dan manager dengan:
- Analisis data karyawan dan KPI
- Rekomendasi keputusan HR
- Penjelasan kebijakan perusahaan
- Prediksi dan early warning
- Bantuan operasional HR harian

Bahasa: Indonesia (formal tapi ramah).
Gaya: Singkat, langsung ke poin, gunakan emoji jika sesuai.
Batasan: Jangan mengarang data. Jika tidak yenyakin, bilang "Saya tidak memiliki data yang cukup untuk menjawab ini."`;

    // Add RAG context from vector search
    if (relevantDocs.length > 0) {
      systemPrompt += "\n\n--- KONTEKS DARI DOKUMEN PERUSAHAAN ---\n";
      relevantDocs.forEach((doc: any, i: number) => {
        systemPrompt += `\n[Dokumen ${i + 1}] ${doc.title || 'Untitled'}:\n${doc.content}\n`;
      });
      systemPrompt += "\n--- AKHIR KONTEKS ---\n";
    }

    // Add live data context
    if (contextData) {
      systemPrompt += `\n\n--- DATA REAL-TIME ---\n${contextData}\n--- AKHIR DATA ---\n`;
    }

    // ── Step 5: Generate response via OpenAI Chat ──
    const messages = [
      { role: "system", content: systemPrompt },
      ...conversationHistory.slice(-10), // Last 10 messages for context
      { role: "user", content: message },
    ];

    const chatRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages,
        max_tokens: 1024,
        temperature: 0.7,
        stream: false,
      }),
    });

    if (!chatRes.ok) {
      const err = await chatRes.text();
      console.error("Chat error:", err);
      return new Response(
        JSON.stringify({ error: "Failed to generate response", details: err }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const chatData = await chatRes.json();
    const assistantMessage = chatData.choices[0].message.content;

    // ── Step 6: Save to conversation log ──
    try {
      await supabase.from("ai_conversations").insert({
        user_message: message,
        assistant_message: assistantMessage,
        context,
        tokens_used: chatData.usage?.total_tokens || 0,
        documents_used: relevantDocs.length,
      });
    } catch (e) {
      console.warn("Failed to log conversation:", e);
    }

    // ── Step 7: Return response ──
    return new Response(
      JSON.stringify({
        message: assistantMessage,
        sources: relevantDocs.map((d: any) => ({
          title: d.title,
          similarity: d.similarity,
        })),
        usage: chatData.usage,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("AI Copilot error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ── Helper: Fetch recent data based on context ──
async function fetchRecentData(supabase: any, context: string): Promise<string> {
  const parts: string[] = [];

  try {
    // Always fetch summary stats
    const { data: summary } = await supabase.rpc("admin_get_summary");
    if (summary) {
      parts.push(`Summary: ${JSON.stringify(summary)}`);
    }

    // Context-specific data
    if (context === "kpi" || context === "general") {
      const { data: topPerformers } = await supabase.rpc("admin_get_top_performers");
      if (topPerformers?.length) {
        parts.push(`Top Performers: ${topPerformers.slice(0, 5).map((p: any) => `${p.nama} (${p.kpi_score})`).join(", ")}`);
      }
    }

    if (context === "payroll" || context === "general") {
      const { data: payroll } = await supabase.rpc("admin_get_payroll");
      if (payroll?.length) {
        const totalGaji = payroll.reduce((s: number, p: any) => s + (p.gaji_bersih || 0), 0);
        parts.push(`Total payroll: Rp ${totalGaji.toLocaleString("id-ID")} (${payroll.length} karyawan)`);
      }
    }

    if (context === "attendance" || context === "general") {
      const { data: workers } = await supabase.rpc("get_worker_status");
      if (workers) {
        parts.push(`Worker status: ${JSON.stringify(workers)}`);
      }
    }
  } catch (e) {
    console.warn("Failed to fetch context data:", e);
  }

  return parts.length > 0 ? parts.join("\n") : "";
}
