/**
 * supabase-browser.ts — Supabase client + session management (TypeScript)
 *
 * Typed module — drop-in replacement for the pre-TypeScript version.
 * All existing imports from './supabase-browser' continue to work.
 */

import { createClient, Session, User } from '@supabase/supabase-js';
import { checkRateLimit } from './rate-limiter';
import type { UserSession, CurrentUserContext, RpcError, RpcErrorKind } from '@/types';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// ─── RPC with rate limiting ───────────────────────────────────

// NOTE: default `any` because Supabase `.rpc()` rows are unshaped at the client
// (no static column info). Known RPCs are typed explicitly via typed-wrapped
// helpers that pass `<ConcreteType>`; untyped call sites get `any` (as in the
// original JS client), NOT a forced `unknown` that would cascade into setState.

/**
 * Kontrak RPC (audit L1) — kegagalan TIDAK lagi disamarkan sebagai hasil sukses:
 *  - sukses  → payload apa adanya (`T`)
 *  - gagal   → `RpcError` (`{ ok: false, msg, kind }`) yang eksplisit di tipe
 * Versi lama mengembalikan `{ ok:false, msg } as T`, sehingga pemanggil yang
 * mengharap array/objek menerima bentuk salah TANPA error tipe. Pemanggil
 * bertipe kini WAJIB mempersempit; pemanggil tanpa generic (`T = any`) tidak
 * terpengaruh sehingga migrasi bisa bertahap (241 call site).
 */
function rpcError(fn: string, kind: RpcErrorKind, msg: string): RpcError {
  return { ok: false, msg, kind };
}

// OPS-11: cache + dedupe in-flight untuk RPC baca publik `get_branding`.
// Branding jarang berubah → 1x per 5 menit per tab (stale sedikit dapat diterima).
// Dedupe in-flight: N komponen yang menembak paralel (mis. AppDrawer + Home, atau
// duplikasi effect oleh StrictMode di dev) berbagi SATU permintaan jaringan, dan
// remount saat in-flight pun tidak menembak ulang. Error TIDAK di-cache.
const BRANDING_CACHE_TTL_MS = 5 * 60 * 1000;
let brandingCache: { data: unknown; at: number } | null = null;
let brandingInFlight: Promise<unknown> | null = null;

/** OPS-11: buang cache branding — WAJIB dipanggil setelah `update_branding` sukses. */
export function invalidateBrandingCache(): void {
  brandingCache = null;
}

export async function rpc<T = any>(
  fn: string,
  params: Record<string, unknown> = {},
): Promise<T | RpcError> {
  const { allowed, retryAfter } = checkRateLimit(fn);
  if (!allowed) {
    return rpcError(fn, 'rate_limited', `Rate limited. Retry in ${retryAfter}s.`);
  }

  // OPS-11: get_branding tanpa parameter → jalur cache + dedupe in-flight (lihat blok di atas).
  if (fn === 'get_branding' && Object.keys(params).length === 0) {
    if (brandingCache && Date.now() - brandingCache.at < BRANDING_CACHE_TTL_MS) {
      return brandingCache.data as T;
    }
    if (!brandingInFlight) {
      brandingInFlight = (async () => {
        try {
          const { data, error } = await supabase.rpc('get_branding', {});
          const result: unknown = error
            ? rpcError('get_branding', 'transport', error.message)
            : (data === null || data === undefined)
              ? rpcError('get_branding', 'no_response', 'No response')
              : data;
          if (!isRpcError(result)) brandingCache = { data: result, at: Date.now() }; // error TIDAK di-cache
          return result;
        } finally {
          brandingInFlight = null;
        }
      })();
    }
    return brandingInFlight as Promise<T | RpcError>;
  }

  const { data, error } = await supabase.rpc(fn, params);
  if (error) return rpcError(fn, 'transport', error.message);
  // Hanya null/undefined yang dianggap "tidak ada respons". Nilai falsy yang SAH
  // (mis. `false` dari check_module_access) adalah hasil sukses — versi lama
  // memakai `data || {...}` sehingga `false` berubah menjadi error palsu.
  if (data === null || data === undefined) {
    return rpcError(fn, 'no_response', 'No response');
  }
  return data;
}

/**
 * Type guard untuk mempersempit hasil `rpc()`. Sengaja memeriksa `kind` (bukan hanya
 * `ok: false`) supaya kegagalan TRANSPORT tidak tertukar dengan payload domain yang
 * memang mengembalikan `{ ok: false, msg }` (mis. kredensial login salah) — payload
 * seperti itu tetap hasil sukses dari sudut pandang transport.
 */
export function isRpcError(x: unknown): x is RpcError {
  if (typeof x !== 'object' || x === null) return false;
  const kind = (x as { kind?: unknown }).kind;
  return (x as { ok?: unknown }).ok === false
    && (kind === 'rate_limited' || kind === 'transport' || kind === 'no_response');
}

// ─── Session Management ───────────────────────────────────────

let _sessionCache: UserSession | null = null;

