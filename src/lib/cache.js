// ============================================================
// cache.js — Client-side Cache Layer
// localStorage + TTL + Supabase RPC server-side cache
// ============================================================
// Strategi: Cache di browser (localStorage) untuk performa,
// Supabase RPC untuk cache server-side (Redis via Edge Functions)
// ============================================================

import { supabase } from './supabase-browser';

const CACHE_PREFIX = 'wos_cache:';
const DEFAULT_TTL = 300; // 5 menit

// ──────────────────────────────────────────────────────────────
// LOCALSTORAGE CACHE (Client-side)
// ──────────────────────────────────────────────────────────────

/**
 * Get cached data from localStorage
 * @param {string} key - Cache key
 * @returns {any|null} Cached data or null if expired/missing
 */
export function cacheGet(key) {
  try {
    const raw = localStorage.getItem(CACHE_PREFIX + key);
    if (!raw) return null;

    const { data, expires } = JSON.parse(raw);
    if (Date.now() > expires) {
      localStorage.removeItem(CACHE_PREFIX + key);
      return null;
    }
    return data;
  } catch {
    return null;
  }
}

/**
 * Set data in localStorage with TTL
 * @param {string} key - Cache key
 * @param {any} data - Data to cache
 * @param {number} ttlSeconds - Time to live in seconds (default: 300)
 */
export function cacheSet(key, data, ttlSeconds = DEFAULT_TTL) {
  try {
    const entry = {
      data,
      expires: Date.now() + ttlSeconds * 1000,
      cachedAt: new Date().toISOString(),
    };
    localStorage.setItem(CACHE_PREFIX + key, JSON.stringify(entry));
  } catch (e) {
    // localStorage full — cleanup old entries
    cleanupOldCache();
    try {
      localStorage.setItem(CACHE_PREFIX + key, JSON.stringify({ data, expires: Date.now() + ttlSeconds * 1000 }));
    } catch {}
  }
}

/**
 * Remove specific cache entry
 * @param {string} key - Cache key
 */
export function cacheRemove(key) {
  localStorage.removeItem(CACHE_PREFIX + key);
}

/**
 * Clear all cache entries
 */
export function cacheClear() {
  const keys = Object.keys(localStorage).filter(k => k.startsWith(CACHE_PREFIX));
  keys.forEach(k => localStorage.removeItem(k));
}

/**
 * Remove expired cache entries
 */
function cleanupOldCache() {
  const keys = Object.keys(localStorage).filter(k => k.startsWith(CACHE_PREFIX));
  const now = Date.now();
  keys.forEach(k => {
    try {
      const { expires } = JSON.parse(localStorage.getItem(k) || '{}');
      if (expires && now > expires) localStorage.removeItem(k);
    } catch {
      localStorage.removeItem(k);
    }
  });
}

// ──────────────────────────────────────────────────────────────
// CACHED RPC — Panggil RPC dengan auto-cache
// ──────────────────────────────────────────────────────────────

/**
 * Call RPC with client-side caching
 * @param {string} fn - RPC function name
 * @param {object} params - RPC parameters
 * @param {number} ttlSeconds - Cache TTL (default: 300s)
 * @returns {any} RPC result
 */
export async function cachedRpc(fn, params = {}, ttlSeconds = DEFAULT_TTL) {
  const cacheKey = `rpc:${fn}:${JSON.stringify(params)}`;

  // Check cache first
  const cached = cacheGet(cacheKey);
  if (cached !== null) {
    return cached;
  }

  // Call RPC
  const { data, error } = await supabase.rpc(fn, params);
  if (error) {
    console.error(`cachedRpc ${fn} error:`, error);
    return { ok: false, msg: error.message };
  }

  const result = data || { ok: false, msg: 'No response' };

  // Cache successful results
  if (result && result.ok !== false) {
    cacheSet(cacheKey, result, ttlSeconds);
  }

  return result;
}

/**
 * Invalidate cache for a specific RPC function
 * @param {string} fn - RPC function name
 */
export function invalidateRpcCache(fn) {
  const keys = Object.keys(localStorage).filter(k => k.startsWith(CACHE_PREFIX + `rpc:${fn}:`));
  keys.forEach(k => localStorage.removeItem(k));
}

/**
 * Invalidate all RPC cache
 */
export function invalidateAllCache() {
  cacheClear();
}

// ──────────────────────────────────────────────────────────────
// SERVER-SIDE CACHE (via Supabase RPC)
// Untuk data yang perlu di-cache di server (Redis via Edge Functions)
// ──────────────────────────────────────────────────────────────

/**
 * Get from server-side cache (via Supabase RPC)
 * @param {string} key - Cache key
 * @returns {any|null} Cached data
 */
export async function serverCacheGet(key) {
  try {
    const { data, error } = await supabase.rpc('cache_get', { p_key: key });
    if (error || !data) return null;
    return data;
  } catch {
    return null;
  }
}

/**
 * Set server-side cache (via Supabase RPC)
 * @param {string} key - Cache key
 * @param {any} value - Value to cache (will be JSON.stringify'd)
 * @param {number} ttlSeconds - TTL in seconds
 */
export async function serverCacheSet(key, value, ttlSeconds = 300) {
  try {
    await supabase.rpc('cache_set', {
      p_key: key,
      p_value: JSON.stringify(value),
      p_ttl: ttlSeconds,
    });
  } catch (e) {
    console.error('serverCacheSet error:', e);
  }
}

// ──────────────────────────────────────────────────────────────
// CACHE STATISTICS
// ──────────────────────────────────────────────────────────────

/**
 * Get cache statistics
 */
export function getCacheStats() {
  const keys = Object.keys(localStorage).filter(k => k.startsWith(CACHE_PREFIX));
  let totalSize = 0;
  let validCount = 0;
  let expiredCount = 0;
  const now = Date.now();

  keys.forEach(k => {
    try {
      const raw = localStorage.getItem(k);
      totalSize += raw?.length || 0;
      const { expires } = JSON.parse(raw || '{}');
      if (expires && now > expires) expiredCount++;
      else validCount++;
    } catch {}
  });

  return {
    totalEntries: keys.length,
    validEntries: validCount,
    expiredEntries: expiredCount,
    totalSizeKB: (totalSize / 1024).toFixed(1),
  };
}
