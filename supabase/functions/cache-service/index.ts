// ============================================================
// cache-service — Supabase Edge Function
// Redis cache via Upstash (server-side only)
// ============================================================
// Deploy: supabase functions deploy cache-service
// Invoke: POST /functions/v1/cache-service
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const UPSTASH_URL = Deno.env.get("UPSTASH_REDIS_REST_URL")!;
const UPSTASH_TOKEN = Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ── Upstash Redis Client ──
async function redis(command: string, ...args: (string | number)[]) {
  const res = await fetch(UPSTASH_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${UPSTASH_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify([command, ...args]),
  });
  if (!res.ok) throw new Error(`Redis error: ${res.status}`);
  const data = await res.json();
  return data.result;
}

// ── CORS Headers ──
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, key, value, ttl } = await req.json();

    // Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify Supabase JWT
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let result;

    switch (action) {
      case "get":
        result = await redis("GET", `cache:${key}`);
        if (result) {
          try { result = JSON.parse(result); } catch {}
        }
        break;

      case "set":
        const ttlSeconds = ttl || 300;
        await redis("SETEX", `cache:${key}`, ttlSeconds, JSON.stringify(value));
        result = { ok: true, key, ttl: ttlSeconds };
        break;

      case "delete":
        await redis("DEL", `cache:${key}`);
        result = { ok: true, key };
        break;

      case "invalidate_pattern":
        const keys = await redis("KEYS", `cache:${key}*`);
        if (keys && Array.isArray(keys)) {
          for (const k of keys) {
            await redis("DEL", k);
          }
        }
        result = { ok: true, deleted: keys?.length || 0 };
        break;

      case "health":
        const start = Date.now();
        await redis("PING");
        result = { ok: true, latency: Date.now() - start };
        break;

      default:
        return new Response(JSON.stringify({ error: "Invalid action" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
