import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN,
});

export default redis;

// Cache helper functions
export async function getCached(key, ttlSeconds = 300) {
  try {
    const cached = await redis.get(key);
    return cached;
  } catch {
    return null;
  }
}

export async function setCached(key, value, ttlSeconds = 300) {
  try {
    await redis.set(key, value, { ex: ttlSeconds });
  } catch {}
}

export async function invalidateCache(pattern) {
  try {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  } catch {}
}
