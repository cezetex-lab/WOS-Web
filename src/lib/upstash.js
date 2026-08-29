// Upstash Redis client Ã¢â‚¬â€ works in Edge Runtime
// Uses REST API (not TCP), so it works in Vercel Edge Middleware

const UPSTASH_URL = process.env.UPSTASH_REDIS_REST_URL;
const UPSTASH_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

async function upstashCommand(command, ...args) {
  const res = await fetch(UPSTASH_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${UPSTASH_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify([command, ...args]),
  });

  if (!res.ok) {
    throw new Error(`Upstash error: ${res.status}`);
  }

  const data = await res.json();
  return data.result;
}

export const redis = {
  get: (key) => upstashCommand('GET', key),
  set: (key, value, opts) => {
    if (opts?.ex) return upstashCommand('SETEX', key, opts.ex, value);
    return upstashCommand('SET', key, value);
  },
  del: (key) => upstashCommand('DEL', key),
  incr: (key) => upstashCommand('INCR', key),
  expire: (key, ttl) => upstashCommand('EXPIRE', key, ttl),
  ttl: (key) => upstashCommand('TTL', key),
  ping: () => upstashCommand('PING'),
};

// ---- Session Store ----

export async function createSession(token, userData, ttlSeconds = 86400) {
  await redis.set(`session:${token}`, JSON.stringify(userData), { ex: ttlSeconds });
}

export async function getSession(token) {
  const data = await redis.get(`session:${token}`);
  if (!data) return null;
  try {
    return JSON.parse(data);
  } catch {
    return null;
  }
}

export async function deleteSession(token) {
  await redis.del(`session:${token}`);
}

// ---- Rate Limiting (Sliding Window) ----

export async function checkRateLimit(key, maxRequests = 100, windowSeconds = 60) {
  const rateKey = `rate:${key}`;
  const current = await redis.incr(rateKey);
  if (current === 1) {
    await redis.expire(rateKey, windowSeconds);
  }
  return {
    allowed: current <= maxRequests,
    current,
    limit: maxRequests,
    remaining: Math.max(0, maxRequests - current),
  };
}

// ---- Cache Layer (3-Tier) ----

export async function cacheGet(key) {
  const data = await redis.get(`cache:${key}`);
  if (!data) return null;
  try {
    return JSON.parse(data);
  } catch {
    return null;
  }
}

export async function cacheSet(key, value, ttlSeconds = 300) {
  await redis.set(`cache:${key}`, JSON.stringify(value), { ex: ttlSeconds });
}

export async function cacheInvalidate(key) {
  await redis.del(`cache:${key}`);
}

export async function cacheInvalidatePattern(pattern) {
  // Upstash doesn't support KEYS scan efficiently
  // We use a pattern list approach for known cache keys
  const keys = await upstashCommand('KEYS', `cache:${pattern}*`);
  if (keys && keys.length > 0) {
    for (const key of keys) {
      await redis.del(key);
    }
  }
}

// ---- Health Check ----

export async function healthCheck() {
  try {
    const start = Date.now();
    await redis.ping();
    const latency = Date.now() - start;
    return { ok: true, latency };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}
