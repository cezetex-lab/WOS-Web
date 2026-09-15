/**
 * supabase-browser.ts — Supabase client + session management (TypeScript)
 *
 * Drop-in typed replacement for supabase-browser.js.
 * All existing imports from './supabase-browser' continue to work.
 */

import { createClient, Session, User } from '@supabase/supabase-js';
import { checkRateLimit } from './rate-limiter';
import type { UserSession, CurrentUserContext } from '@/types';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// ─── RPC with rate limiting ───────────────────────────────────

// NOTE: default `any` because Supabase `.rpc()` rows are unshaped at the client
// (no static column info). Known RPCs are typed explicitly via typed-wrapped
// helpers that pass `<ConcreteType>`; untyped call sites get `any` (as in the
// original JS client), NOT a forced `unknown` that would cascade into setState.
export async function rpc<T = any>(
  fn: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  const { allowed, retryAfter } = checkRateLimit(fn);
  if (!allowed) {
    console.error(`[RPC] Rate limited for ${fn}. Retry in ${retryAfter}s`);
    return { ok: false, msg: `Rate limited. Retry in ${retryAfter}s.` } as T;
  }

  const { data, error } = await supabase.rpc(fn, params);
  if (error) {
    console.error(`[RPC] Error calling ${fn}:`, error);
    return { ok: false, msg: error.message } as T;
  }
  return (data || { ok: false, msg: 'No response' }) as T;
}

// ─── Session Management ───────────────────────────────────────

let _sessionCache: UserSession | null = null;
const SESSION_STORAGE_KEY = 'wos_user';

function loadSessionCache(): UserSession | null {
  if (_sessionCache) return _sessionCache;
  try {
    const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
    if (raw) {
      const s = JSON.parse(raw) as UserSession;
      if (s?.nrp && (!s.expires_at || new Date(s.expires_at) > new Date())) {
        _sessionCache = s;
        return _sessionCache;
      }
      sessionStorage.removeItem(SESSION_STORAGE_KEY);
    }
  } catch { /* ignore corrupt storage */ }
  return null;
}

export function setSession(user: UserSession | null): void {
  _sessionCache = user;
  try {
    if (user) sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(user));
    else sessionStorage.removeItem(SESSION_STORAGE_KEY);
  } catch { /* storage full / private mode */ }
}

export function getSession(): UserSession | null {
  try {
    const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as UserSession;
    if (s?.nrp && (!s.expires_at || new Date(s.expires_at) > new Date())) return s;
    sessionStorage.removeItem(SESSION_STORAGE_KEY);
    return null;
  } catch {
    try { sessionStorage.removeItem(SESSION_STORAGE_KEY); } catch {}
    return null;
  }
}

export async function initSession(): Promise<UserSession | null> {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (session) {
      const { data, error } = await supabase.rpc('get_current_user_context');
      if (!error && data) {
        const ctx: UserSession = {
          nrp: data.nrp,
          nama: data.nama,
          role: data.role,
          role_level: data.role_level,
          business_unit_id: data.business_unit_id,
          divisi: data.divisi,
          posisi: data.posisi,
          is_owner: data.is_owner || data.role === 'owner',
          email: data.email,
        };
        setSession(ctx);
        return ctx;
      }
    }

    const restored = loadSessionCache();
    if (restored?.token) return restored;

    _sessionCache = null;
    return null;
  } catch {
    _sessionCache = loadSessionCache();
    return _sessionCache;
  }
}

export function clearSession(): void {
  _sessionCache = null;
  try { sessionStorage.removeItem(SESSION_STORAGE_KEY); } catch {}
  supabase.auth.signOut().catch(() => {});
}

// ─── Auth Helpers ─────────────────────────────────────────────

export async function syncSupabaseAuth(
  email: string,
  password: string,
): Promise<{ session: Session; user: User } | null> {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return null;
    return data;
  } catch {
    return null;
  }
}

export function getAuthUser() {
  return supabase.auth.getUser();
}

export async function signOutAuth(): Promise<void> {
  await supabase.auth.signOut();
}
