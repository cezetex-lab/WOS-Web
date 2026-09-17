import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { rpc, setSession, getSession, supabase, syncSupabaseAuth } from '@/lib/supabase-browser';
import { callEdgeFunction } from '@/lib/edge-functions';
import { isAdminRole } from '@/lib/role-utils';
import { useToast } from '@/lib/design-system';
import type { UserSession } from '@/types';

// Root-cause fix (audit): worker tidak pernah punya akun Supabase Auth →
// auth.uid() NULL → authz_current_nrp()/get_enabled_modules() menolak
// akses → DynamicRoutes me-redirect balik ke /.
// Tahap 4C FAST PATH: akun yang sudah diprovisi → signInWithPassword langsung
// (email sintetis satu sumber: lower(trim(nrp)) + '@insightwos.internal').
// Fallback: edge function worker-auth-sync (provisioning/rotasi + SESI — edge tidak
// pernah mengembalikan password ke client, audit S6).
// Non-fatal: gagal hanya me-log warning (login RPC tetap jalan).
async function provisionWorkerAuth(nrp: string, nik: string, password: string) {
  try {
    // FAST PATH - akun Supabase Auth sudah ada -> sign-in langsung
    const syntheticEmail = String(nrp).toLowerCase().trim() + '@insightwos.internal';
    const direct = await syncSupabaseAuth(syntheticEmail, password);
    if (direct) return true;
    // fast path gagal -> fallback edge

    // Timeout 5s: auth-sync bersifat best-effort — edge function yang hang
    // tidak boleh memblokir redirect login (fetch default tidak pernah timeout).
    // Edge mengembalikan SESI (access/refresh token), BUKAN password — password
    // plaintext tidak lagi melintas ke client (audit S6).
    type AuthSyncResponse = {
      ok?: boolean; msg?: string; email?: string;
      session?: { access_token?: string; refresh_token?: string };
    };
    const d = await callEdgeFunction<AuthSyncResponse>('worker-auth-sync', { nrp, nik, password }, { timeoutMs: 5000 });
    const accessToken = d?.session?.access_token;
    const refreshToken = d?.session?.refresh_token;
    if (!d?.ok || !accessToken || !refreshToken) {
      // provisionWorkerAuth tidak berhasil — user akan dapat alert warning
      return false;
    }
    const { error: setErr } = await supabase.auth.setSession({
      access_token: accessToken,
      refresh_token: refreshToken,
    });
    if (setErr) {
      return false;
    }
    return true;
  } catch (err: any) {
    return false;
  }
}


function checkMfaStatus(nrp: string) {
  return callEdgeFunction('mfa-service', { action: 'check', nrp });
}
function verifyMfaLogin(nrp: string, code: string) {
  return callEdgeFunction('mfa-service', { action: 'verify_login', nrp, code });
}

