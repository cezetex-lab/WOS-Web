/**
 * edge-functions.ts — Supabase Edge Function calls (TypeScript)
 *
 * Typed module — drop-in replacement for the pre-TypeScript version.
 */

import { supabase } from './supabase-browser';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

interface EdgeFunctionOptions {
  auth?: 'anon' | 'user' | 'apikey';
  timeoutMs?: number;
  throwOnError?: boolean;
}

function functionUrl(fn: string): string {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error('Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY');
  }
  return `${SUPABASE_URL}/functions/v1/${fn}`;
}

async function postEdge<T = Record<string, unknown>>(
  fn: string,
  body: Record<string, unknown> = {},
  opts: EdgeFunctionOptions = {},
): Promise<T> {
  const { auth = 'anon', timeoutMs, throwOnError } = opts;

  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (auth === 'user') {
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

  return res.json() as Promise<T>;
}

export function callEdgeFunction<T = Record<string, unknown>>(
  fn: string,
  body: Record<string, unknown> = {},
  opts: EdgeFunctionOptions = {},
): Promise<T> {
  return postEdge<T>(fn, body, opts);
}

export function callEdgeFunctionAuth<T = Record<string, unknown>>(
  fn: string,
  body: Record<string, unknown> = {},
  opts: EdgeFunctionOptions = {},
): Promise<T> {
  return postEdge<T>(fn, body, { ...opts, auth: 'user' });
}

export function callEdgeFunctionApiKey<T = Record<string, unknown>>(
  fn: string,
  body: Record<string, unknown> = {},
  opts: EdgeFunctionOptions = {},
): Promise<T> {
  return postEdge<T>(fn, body, { ...opts, auth: 'apikey' });
}
