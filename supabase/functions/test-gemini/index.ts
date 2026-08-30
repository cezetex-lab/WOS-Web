// Minimal Gemini API test — no DB, no template, just API test
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const geminiKey = Deno.env.get("GEMINI_API_KEY") || "";
  const results: any[] = [];

  if (!geminiKey) {
    return new Response(
      JSON.stringify({ error: "GEMINI_API_KEY not set", results: [] }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Test each model with both endpoints
  const models = ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-2.5-flash"];

  for (const model of models) {
    // Test 1: Interactions API
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/interactions?key=${geminiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ model, input: "Say hello in 5 words" }),
        }
      );
      const data = await res.json();
      results.push({
        model,
        endpoint: "interactions",
        status: res.status,
        ok: res.ok,
        text: data.response?.candidates?.[0]?.content?.parts?.[0]?.text
          || data.interaction?.outputText
          || null,
        error: data.error?.message || null,
      });
    } catch (e: any) {
      results.push({ model, endpoint: "interactions", status: "error", error: e.message });
    }

    // Test 2: generateContent
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: "Say hello in 5 words" }] }],
          }),
        }
      );
      const data = await res.json();
      results.push({
        model,
        endpoint: "generateContent",
        status: res.status,
        ok: res.ok,
        text: data.candidates?.[0]?.content?.parts?.[0]?.text || null,
        error: data.error?.message || null,
      });
    } catch (e: any) {
      results.push({ model, endpoint: "generateContent", status: "error", error: e.message });
    }
  }

  return new Response(
    JSON.stringify({ geminiKeyLength: geminiKey.length, results }, null, 2),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