export default function Home() {
  const navigate = useNavigate();
  const toast = useToast();
  const [tab, setTab] = useState('worker');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [nrp, setNrp] = useState('');
  const [nik, setNik] = useState('');
  const [pass, setPass] = useState('');
  const [adminPass, setAdminPass] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [resetPass, setResetPass] = useState('');
  const [resetConfirm, setResetConfirm] = useState('');

  const [loginStep, setLoginStep] = useState('credentials');
  const [mfaRequired, setMfaRequired] = useState(false);
  const [mfaCode, setMfaCode] = useState('');
  const [mfaNrp, setMfaNrp] = useState('');
  const [mfaContext, setMfaContext] = useState('worker'); // 'worker' or 'admin'
  const [validatedNrp, setValidatedNrp] = useState('');
  const [adminValidated, setAdminValidated] = useState(false);
  const [brand, setBrand] = useState<{ company_name: string; logo_url: string; tagline?: string }>({ company_name: 'insightWIP', logo_url: '' });
  const [mfaEmail, setMfaEmail] = useState('');
  // Registration form state
  const [regNama, setRegNama] = useState('');
  const [regEmail, setRegEmail] = useState('');
  const [regDivisi, setRegDivisi] = useState('');
  const [regPosisi, setRegPosisi] = useState('');
  // Login mode toggle: 'email' (default) or 'nrp' (fallback)
  const [loginMode, setLoginMode] = useState('email');
  const [workerEmail, setWorkerEmail] = useState('');

  useEffect(() => {
    rpc('get_branding', {}).then(d => {
      if (d && d.company_name) setBrand({ company_name: d.company_name, logo_url: d.logo_url ?? '', tagline: d.tagline });
      // Dynamic favicon from branding
      if (d?.favicon_url) {
        const link = document.querySelector('link[rel="icon"]') as HTMLLinkElement | null;
        if (link) link.href = d.favicon_url;
      }
      // Dynamic title from branding
      if (d?.company_name) {
        document.title = d.company_name + ' — ' + (d.tagline || 'Workforce Intelligence');
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    const user = getSession();
    if (user) {
      // G2 / G1 — redirect berdasarkan `entry` (tab asal login / sesi), bukan hanya role.
      // Ini menyelaraskan dengan redirectAfterLogin() dan RoleGuard (entry check).
      const entry = user.entry || 'worker';
      if (entry === 'admin') window.location.href = '/admin';
      else if (entry === 'dashboard') window.location.href = '/dashboard';
      else window.location.href = '/worker';
    }
  }, []);

  function switchTab(t: string) {
    setTab(t);
    setError('');
    setLoginStep('credentials');
    setOtp('');
    setOtpCode('');
    setValidatedNrp('');
    setAdminValidated(false);
    setMfaRequired(false);
    setMfaNrp('');
    setMfaCode('');
    setMfaContext('worker');
    setNrp('');
    setNik('');
    setPass('');
    setAdminPass('');
    setResetPass('');
    setResetConfirm('');
    setLoginMode('email');
    setWorkerEmail('');
  }

  // Redirect sesuai TAB ASAL LOGIN — bukan role.
  // Admin juga bisa jadi worker: login lewat tab Pekerja → area pekerja.
  function redirectAfterLogin(entry: string) {
    if (entry === 'dashboard') window.location.href = '/dashboard';
    else if (entry === 'admin') window.location.href = '/admin';
    else window.location.href = '/worker';
  }

  // Finalisasi sesi worker dari response login_worker (termasuk pengecekan MFA)
  async function finalizeWorkerSession(d: any, creds: {nik?: string; password?: string}, entry: string) {
    if (!d || !d.ok) return;
    const role = d.role || 'worker';
    const sessionData = { role, nama: d.nama, nrp: d.nrp, entry: (entry || tab) as 'admin' | 'worker' | 'dashboard' | 'owner', role_level: d.role_level, business_unit_id: d.business_unit_id, business_unit: (d.business_unit || 'HQ') as string, tier: d.tier ?? 0, expires_at: d.expires_at };
    try {
      const mfaRes = await checkMfaStatus(d.nrp);
      if (mfaRes && mfaRes.mfa_enabled) {
        setSession(sessionData);
        setMfaNrp(d.nrp);
        setMfaContext('worker');
        setLoginStep('mfa');
        return;
      }
    } catch (err: any) {
      // MFA check gagal -> lanjut login (tidak memblokir user)
    }
    setSession(sessionData);
    // Provision akun Supabase Auth supaya auth.uid() tersedia (authz/RLS)
    if (creds?.nik && creds?.password) {
      const pw = await provisionWorkerAuth(d.nrp, creds.nik, creds.password);
      if (!pw) {
        toast.warning('Auth sync gagal — beberapa fitur mungkin terbatas. Silakan muat ulang halaman.');
      }
    }
    redirectAfterLogin(entry);
  }

  async function submitWorkerCredentials(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const isEmailMode = loginMode === 'email';
      const lockId = isEmailMode ? workerEmail : nrp;

      // V6: Check lockout before attempting login
      const lockCheck = await rpc('check_login_lockout', { p_identifier: lockId, p_attempt_type: 'worker' });
      if (lockCheck?.locked) {
        setError(lockCheck.reason || "Akun sementara dikunci");
        setLoading(false);
        return;
      }

      let d;
      if (isEmailMode) {
        d = await rpc('login_worker_by_email', { p_email: workerEmail, p_password: pass });
      } else {
        d = await rpc('login_worker', { p_nrp: nrp, p_nik: nik, p_password: pass });
      }
      if (!d.ok) {
        setError(d.msg || 'Login gagal');
        setLoading(false);
        return;
      }
      // Set NRP/NIK from response for downstream functions (finalizeWorkerSession, provisionWorkerAuth)
      if (d.nrp) setNrp(d.nrp);
      if (d.nik) setNik(d.nik);
      if (d.reset_required) {
        setValidatedNrp(d.nrp || nrp);
        setLoginStep('reset');
        setLoading(false);
        return;
      }
      // OTP wajib untuk tab dashboard: setelah user+password sukses, kirim OTP
      // via edge (password-reset) lalu input OTP sebelum redirect ke /dashboard.
      if (tab === 'dashboard') {
        setValidatedNrp(d.nrp || nrp);
        await requestAdminOtpForEntry(d.nrp || nrp, 'dashboard');
        setLoading(false);
        return;
      }
      await finalizeWorkerSession(d, { nik: d.nik || nik, password: pass }, tab);
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  // Kirim password baru (reset_required) lalu finalisasi sesi login yang tertunda
  async function submitResetPassword(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    if (!resetPass || resetPass.length < 8) {
      setError('Password baru minimal 8 karakter');
      return;
    }
    if (resetPass !== resetConfirm) {
      setError('Konfirmasi password tidak cocok');
      return;
    }
    setLoading(true);
    try {
      const d = await rpc('change_password', { p_nrp: validatedNrp, p_old_password: pass, p_new_password: resetPass });
      if (d.ok) {
        // change_password meng-invalidate semua session token lama -> login ulang untuk token baru
        const d2 = await rpc('login_worker', { p_nrp: validatedNrp, p_nik: nik, p_password: resetPass });
        if (d2 && d2.ok) {
          setError('');
          await finalizeWorkerSession(d2, { nik, password: resetPass }, tab);
        } else {
          window.location.href = '/';
        }
      } else {
        setError(d.msg || 'Gagal mengubah password');
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  async function submitAdminCredentials(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      // V6: Check lockout before attempting login
      const lockCheck = await rpc('check_login_lockout', { p_identifier: adminEmail, p_attempt_type: 'admin' });
      if (lockCheck?.locked) {
        setError(lockCheck.reason || "Akun sementara dikunci");
        setLoading(false);
        return;
      }

      // V6: Use Supabase Auth directly for admin login
      const authResult = await syncSupabaseAuth(adminEmail, adminPass);
      if (!authResult) {
        setError('Email atau password salah');
        setLoading(false);
        return;
      }
      // Look up employee by auth_id
      const ctx = await rpc('get_user_context_by_auth_id', { p_auth_id: authResult.user.id });
      if (!ctx.ok) {
        setError(ctx.msg || 'Akun tidak ditemukan di sistem');
        setLoading(false);
        return;
      }

      // Check MFA
      const mfaRes = await checkMfaStatus(ctx.nrp);
      if (mfaRes?.mfa_enabled) {
        setSession({ entry: 'admin', role: ctx.role, nama: ctx.nama, nrp: ctx.nrp, role_level: ctx.role_level, business_unit_id: ctx.business_unit_id, business_unit: ctx.unit_code || 'HQ', tier: ctx.tier, is_owner: ctx.role === 'owner' });
        setMfaNrp(ctx.nrp);
        setMfaEmail(adminEmail);
        setMfaContext('admin');
        setLoginStep('mfa');
        setLoading(false);
        return;
      }
      
      // No MFA — Kirim OTP via email (edge password-reset) sebelum redirect ke /admin.
      // OTP wajib untuk tab admin (keputusan user: "admin dan dashboard = setelah
      // sukses user+passwd, harus kirim OTP email dan input OTP baru diarahkan").
      const sessionData = { entry: 'admin' as const, role: ctx.role ?? '', nama: ctx.nama ?? '', nrp: ctx.nrp ?? '', role_level: ctx.role_level ?? 0, business_unit_id: ctx.business_unit_id ?? '', business_unit: (ctx.unit_code || 'HQ') as string, tier: ctx.tier ?? 0, is_owner: ctx.role === 'owner' };
      setSession(sessionData);
      setValidatedNrp(ctx.nrp);
      await requestAdminOtpForEntry(ctx.nrp, 'admin');
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  async function requestAdminOtp() {
    setError('');
    setLoading(true);
    try {
      const otpRes = await rpc('generate_admin_otp', {});
      if (otpRes.ok) {
        setOtpCode(otpRes.otp || '');
        setLoginStep('otp');
      } else {
        setError(otpRes.msg || 'Gagal generate OTP');
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  // Kirim OTP login via edge password-reset (action login_otp) setelah
  // user+password sukses (tab admin & dashboard). OTP wajib sebelum redirect.
  async function requestAdminOtpForEntry(nrp: string, entry: string) {
    setError('');
    setLoading(true);
    try {
      const r = await callEdgeFunction('password-reset', { action: 'login_otp', nrp });
      if (r?.ok) {
        if (r.dev_code) setOtpCode(String(r.dev_code));
        setLoginStep('otp');
      } else {
        setError(String(r?.msg || 'Gagal mengirim OTP ke email'));
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  async function submitWorkerOtp(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      if (tab === 'admin') {
        // OTP admin: verifikasi via RPC verify_admin_otp (identitas = NRP hasil
        // verify; bukan dari input user) — lalu cek MFA, finalisasi sesi.
        const d = await rpc('verify_admin_otp', { p_code: otp });
        if (d.ok) {
          const s: UserSession = { entry: (tab || 'admin') as 'admin' | 'worker' | 'dashboard' | 'owner', role: d.role || 'admin_pusat', nama: d.nama || 'Administrator', nrp: d.nrp || validatedNrp || '', role_level: d.role_level ?? 0, business_unit_id: d.business_unit_id ?? '' };
          const mfaRes = await checkMfaStatus(s.nrp);
          if (mfaRes?.mfa_enabled) {
            setSession(s);
            setMfaNrp(s.nrp);
            setMfaContext('admin');
            setLoginStep('mfa');
            setLoading(false);
            return;
          }
          setSession(s);
          if (adminEmail && adminPass) await syncSupabaseAuth(adminEmail, adminPass);
          redirectAfterLogin('admin');
        } else {
          setError(d.msg || 'OTP salah');
        }
        setLoading(false);
        return;
      }
      // OTP dashboard: kode dari edge password-reset (action login_otp) —
      // verify via edge (verify_login_otp) → identitas dari hasil verify.
      if (tab === 'dashboard') {
        const v = await callEdgeFunction('password-reset', { action: 'verify_login_otp', token: otp });
        if (v?.ok) {
        finalizeWorkerSession({ ...v, role: v.role || 'manager' }, {}, 'dashboard');
          setLoading(false);
          return;
        }
        setError(String(v?.msg || 'OTP salah'));
        setLoading(false);
        return;
      }
      const d = await rpc('verify_worker_otp', { p_nrp: validatedNrp, p_code: otp });
      if (d.ok) {
        // Check if MFA is enabled for this user
        const mfaRes = await checkMfaStatus(validatedNrp);
        if (mfaRes.mfa_enabled) {
          // MFA required — store OTP data, show MFA input
          setSession({ role: 'worker', entry: (tab || 'worker') as 'admin' | 'worker' | 'dashboard' | 'owner', role_level: (d as { role_level?: number }).role_level ?? 0, business_unit_id: (d as { business_unit_id?: string }).business_unit_id ?? '', nrp: (d as { nrp?: string }).nrp ?? validatedNrp ?? '', nama: (d as { nama?: string }).nama ?? '' });
          setMfaRequired(true);
          setMfaNrp(validatedNrp);
          setMfaContext('worker');
          setLoginStep('mfa');
          return;
        }
        // No MFA — direct sesuai tab asal login
        finalizeWorkerSession(d, {}, tab);
        if (nik && pass) {
          const pw = await provisionWorkerAuth(validatedNrp, nik, pass);
          if (!pw) {
            toast.warning('Auth sync gagal — beberapa fitur mungkin terbatas. Silakan muat ulang halaman.');
          }
        }
        redirectAfterLogin(tab);
      } else {
        setError(d.msg || 'OTP salah');
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  async function submitWorkerMfa(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    setLoading(false); // Ensure loading is reset
    const cleanCode = mfaCode.replace(/\s/g, '');
    if (cleanCode.length !== 6) {
      setError('Masukkan 6 digit kode TOTP');
      return;
    }
    setLoading(true);
    try {
      const d = await verifyMfaLogin(mfaNrp, cleanCode);
      if (d.mfa_verified) {
        // V6: sync Supabase Auth for gatekeeper RPCs
        // V6: For admin, Supabase Auth session already established in submitAdminCredentials
        // For worker, sync now with the worker's Supabase Auth credentials
        if (mfaContext === 'worker') {
          // Provision akun auth dengan kredensial asli (nik/pass state masih
          // memegang nilai dari form login) — bukan email sintetis + password
          // tebak-tebakan 'mfa-sync-'+nrp yang selalu gagal.
          const pw = await provisionWorkerAuth(mfaNrp, nik, pass);
          if (!pw) {
            toast.warning('Auth sync gagal — beberapa fitur mungkin terbatas. Silakan muat ulang halaman.');
          }
          redirectAfterLogin(tab);
        } else {
          window.location.href = '/admin';
        }
      } else {
        setError(String(d.msg || 'Kode TOTP salah'));
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  async function submitAdminOtp(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const d = await rpc('verify_admin_otp', { p_code: otp });
      if (d.ok) {
        const adminNrp = d.nrp || 'ADMIN';
        // Check MFA for admin
        const mfaRes = await checkMfaStatus(adminNrp);
        if (mfaRes.mfa_enabled) {
          setSession({ entry: (tab || 'admin') as 'admin' | 'worker' | 'dashboard' | 'owner', role: d.role || 'admin_pusat', nama: d.nama || 'Administrator', nrp: adminNrp, role_level: d.role_level ?? 0, business_unit_id: d.business_unit_id ?? '' });
          setMfaRequired(true);
          setMfaNrp(adminNrp);
          setMfaContext('admin');
          setLoginStep('mfa');
          setLoading(false);
          return;
        }
        setSession({ entry: (tab || 'admin') as 'admin' | 'worker' | 'dashboard' | 'owner', role: d.role || 'admin_pusat', nama: d.nama || 'Administrator', nrp: adminNrp, role_level: d.role_level ?? 0, business_unit_id: d.business_unit_id ?? '' });
        // V6: sync Supabase Auth for gatekeeper RPCs
        if (adminEmail) syncSupabaseAuth(adminEmail, adminPass);
        window.location.href = '/admin';
      } else {
        setError(d.msg || 'OTP salah');
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  async function resendOtp() {
    setError('');
    setLoading(true);
    try {
      let res;
      if (tab === 'admin') {
        res = await rpc('generate_admin_otp', {});
      } else if (tab === 'dashboard') {
        res = await callEdgeFunction('password-reset', { action: 'login_otp', nrp: validatedNrp });
        if (res?.ok && res.dev_code) res = { ...res, otp: res.dev_code };
      } else {
        res = await rpc('generate_worker_otp', { p_nrp: validatedNrp, p_nik: nik, p_password: pass });
      }
      if (res.ok) {
        setOtpCode(res.otp || '');
        setError('');
      } else {
        setError(res.msg || 'Gagal kirim ulang OTP');
      }
    } catch (err: any) {
      setError('Koneksi error: ' + (err instanceof Error ? err.message : String(err)));
    }
    setLoading(false);
  }

  function goBack() {
    setLoginStep('credentials');
    setOtp('');
    setOtpCode('');
    setError('');
    setAdminValidated(false);
    setLoading(false);
    setMfaCode('');
    setMfaRequired(false);
    setMfaNrp('');
    setMfaContext('worker');
    setResetPass('');
    setResetConfirm('');
  }

  const S: Record<string, React.CSSProperties> = {
    wrap: {
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg,#0f172a,#1e293b)',
      padding: '20px',
      fontFamily: '-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif',
      color: '#e2e8f0'
    },
    logo: { fontSize: '48px', marginBottom: '8px' },
    brand: {
      fontSize: '28px',
      fontWeight: '700',
      margin: '0',
      background: 'linear-gradient(135deg,#38bdf8,#818cf8)',
      WebkitBackgroundClip: 'text',
      WebkitTextFillColor: 'transparent'
    },
    sub: { fontSize: '13px', color: '#94a3b8', marginTop: '4px', textAlign: 'center', marginBottom: '24px' },
    tabs: { display: 'flex', gap: '8px', marginBottom: '20px', width: '100%', maxWidth: '360px' },
    tab: {
      flex: 1,
      padding: '10px 8px',
      borderWidth: '1px',
      borderStyle: 'solid',
      borderColor: '#334155',
      borderRadius: '8px',
      background: '#1e293b',
      color: '#94a3b8',
      fontSize: '12px',
      fontWeight: '600',
      cursor: 'pointer',
      transition: 'all 0.2s'
    },
    tabA: {
      background: '#38bdf8',
      color: '#0f172a',
      borderColor: '#38bdf8'
    },
    form: { width: '100%', maxWidth: '360px', display: 'flex', flexDirection: 'column', gap: '12px' },
    field: { display: 'flex', flexDirection: 'column', gap: '4px' },
    label: { fontSize: '13px', fontWeight: '600', color: '#cbd5e1' },
    inp: {
      padding: '12px 14px',
      borderRadius: '8px',
      border: '1px solid #334155',
      background: '#0f172a',
      color: '#e2e8f0',
      fontSize: '16px',
      outline: 'none',
      transition: 'border 0.2s'
    },
    btn: {
      padding: '14px',
      borderRadius: '8px',
      border: 'none',
      background: 'linear-gradient(135deg,#38bdf8,#818cf8)',
      color: '#fff',
      fontSize: '16px',
      fontWeight: '700',
      cursor: 'pointer',
      marginTop: '4px',
      transition: 'opacity 0.2s'
    },
    btnSmall: {
      padding: '8px 16px',
      borderRadius: '8px',
      border: 'none',
      background: 'transparent',
      color: '#38bdf8',
      fontSize: '13px',
      fontWeight: '600',
      cursor: 'pointer',
      textDecoration: 'underline'
    },
    btnBack: {
      padding: '8px 16px',
      borderRadius: '8px',
      border: '1px solid #334155',
      background: 'transparent',
      color: '#94a3b8',
      fontSize: '13px',
      fontWeight: '600',
      cursor: 'pointer'
    },
    err: {
      background: '#7f1d1d',
      border: '1px solid #dc2626',
      borderRadius: '8px',
      padding: '10px 14px',
      marginBottom: '12px',
      fontSize: '13px',
      color: '#fca5a5',
      width: '100%',
      maxWidth: '360px',
      textAlign: 'center'
    },
    otpInfo: {
      background: '#1e3a5f',
      border: '1px solid #38bdf8',
      borderRadius: '8px',
      padding: '12px 14px',
      marginBottom: '12px',
      fontSize: '13px',
      color: '#93c5fd',
      width: '100%',
      maxWidth: '360px',
      textAlign: 'center'
    },
    otpShow: {
      background: '#0f172a',
      border: '2px dashed #22c55e',
      borderRadius: '12px',
      padding: '16px',
      marginBottom: '12px',
      width: '100%',
      maxWidth: '360px',
      textAlign: 'center'
    },
    otpNumber: {
      fontSize: '36px',
      fontWeight: '900',
      letterSpacing: '10px',
      color: '#22c55e',
      fontFamily: 'monospace'
    },
    links: {
      display: 'flex',
      justifyContent: 'center',
      gap: '16px',
      marginTop: '8px',
      width: '100%',
      maxWidth: '360px'
    },
    link: {
      color: '#38bdf8',
      fontSize: '13px',
      fontWeight: '600',
      cursor: 'pointer',
      textDecoration: 'none',
      padding: '6px 12px',
      borderRadius: '6px',
      transition: 'background 0.2s'
    },
    otpInp: {
      padding: '14px',
      borderRadius: '8px',
      border: '2px solid #38bdf8',
      background: '#0f172a',
      color: '#e2e8f0',
      fontSize: '24px',
      fontWeight: '700',
      letterSpacing: '8px',
      textAlign: 'center',
      outline: 'none',
      width: '100%',
      maxWidth: '200px',
      margin: '0 auto'
    }
  };

  const btnLabel = loading ? '...' : (loginStep === 'otp' ? 'Verifikasi OTP' : 'Masuk');

  return (
    <div style={S.wrap}>
      <div style={{ textAlign: 'center', marginBottom: '24px' }}>
        <div style={S.logo}>{'\u{1F4CA}'}</div>
        <h1 style={S.brand}>{brand.company_name || 'insightWIP'}</h1>
        <p style={S.sub}>Workforce Intelligence Platform</p>
      </div>

      <div style={S.tabs}>
        {[['worker', '\u{1F464} Pekerja'], ['admin', '\u{1F3E2} Admin'], ['dashboard', '\u{1F4CA} Dashboard']].map(([k, l]) => (
          <button key={k} onClick={() => switchTab(k)} style={{ ...S.tab, ...(tab === k ? S.tabA : {}) }}>
            {l}
          </button>
        ))}
      </div>

      {error && <div style={S.err}>{error}</div>}

      {/* Worker Login */}
      {tab === 'worker' && loginStep === 'credentials' && (
        <form onSubmit={submitWorkerCredentials} style={S.form}>
          {loginMode === 'email' ? (
            <>
              <div style={S.field}>
                <label style={S.label}>Email</label>
                <input type="email" value={workerEmail} onChange={e => setWorkerEmail(e.target.value)} placeholder="Masukkan email" style={S.inp} required />
              </div>
              <div style={S.field}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <label style={S.label}>Password</label>
                  <a href="/reset-password" style={{ color: "#60a5fa", fontSize: 13 }}>Lupa Password?</a>
                </div>
                <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Masukkan password" style={S.inp} required />
              </div>
            </>
          ) : (
            <>
              <div style={S.field}>
                <label style={S.label}>NRP</label>
                <input value={nrp} onChange={e => setNrp(e.target.value)} placeholder="Masukkan NRP" style={S.inp} required />
              </div>
              <div style={S.field}>
                <label style={S.label}>NIK</label>
                <input value={nik} onChange={e => setNik(e.target.value)} placeholder="Masukkan NIK" style={S.inp} required />
              </div>
              <div style={S.field}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <label style={S.label}>Password</label>
                  <a href="/reset-password" style={{ color: "#60a5fa", fontSize: 13 }}>Lupa Password?</a>
                </div>
                <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Masukkan password" style={S.inp} required />
              </div>
            </>
          )}
          <button type="submit" style={S.btn} disabled={loading}>{btnLabel}</button>

          <div style={S.links}>
            <span style={S.link} onClick={() => setLoginMode(loginMode === 'email' ? 'nrp' : 'email')}>
              {loginMode === 'email' ? 'Masuk dengan NRP' : 'Masuk dengan Email'}
            </span>
            <span style={S.link} onClick={() => setLoginStep('register')}>Daftar Baru</span>
            <span style={S.link} onClick={() => setLoginStep('cek_daftar')}>Cek Daftar</span>
            <span style={S.link} onClick={() => alert('Login dulu, lalu buka menu MFA Setup di halaman utama.')}>MFA Setup</span>
          </div>
        </form>
      )}

      {/* Worker Reset Password (reset_required dari login_worker) */}
      {tab === 'worker' && loginStep === 'reset' && (
        <form onSubmit={submitResetPassword} style={S.form}>
          <div style={S.otpInfo}>🔑 Password Wajib Diganti — NRP: <strong>{validatedNrp}</strong></div>
          <div style={{ fontSize: '12px', color: '#94a3b8', textAlign: 'center', marginBottom: '12px' }}>
            Untuk keamanan, Anda harus membuat password baru sebelum masuk.
          </div>
          <div style={S.field}>
            <label style={S.label}>Password Baru (min. 8 karakter)</label>
            <input type="password" value={resetPass} onChange={e => setResetPass(e.target.value)} placeholder="Password baru" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>Konfirmasi Password Baru</label>
            <input type="password" value={resetConfirm} onChange={e => setResetConfirm(e.target.value)} placeholder="Ulangi password baru" style={S.inp} required />
          </div>
          <button type="submit" style={S.btn} disabled={loading}>{loading ? '...' : 'Simpan Password Baru'}</button>
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={goBack}>{'←'} Kembali</button>
          </div>
        </form>
      )}

      {tab === 'worker' && loginStep === 'otp' && (
        <form onSubmit={submitWorkerOtp} style={S.form}>
          <div style={S.otpInfo}>Kode OTP untuk NRP: <strong>{validatedNrp}</strong></div>
          {otpCode && (
            <div style={S.otpShow}>
              <div style={{ fontSize: '11px', color: '#94a3b8', marginBottom: '4px' }}>Kode OTP Anda:</div>
              <div style={S.otpNumber}>{otpCode}</div>
              <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '4px' }}>Berlaku 5 menit</div>
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <input value={otp} onChange={e => setOtp(e.target.value)} placeholder="000000" style={S.otpInp} maxLength={6} required autoFocus />
          </div>
          <button type="submit" style={S.btn} disabled={loading}>{btnLabel}</button>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '16px', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={goBack}>{'←'} Kembali</button>
            <button type="button" style={S.btnSmall} onClick={resendOtp} disabled={loading}>Kirim Ulang OTP</button>
          </div>
        </form>
      )}

      {/* Registration Form */}
      {tab === 'worker' && loginStep === 'register' && (
        <form onSubmit={async (e: React.FormEvent<HTMLFormElement>) => {
          e.preventDefault(); setLoading(true); setError('');
          try {
            if (!nik || nik.length !== 16) { setError('NIK harus tepat 16 digit angka'); setLoading(false); return; }
            const r = await rpc('submit_registration', {
              p_nrp: nrp, p_nik: nik, p_nama: regNama, p_password: pass,
              p_email: regEmail, p_divisi: regDivisi || null, p_posisi: regPosisi || null,
            });
            if (r?.ok) { alert(r.msg); setLoginStep('credentials'); }
            else { setError(r?.msg || 'Gagal mendaftar'); }
          } catch (err: any) { setError('Gagal mendaftar: ' + (err instanceof Error ? err.message : String(err))); }
          setLoading(false);
        }} style={S.form}>
          <div style={S.otpInfo}>📝 Formulir Pendaftaran Baru</div>
          <div style={{ fontSize: '12px', color: '#94a3b8', textAlign: 'center', marginBottom: '12px' }}>
            {brand.company_name || 'insightWOS'} — {brand.tagline || ''}
          </div>
          <div style={S.field}>
            <label style={S.label}>NRP *</label>
            <input value={nrp} onChange={e => setNrp(e.target.value)} placeholder="NRP" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>NIK *</label>
            <input value={nik} onChange={e => setNik(e.target.value.replace(/\D/g, '').slice(0, 16))} placeholder="NIK (16 digit angka)" style={S.inp} required pattern="\d{16}" maxLength={16} inputMode="numeric" title="NIK harus tepat 16 digit angka" />
          </div>
          <div style={S.field}>
            <label style={S.label}>Nama Lengkap *</label>
            <input value={regNama} onChange={e => setRegNama(e.target.value)} placeholder="Nama lengkap" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>Email *</label>
            <input type="email" value={regEmail} onChange={e => setRegEmail(e.target.value)} placeholder="email@contoh.com" style={S.inp} required />
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <div style={{ ...S.field, flex: 1 }}>
              <label style={S.label}>Divisi</label>
              <input value={regDivisi} onChange={e => setRegDivisi(e.target.value)} placeholder="Divisi" style={S.inp} />
            </div>
            <div style={{ ...S.field, flex: 1 }}>
              <label style={S.label}>Posisi</label>
              <input value={regPosisi} onChange={e => setRegPosisi(e.target.value)} placeholder="Posisi" style={S.inp} />
            </div>
          </div>
          <div style={S.field}>
            <label style={S.label}>Password *</label>
            <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Password (min. 6 karakter)" style={S.inp} required />
          </div>
          {error && <div style={{ color: '#f87171', fontSize: 12, textAlign: 'center', marginBottom: 8 }}>{error}</div>}
          <button type="submit" style={S.btn} disabled={loading}>{loading ? '...' : '📤 Daftar Sekarang'}</button>
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={() => setLoginStep('credentials')}>{'<'} Kembali</button>
          </div>
        </form>
      )}

      {/* Check Registration Status */}
      {tab === 'worker' && loginStep === 'cek_daftar' && (
        <form onSubmit={async (e: React.FormEvent<HTMLFormElement>) => {
          e.preventDefault(); setLoading(true); setError('');
          try {
            const r = await rpc('check_registration_status', { p_query: nrp });
            if (r?.data) {
              alert(`Status: ${r.data.status}\nNRP: ${r.data.nrp}\nNama: ${r.data.nama}`);
            } else { setError(r?.msg || 'Data tidak ditemukan'); }
          } catch (err: any) { setError('Gagal cek status: ' + (err instanceof Error ? err.message : String(err))); }
          setLoading(false);
        }} style={S.form}>
          <div style={S.otpInfo}>🔍 Cek Status Pendaftaran</div>
          <div style={S.field}>
            <label style={S.label}>NRP atau Email</label>
            <input value={nrp} onChange={e => setNrp(e.target.value)} placeholder="Masukkan NRP atau email" style={S.inp} required />
          </div>
          {error && <div style={{ color: '#f87171', fontSize: 12, textAlign: 'center', marginBottom: 8 }}>{error}</div>}
          <button type="submit" style={S.btn} disabled={loading}>{loading ? '...' : '🔍 Cek Status'}</button>
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={() => setLoginStep('credentials')}>{'<'} Kembali</button>
          </div>
        </form>
      )}

      {/* Worker + Dashboard MFA Step */}
      {(tab === 'worker' || tab === 'dashboard') && loginStep === 'mfa' && (
        <form onSubmit={submitWorkerMfa} style={S.form}>
          <div style={S.otpInfo}>🔐 Verifikasi MFA untuk NRP: <strong>{mfaNrp}</strong></div>
          <div style={{ fontSize: '12px', color: '#94a3b8', textAlign: 'center', marginBottom: '12px' }}>
            Masukkan 6 digit kode dari Authenticator App
          </div>
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <input value={mfaCode} onChange={e => setMfaCode(e.target.value.replace(/\s/g, '').slice(0, 6))} placeholder="000000" style={S.otpInp} maxLength={6} required autoFocus />
          </div>
          {error && <div style={{ color: '#ef4444', fontSize: '13px', textAlign: 'center', marginTop: '8px' }}>{error}</div>}
          <button type="submit" style={S.btn}>Verifikasi</button>
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={goBack}>{'←'} Kembali</button>
          </div>
        </form>
      )}

      {/* Admin Login */}
      {tab === 'admin' && loginStep === 'credentials' && !adminValidated && (
        <form onSubmit={submitAdminCredentials} style={S.form}>
          <div style={S.field}>
            <label style={S.label}>Email Admin</label>
            <input type="email" value={adminEmail} onChange={e => setAdminEmail(e.target.value)} placeholder="Masukkan email" style={S.inp} required />
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <label style={S.label}>Password</label>
              <a href="/reset-password" style={{ color: "#60a5fa", fontSize: 13 }}>Lupa Password?</a>
            </div>
            <input type="password" value={adminPass} onChange={e => setAdminPass(e.target.value)} placeholder="Masukkan password admin" style={S.inp} required />
          </div>

          <button type="submit" style={S.btn} disabled={loading}>{loading ? '...' : 'Verifikasi Password'}</button>
          <div style={S.links}>
            <span style={S.link} onClick={() => alert('Login dulu, lalu buka menu MFA Setup di halaman utama.')}>MFA Setup</span>
          </div>
        </form>
      )}

      {/* OTP Wajib — tab admin & dashboard (setelah user+password sukses).
          Worker tab memakai OTP hanya via requestAdminOtp (1-click flow). */}
      {(tab === 'admin' || tab === 'dashboard') && loginStep === 'otp' && (
        <form onSubmit={submitWorkerOtp} style={S.form}>
          <div style={S.otpInfo}>Kode OTP dikirim ke email untuk NRP: <strong>{validatedNrp}</strong></div>
          {otpCode && (
            <div style={S.otpShow}>
              <div style={{ fontSize: '11px', color: '#94a3b8', marginBottom: '4px' }}>Kode OTP (dev-mode):</div>
              <div style={S.otpNumber}>{otpCode}</div>
              <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '4px' }}>Berlaku 5 menit</div>
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <input value={otp} onChange={e => setOtp(e.target.value)} placeholder="000000" style={S.otpInp} maxLength={6} required autoFocus />
          </div>
          <button type="submit" style={S.btn} disabled={loading}>{btnLabel}</button>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '16px', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={goBack}>{'←'} Kembali</button>
            <button type="button" style={S.btnSmall} onClick={resendOtp} disabled={loading}>Kirim Ulang OTP</button>
          </div>
        </form>
      )}

      

      

      {/* Admin MFA Step */}
      {tab === 'admin' && loginStep === 'mfa' && (
        <form onSubmit={submitWorkerMfa} style={S.form}>
          <div style={S.otpInfo}>🔐 Verifikasi MFA untuk Admin</div>
          <div style={{ fontSize: '12px', color: '#94a3b8', textAlign: 'center', marginBottom: '12px' }}>
            Masukkan 6 digit kode dari Authenticator App
          </div>
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <input value={mfaCode} onChange={e => setMfaCode(e.target.value.replace(/\s/g, '').slice(0, 6))} placeholder="000000" style={S.otpInp} maxLength={6} required autoFocus />
          </div>
          {error && <div style={{ color: '#ef4444', fontSize: '13px', textAlign: 'center', marginTop: '8px' }}>{error}</div>}
          <button type="submit" style={S.btn}>Verifikasi</button>
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '4px' }}>
            <button type="button" style={S.btnBack} onClick={goBack}>{'←'} Kembali</button>
          </div>
        </form>
      )}

      {/* Dashboard Login (sama dengan worker, dengan tujuan dashboard) */}
      {tab === 'dashboard' && loginStep === 'credentials' && (
        <form onSubmit={submitWorkerCredentials} style={S.form}>
          {loginMode === 'email' ? (
            <>
              <div style={S.field}>
                <label style={S.label}>Email</label>
                <input type="email" value={workerEmail} onChange={e => setWorkerEmail(e.target.value)} placeholder="Masukkan email" style={S.inp} required />
              </div>
              <div style={S.field}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <label style={S.label}>Password</label>
                  <a href="/reset-password" style={{ color: "#60a5fa", fontSize: 13 }}>Lupa Password?</a>
                </div>
                <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Masukkan password" style={S.inp} required />
              </div>
            </>
          ) : (
            <>
              <div style={S.field}>
                <label style={S.label}>NRP</label>
                <input value={nrp} onChange={e => setNrp(e.target.value)} placeholder="Masukkan NRP" style={S.inp} required />
              </div>
              <div style={S.field}>
                <label style={S.label}>NIK</label>
                <input value={nik} onChange={e => setNik(e.target.value)} placeholder="Masukkan NIK" style={S.inp} required />
              </div>
              <div style={S.field}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <label style={S.label}>Password</label>
                  <a href="/reset-password" style={{ color: "#60a5fa", fontSize: 13 }}>Lupa Password?</a>
                </div>
                <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Masukkan password" style={S.inp} required />
              </div>
            </>
          )}
          <button type="submit" style={S.btn} disabled={loading}>{btnLabel}</button>
          <div style={S.links}>
            <span style={S.link} onClick={() => setLoginMode(loginMode === 'email' ? 'nrp' : 'email')}>
              {loginMode === 'email' ? 'Masuk dengan NRP' : 'Masuk dengan Email'}
            </span>
            <span style={S.link} onClick={() => alert('Login dulu, lalu buka menu MFA Setup di halaman utama.')}>MFA Setup</span>
          </div>
        </form>
      )}

      {/* NOTE: langkah OTP khusus dashboard dihapus — blok OTP admin serve
          kedua tab admin & dashboard (kondisi tab === 'admin' || 'dashboard'). */}

      <p style={{ marginTop: '32px', fontSize: '11px', color: '#475569' }}>{'\u00A9'} 2026 insightWOS</p>



    </div>
  );
}

