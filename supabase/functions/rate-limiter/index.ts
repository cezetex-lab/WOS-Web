// ============================================================
// rate-limiter/index.ts — Supabase Edge Function
// In-memory rate limiting (free tier, no Upstash needed)
// Deploy: supabase functions deploy rate-limiter
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// In-memory rate limit store (resets on cold start — acceptable for free tier)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

const RATE_LIMITS: Record<string, { max: number; windowMs: number }> = {
  default: { max: 120, windowMs: 60_000 },
  rpc: { max: 60, windowMs: 60_000 },
  login: { max: 10, windowMs: 300_000 },
  ai: { max: 20, windowMs: 60_000 },
};

function getClientIp(req: Request): string {
  return (
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    req.headers.get("x-real-ip") ||
    "unknown"
  );
}

function getCategory(pathname: string): string {
  if (pathname.includes("login")) return "login";
  if (pathname.includes("ai-copilot")) return "ai";
  if (pathname.includes("rpc")) return "rpc";
  return "default";
}

function isRateLimited(key: string, config: { max: number; windowMs: number }): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(key);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + config.windowMs });
    return false;
  }

  entry.count++;
  if (entry.count > config.max) return true;
  return false;
}

// Cleanup old entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitMap) {
    if (now > entry.resetAt) rateLimitMap.delete(key);
  }
}, 300_000);

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  const ip = getClientIp(req);
  const url = new URL(req.url);
  const category = getCategory(url.pathname);
  const config = RATE_LIMITS[category] || RATE_LIMITS.default;
  const key = `${ip}:${category}`;

  if (isRateLimited(key, config)) {
    return new Response(
      JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
      {
        status: 429,
        headers: {
          "Content-Type": "application/json",
          "X-RateLimit-Limit": String(config.max),
          "X-RateLimit-Remaining": "0",
          "X-RateLimit-Reset": String(Math.ceil((rateLimitMap.get(key)?.resetAt || Date.now()) / 1000)),
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  }

  const remaining = config.max - (rateLimitMap.get(key)?.count || 0);

  return new Response(
    JSON.stringify({ ok: true, remaining, limit: config.max }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "X-RateLimit-Limit": String(config.max),
        "X-RateLimit-Remaining": String(Math.max(0, remaining)),
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
});
