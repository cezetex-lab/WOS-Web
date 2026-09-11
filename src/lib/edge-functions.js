// ============================================================
// edge-functions.js — Panggilan Supabase Edge Functions (sumber tunggal)
// ============================================================
// Mengganti 4 duplikasi boilerplate fetch di Home.jsx, MfaSetup.jsx,
// PasswordReset.jsx, dan ChatCopilot.jsx.
//
// TIGA varian auth sesuai kontrak masing-masing edge function:
//  - callEdgeFunction       → Authorization: Bearer <anon key>  (default)
//  - callEdgeFunctionAuth   → Bearer <user JWT>, fallback anon  (mfa-service)
//  - callEdgeFunctionApiKey → header apikey (tanpa Bearer)       (password-reset)
//
// Timeout bersifat opsional — hanya worker-auth-sync yang perlu (5s,
// best-effort saat login; fetch default tidak pernah timeout).

import { supabase } from './supabase-browser';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

function functionUrl(fn) {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error('Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY');
  }
  return `${SUPABASE_URL}/functions/v1/${fn}`;
}

/**
 * POST JSON ke edge function.
 * @param {string} fn    nama edge function, mis. 'mfa-service'
 * @param {object} body  payload JSON
 * @param {object} [opts]
 * @param {'anon'|'user'|'apikey'} [opts.auth='anon']
 * @param {number}  [opts.timeoutMs]  AbortSignal.timeout bila diset
 * @param {boolean} [opts.throwOnError] throw Error dari body error bila !res.ok
 * @returns {Promise<object>} hasil res.json()
 */
async function postEdge(fn, body = {}, opts = {}) {
  const { auth = 'anon', timeoutMs, throwOnError } = opts;

  const headers = { 'Content-Type': 'application/json' };
  if (auth === 'user') {
    // Edge yang hardened menuntut JWT user (auth.uid() harus valid) —
    // fallback ke anon key hanya untuk action yang memang terbuka.
    const { data: { session } } = await supabase.auth.getSession();
    headers['Authorization'] = `Bearer ${session?.access_token || SUPABASE_ANON_KEY}`;
  } else if (auth === 'apikey') {
    headers['apikey'] = SUPABASE_ANON_KEY;
  } else {
    headers['Authorization'] = `Bearer ${SUPABASE_ANON_KEY}`;
  }

  const res = await fetch(functionUrl(fn), {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
    ...(timeoutMs ? { signal: AbortSignal.timeout(timeoutMs) } : {}),
  });

  if (throwOnError && !res.ok) {
    const err = await res.json().catch(() => ({ error: 'Network error' }));
    throw new Error(err.error || `HTTP ${res.status}`);
  }

  return res.json();
}

export function callEdgeFunction(fn, body = {}, opts = {}) {
  return postEdge(fn, body, opts);
}

export function callEdgeFunctionAuth(fn, body = {}, opts = {}) {
  return postEdge(fn, body, { ...opts, auth: 'user' });
}

export function callEdgeFunctionApiKey(fn, body = {}, opts = {}) {
  return postEdge(fn, body, { ...opts, auth: 'apikey' });
}
