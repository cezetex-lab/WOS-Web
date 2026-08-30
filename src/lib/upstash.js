// ============================================================
// upstash.js — SERVER-ONLY (NOT for browser use)
// ============================================================
// File ini HANYA untuk reference / Edge Functions.
// Frontend SPA tidak bisa akses Upstash Redis langsung.
// Gunakan cache.js untuk client-side caching.
// ============================================================

// ⚠️ SERVER-ONLY — Jangan import di frontend!
// Untuk Edge Functions, gunakan fetch-based Upstash client:
//
//   const UPSTASH_URL = process.env.UPSTASH_REDIS_REST_URL;
//   const UPSTASH_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;
//
//   async function upstashCommand(command, ...args) {
//     const res = await fetch(UPSTASH_URL, {
//       method: 'POST',
//       headers: {
//         Authorization: \`Bearer \${UPSTASH_TOKEN}\`,
//         'Content-Type': 'application/json',
//       },
//       body: JSON.stringify([command, ...args]),
//     });
//     const data = await res.json();
//     return data.result;
//   }
//
// Untuk frontend, gunakan:
//   import { cachedRpc, cacheGet, cacheSet } from './cache';

console.warn('upstash.js is server-only and should not be imported in browser code.');
