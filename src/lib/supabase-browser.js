import { createClient } from '@supabase/supabase-js';
import { checkRateLimit } from './rate-limiter';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// P3 FIX: RPC with rate limiting
export async function rpc(fn, params = {}) {
  // Rate limit check
  const { allowed, retryAfter } = checkRateLimit(fn);
  if (!allowed) {
    console.error(`[RPC] Rate limited for ${fn}. Retry in ${retryAfter}s`);
    return { ok: false, msg: `Rate limited. Retry in ${retryAfter}s.` };
  }

  const { data, error } = await supabase.rpc(fn, params);
  if (error) {
    console.error(`[RPC] Error calling ${fn}:`, error);
    return { ok: false, msg: error.message };
  }
  return data || { ok: false, msg: 'No response' };
}

// P2 SECURITY FIX: In-memory session (not sessionStorage)
// Session data fetched from backend RPC via initSession(), cached in memory
// getSession() is SYNC (reads cache) — no callers need to change
let _sessionCache = null;

export function setSession(user) {
  _sessionCache = user;
}

// SYNC getter — reads from in-memory cache only
export function getSession() {
  return _sessionCache;
}

// ASYNC initializer — call once at app startup
// Fetches user context from backend using Supabase Auth JWT
export async function initSession() {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) { _sessionCache = null; return null; }

    const { data, error } = await supabase.rpc('get_current_user_context');
    if (error || !data) { _sessionCache = null; return null; }

    _sessionCache = {
      nrp: data.nrp,
      nama: data.nama,
      role: data.role,
      role_level: data.role_level,
      business_unit_id: data.business_unit_id,
      divisi: data.divisi,
      posisi: data.posisi,
      is_owner: data.is_owner,
      email: data.email
    };
    return _sessionCache;
  } catch {
    _sessionCache = null;
    return null;
  }
}

export function clearSession() {
  _sessionCache = null;
  supabase.auth.signOut().catch(() => {});
}

// V6: Sync login to Supabase Auth
export async function syncSupabaseAuth(email, password) {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      return null;
    }
    return data;
  } catch {
    return null;
  }
}

export function getAuthUser() {
  return supabase.auth.getUser();
}

export async function signOutAuth() {
  await supabase.auth.signOut();
}
