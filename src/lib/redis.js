// ============================================================
// redis.js — SERVER-ONLY (NOT for browser use)
// ============================================================
// File ini HANYA untuk reference / Edge Functions.
// Frontend SPA tidak bisa akses Redis langsung.
// Gunakan cache.js untuk client-side caching.
// ============================================================

// ⚠️ SERVER-ONLY — Jangan import di frontend!
// Untuk Edge Functions, gunakan:
//   import { Redis } from '@upstash/redis';
//
// Untuk frontend, gunakan:
//   import { cachedRpc, cacheGet, cacheSet } from './cache';

console.warn('redis.js is server-only and should not be imported in browser code.');
