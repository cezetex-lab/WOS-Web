import { createClient } from '@supabase/supabase-js';

// Gunakan import.meta.env dengan prefix VITE_
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Helper: call RPC function
export async function rpc(fn, params = {}) {
  const { data, error } = await supabase.rpc(fn, params);
  if (error) {
    console.error(`RPC ${fn} error:`, error);
    return { ok: false, msg: error.message };
  }
  return data || { ok: false, msg: 'No response' };
}

// Session helpers
export function setSession(user) {
  if (typeof window !== 'undefined') {
    sessionStorage.setItem('wos_user', JSON.stringify(user));
  }
}

export function getSession() {
  if (typeof window !== 'undefined') {
    const raw = sessionStorage.getItem('wos_user');
    return raw ? JSON.parse(raw) : null;
  }
  return null;
}

export function clearSession() {
  if (typeof window !== 'undefined') {
    sessionStorage.removeItem('wos_user');
  }
}