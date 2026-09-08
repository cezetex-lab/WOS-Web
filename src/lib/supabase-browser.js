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
//
// WORKER LOGIN FIX: sesi worker hanya RPC-token (bukan Supabase Auth), jadi
// in-memory cache hilang saat full-page reload (window.location.href) dan user
// terlempar balik ke halaman login. Karena itu sesi juga dipersist ke
// sessionStorage (per-tab; key kontrak: 'wos_user') dan dipulihkan oleh
// loadSessionCache()/initSession() saat app dimuat ulang. Sesi admin/owner
// tetap lebih mengutamakan Supabase Auth.
let _sessionCache = null;
const SESSION_STORAGE_KEY = 'wos_user';

function loadSessionCache() {
  if (_sessionCache) return _sessionCache;
  try {
    const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
    if (raw) {
      const s = JSON.parse(raw);
      if (s?.nrp && (!s.expires_at || new Date(s.expires_at) > new Date())) {
        _sessionCache = s;
        return _sessionCache;
      }
      sessionStorage.removeItem(SESSION_STORAGE_KEY);
    }
  } catch { /* ignore corrupt storage */ }
  return null;
}

export function setSession(user) {
  _sessionCache = user;
  try {
    if (user) sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(user));
    else sessionStorage.removeItem(SESSION_STORAGE_KEY);
  } catch { /* storage full / private mode — sesi tetap jalan in-memory */ }
}

// SYNC getter — sessionStorage adalah source of truth (dibaca langsung setiap
// panggilan, tanpa fallback ke cache in-memory agar tidak mengembalikan data
// basi dari sesi lain). JSON korup dibersihkan dan dianggap tidak ada sesi.
export function getSession() {
  try {
    const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw);
    if (s?.nrp && (!s.expires_at || new Date(s.expires_at) > new Date())) return s;
    sessionStorage.removeItem(SESSION_STORAGE_KEY);
    return null;
  } catch {
    try { sessionStorage.removeItem(SESSION_STORAGE_KEY); } catch {}
    return null;
  }
}

// ASYNC initializer — call once at app startup
// Fetches user context from backend using Supabase Auth JWT.
// Workers (login via RPC token, bukan Supabase Auth) dipulihkan dari
// localStorage — tanpa ini setiap reload mengembalikan user ke halaman login.
export async function initSession() {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (session) {
      const { data, error } = await supabase.rpc('get_current_user_context');
      if (!error && data) {
        const ctx = {
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
        // Persist admin/owner context ke sessionStorage juga — tanpa ini
        // getSession() (sync, baca storage) mengembalikan null untuk admin,
        // sehingga useAdminAuth/RoleGuard menilai role kosong dan
        // me-redirect semua sub-halaman admin balik ke /admin.
        setSession(ctx);
        return ctx;
      }
    }

    // Worker fallback: pulihkan sesi RPC-token dari sessionStorage
    const restored = loadSessionCache();
    if (restored?.token) return restored;

    _sessionCache = null;
    return null;
  } catch {
    _sessionCache = loadSessionCache();
    return _sessionCache;
  }
}

export function clearSession() {
  _sessionCache = null;
  try { sessionStorage.removeItem(SESSION_STORAGE_KEY); } catch {}
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