// Key v2: blok `wos_user` (skema lama — tanpa `entry`/`expires_at`, masih menyimpan
// `token`) sengaja DITINGGALKAN supaya user lama dipaksa login ulang SEKALI. Inilah
// yang menutup bypass isolasi sesi legacy, bukan cek longgar per-halaman.
const SESSION_STORAGE_KEY = 'wos_user_v2';
const LEGACY_SESSION_STORAGE_KEY = 'wos_user';

// Batas umur cache sesi di client. Authz sesungguhnya tetap dari JWT Supabase +
// authz_* di DB (jangan pernah percaya blob ini); TTL ini hanya memastikan sesi
// yang tersimpan punya masa berlaku — bukan hidup selamanya.
const SESSION_TTL_MS = 8 * 60 * 60 * 1000;

/** Sesi valid WAJIB punya nrp + `expires_at` yang bisa diparse dan masih di masa depan (fail-closed). */
function isSessionValid(s: UserSession | null): s is UserSession {
  if (!s?.nrp || !s.expires_at) return false;
  const exp = new Date(s.expires_at).getTime();
  return Number.isFinite(exp) && exp > Date.now();
}

/** Hormati `expires_at` dari server bila valid & masih berlaku; selain itu stempel TTL lokal. */
function normalizeExpiry(raw?: string): string {
  const t = raw ? new Date(raw).getTime() : NaN;
  if (Number.isFinite(t) && t > Date.now()) return new Date(t).toISOString();
  return new Date(Date.now() + SESSION_TTL_MS).toISOString();
}

/** `entry` diturunkan dari role bila pemanggil tidak menyetelnya (satu choke point, G2). */
function entryFromRole(role?: string, isOwner?: boolean): UserSession['entry'] {
  if (isOwner || role === 'owner') return 'owner';
  if (role?.startsWith('admin_')) return 'admin';
  if (role === 'manager') return 'dashboard';
  return 'worker';
}

function purgeLegacySession(): void {
  try { sessionStorage.removeItem(LEGACY_SESSION_STORAGE_KEY); } catch { /* private mode */ }
}

function loadSessionCache(): UserSession | null {
  purgeLegacySession();
  if (_sessionCache && isSessionValid(_sessionCache)) return _sessionCache;
  _sessionCache = null;
  try {
    const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
    if (raw) {
      const s = JSON.parse(raw) as UserSession;
      if (isSessionValid(s)) {
        _sessionCache = s;
        return _sessionCache;
      }
      sessionStorage.removeItem(SESSION_STORAGE_KEY);
    }
  } catch { /* ignore corrupt storage */ }
  return null;
}

export function setSession(user: UserSession | null): void {
  if (!user) {
    _sessionCache = null;
    try { sessionStorage.removeItem(SESSION_STORAGE_KEY); } catch { /* private mode */ }
    return;
  }
  // Satu choke point: `entry` dan `expires_at` SELALU terisi, sehingga tidak ada lagi
  // sesi tanpa expiry (default-open) maupun sesi tanpa entry (legacy).
  const stamped: UserSession = {
    ...user,
    entry: user.entry ?? entryFromRole(user.role, user.is_owner),
    expires_at: normalizeExpiry(user.expires_at),
  };
  _sessionCache = stamped;
  try { sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(stamped)); } catch { /* storage full / private mode */ }
}

export function getSession(): UserSession | null {
  purgeLegacySession();
  try {
    const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as UserSession;
    if (isSessionValid(s)) return s;
    sessionStorage.removeItem(SESSION_STORAGE_KEY);
    return null;
  } catch {
    try { sessionStorage.removeItem(SESSION_STORAGE_KEY); } catch {}
    return null;
  }
}
// ─── Identity Guard ───────────────────────────────────────────
// Sumber identitas WAJIB dari session. DILARANG fallback hardcoded
// (mis. 'NRP001') — RPC akan berjalan dengan identitas orang lain (IDOR).
// Jika session hilang: redirect ke login lalu throw agar render berhenti.

export function requireNrp(): string {
  const nrp = getSession()?.nrp;
  if (!nrp) {
    if (typeof window !== 'undefined' && !window.location.pathname.startsWith('/owner')) {
      window.location.replace('/');
    }
    throw new Error('Session missing: NRP tidak tersedia');
  }
  return nrp;
}

export function requireSession(): UserSession {
  const s = getSession();
  if (!s) {
    if (typeof window !== 'undefined' && !window.location.pathname.startsWith('/owner')) {
      window.location.replace('/');
    }
    throw new Error('Session missing');
  }
  return s;
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

    // Sesi cache hanya boleh menghidupkan ulang sesi yang MASIH BERLAKU (punya
    // expires_at valid). Versi lama menerima `restored?.token` apa pun — token
    // app-level itu sudah tidak dipersist lagi (authz dari JWT + RPC di server).
    const restored = loadSessionCache();
    if (restored) return restored;

    _sessionCache = null;
    return null;
  } catch {
    _sessionCache = loadSessionCache();
    return _sessionCache;
  }
}

export function clearSession(): void {
  _sessionCache = null;
  purgeLegacySession();
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
