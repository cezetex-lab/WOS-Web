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
    return { ok: false, msg: `Rate limited. Retry in ${retryAfter}s.` };
  }

  const { data, error } = await supabase.rpc(fn, params);
  if (error) {
    return { ok: false, msg: error.message };
  }
  return data || { ok: false, msg: 'No response' };
}

// Session helpers (P2 FIX: single source of truth)
export function setSession(user) {
  if (typeof window !== 'undefined') {
    sessionStorage.setItem('wos_user', JSON.stringify(user));
  }
}

export function getSession() {
  if (typeof window !== 'undefined') {
    try {
      const raw = sessionStorage.getItem('wos_user');
      return raw ? JSON.parse(raw) : null;
    } catch {
      sessionStorage.removeItem('wos_user');
      return null;
    }
  }
  return null;
}

export function clearSession() {
  if (typeof window !== 'undefined') {
    sessionStorage.removeItem('wos_user');
  }
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
