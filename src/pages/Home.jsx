import { useState, useEffect } from 'react';
import { rpc, setSession, getSession, supabase, syncSupabaseAuth } from '@/lib/supabase-browser';
import { callEdgeFunction } from '@/lib/edge-functions';

// Root-cause fix (audit): worker tidak pernah punya akun Supabase Auth →
// auth.uid() NULL → authz_current_nrp()/get_enabled_modules() menolak
// akses → DynamicRoutes me-redirect balik ke /. 
// Tahap 4C FAST PATH: akun yang sudah diprovisi → signInWithPassword langsung
// (email sintetis satu sumber: lower(trim(nrp)) + '@insightwos.internal').
// Fallback: edge function worker-auth-sync (provisioning/rotasi + temp password).
// Non-fatal: gagal hanya me-log warning (login RPC tetap jalan).
async function provisionWorkerAuth(nrp, nik, password) {
  try {
    // FAST PATH — akun Supabase Auth sudah ada → sign-in langsung
    const syntheticEmail = String(nrp).toLowerCase().trim() + '@insightwos.internal';
    const direct = await syncSupabaseAuth(syntheticEmail, password);
    if (direct) {
      console.info('[auth-sync] fast path OK');
      return true;
    }
    console.info('[auth-sync] fast path gagal → fallback edge');

    // Timeout 5s: auth-sync bersifat best-effort — edge function yang hang
    // tidak boleh memblokir redirect login (fetch default tidak pernah timeout).
    const d = await callEdgeFunction('worker-auth-sync', { nrp, nik, password }, { timeoutMs: 5000 });
    if (!d?.ok || !d.email || !d.temp_password) {
      console.warn('[auth-sync] tidak berhasil:', d?.msg || 'respons tidak lengkap');
      return false;
    }
    const signed = await syncSupabaseAuth(d.email, d.temp_password);
    if (!signed) console.warn('[auth-sync] signInWithPassword gagal untuk', d.email);
    return !!signed;
  } catch (err) {
    console.warn('[auth-sync] error:', err?.message);
    return false;
  }
}


function checkMfaStatus(nrp) {
  return callEdgeFunction('mfa-service', { action: 'check', nrp });
}
function verifyMfaLogin(nrp, code) {
  return callEdgeFunction('mfa-service', { action: 'verify_login', nrp, code });
}

export default function Home() {
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
  const [brand, setBrand] = useState({ company_name: 'insightWOS', logo_url: '' });
  const [mfaEmail, setMfaEmail] = useState('');

  useEffect(() => {
    rpc('get_branding', {}).then(d => {
      if (d && d.company_name) setBrand(d);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    const user = getSession();
    if (user) {
      const r = user.role || 'worker';
      if (r.startsWith('admin_') || r === 'admin') window.location.href = '/admin';
      else if (r === 'manager') window.location.href = '/dashboard';
      else window.location.href = '/worker';
    }
  }, []);

  function switchTab(t) {
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
  }

  // Redirect sesuai TAB ASAL LOGIN — bukan role.
  // Admin juga bisa jadi worker: login lewat tab Pekerja → area pekerja.
  function redirectAfterLogin(entry) {
    if (entry === 'dashboard') window.location.href = '/dashboard';
    else if (entry === 'admin') window.location.href = '/admin';
    else window.location.href = '/worker';
  }

  // Finalisasi sesi worker dari response login_worker (termasuk pengecekan MFA)
  async function finalizeWorkerSession(d, creds, entry) {
    if (!d || !d.ok) return;
    const role = d.role || 'worker';
    const sessionData = { token: d.token, role, nama: d.nama, nrp: d.nrp, role_level: d.role_level, business_unit_id: d.business_unit_id, business_unit: d.business_unit || 'HQ', tier: d.tier ?? 0, expires_at: d.expires_at };
    try {
      const mfaRes = await checkMfaStatus(d.nrp);
      if (mfaRes && mfaRes.mfa_enabled) {
        setSession(sessionData);
        setMfaNrp(d.nrp);
        setMfaContext('worker');
        setLoginStep('mfa');
        return;
      }
    } catch (err) {
      // MFA check gagal -> lanjut login (tidak memblokir user)
    }
    setSession(sessionData);
    // Provision akun Supabase Auth supaya auth.uid() tersedia (authz/RLS)
    if (creds?.nik && creds?.password) {
      await provisionWorkerAuth(d.nrp, creds.nik, creds.password);
    }
    redirectAfterLogin(entry);
  }

  async function submitWorkerCredentials(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      // V6: Check lockout before attempting login
      const lockCheck = await rpc('check_login_lockout', { p_identifier: nrp, p_attempt_type: 'worker' });
      if (lockCheck?.locked) {
        setError(lockCheck.reason || "Akun sementara dikunci");
        setLoading(false);
        return;
      }

      // Direct login via login_worker (return reset_required bila wajib ganti password)
      const d = await rpc('login_worker', { p_nrp: nrp, p_nik: nik, p_password: pass });
      if (!d.ok) {
        setError(d.msg || 'Login gagal');
        setLoading(false);
        return;
      }
      if (d.reset_required) {
        setValidatedNrp(nrp);
        setLoginStep('reset');
        setLoading(false);
        return;
      }
      await finalizeWorkerSession(d, { nik, password: pass }, tab);
    } catch (err) {
      setError('Koneksi error: ' + err.message);
    }
    setLoading(false);
  }

  // Kirim password baru (reset_required) lalu finalisasi sesi login yang tertunda
  async function submitResetPassword(e) {
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
    } catch (err) {
      setError('Koneksi error: ' + err.message);
    }
    setLoading(false);
  }

  async function submitAdminCredentials(e) {
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
        console.error('[Admin Login] Supabase auth failed');
        setError('Email atau password salah');
        setLoading(false);
        return;
      }
      // Look up employee by auth_id
      const ctx = await rpc('get_user_context_by_auth_id', { p_auth_id: authResult.user.id });
      if (!ctx.ok) {
        console.error('[Admin Login] User context lookup failed:', ctx.msg);
        setError(ctx.msg || 'Akun tidak ditemukan di sistem');
        setLoading(false);
        return;
      }

      // Check MFA
      const mfaRes = await checkMfaStatus(ctx.nrp);
      if (mfaRes?.enabled) {
        setSession({ token: authResult.session?.access_token, role: ctx.role, nama: ctx.nama, nrp: ctx.nrp, role_level: ctx.role_level, business_unit_id: ctx.business_unit_id, business_unit: ctx.unit_code || 'HQ', tier: ctx.tier, is_owner: ctx.role === 'owner' });
        setMfaNrp(ctx.nrp);
        setMfaEmail(adminEmail);
        setMfaContext('admin');
        setLoginStep('mfa');
        setLoading(false);
        return;
      }
      
      // No MFA — direct login
      const sessionData = { token: authResult.session?.access_token, role: ctx.role, nama: ctx.nama, nrp: ctx.nrp, role_level: ctx.role_level, business_unit_id: ctx.business_unit_id, business_unit: ctx.unit_code || 'HQ', tier: ctx.tier, is_owner: ctx.role === 'owner' };
      setSession(sessionData);
      window.location.href = '/admin';
    } catch (err) {
      console.error('[Admin Login] Exception during login:', err);
      setError('Koneksi error: ' + err.message);
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
    } catch (err) {
      setError('Koneksi error: ' + err.message);
    }
    setLoading(false);
  }

  async function submitWorkerOtp(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const d = await rpc('verify_worker_otp', { p_nrp: validatedNrp, p_code: otp });
      if (d.ok) {
        // Check if MFA is enabled for this user
        const mfaRes = await checkMfaStatus(validatedNrp);
        if (mfaRes.mfa_enabled) {
          // MFA required — store OTP data, show MFA input
          setSession({ ...d, role: 'worker' });
          setMfaRequired(true);
          setMfaNrp(validatedNrp);
          setMfaContext('worker');
          setLoginStep('mfa');
          return;
        }
        // No MFA — direct sesuai tab asal login
        setSession({ ...d, role: 'worker' });
        if (nik && pass) await provisionWorkerAuth(validatedNrp, nik, pass);
        redirectAfterLogin(tab);
      } else {
        setError(d.msg || 'OTP salah');
      }
    } catch (err) {
      setError('Koneksi error: ' + err.message);
    }
    setLoading(false);
  }

  async function submitWorkerMfa(e) {
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
          await provisionWorkerAuth(mfaNrp, nik, pass);
          redirectAfterLogin(tab);
        } else {
          window.location.href = '/admin';
        }
      } else {
        setError(d.msg || 'Kode TOTP salah');
      }
    } catch (err) {
      setError('Koneksi error: ' + err.message);
    }
    setLoading(false);
  }

  async function submitAdminOtp(e) {
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
          setSession({ token: d.token, role: d.role || 'admin_pusat', nama: d.nama || 'Administrator', nrp: adminNrp });
          setMfaRequired(true);
          setMfaNrp(adminNrp);
          setMfaContext('admin');
          setLoginStep('mfa');
          setLoading(false);
          return;
        }
        setSession({ token: d.token, role: d.role || 'admin_pusat', nama: d.nama || 'Administrator', nrp: adminNrp });
        // V6: sync Supabase Auth for gatekeeper RPCs
        if (adminEmail) syncSupabaseAuth(adminEmail, adminPass);
        window.location.href = '/admin';
      } else {
        setError(d.msg || 'OTP salah');
      }
    } catch (err) {
      setError('Koneksi error: ' + err.message);
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
      } else {
        res = await rpc('generate_worker_otp', { p_nrp: validatedNrp, p_nik: nik, p_password: pass });
      }
      if (res.ok) {
        setOtpCode(res.otp || '');
        setError('');
      } else {
        setError(res.msg || 'Gagal kirim ulang OTP');
      }
    } catch (err) {
      setError('Koneksi error: ' + err.message);
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

  const S = {
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
        <h1 style={S.brand}>insightWOS</h1>
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
          <div style={S.field}>
            <label style={S.label}>NRP</label>
            <input value={nrp} onChange={e => setNrp(e.target.value)} placeholder="Masukkan NRP" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>NIK</label>
            <input value={nik} onChange={e => setNik(e.target.value)} placeholder="Masukkan NIK" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>Password</label>
            <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Masukkan password" style={S.inp} required />
          </div>
          <button type="submit" style={S.btn} disabled={loading}>{btnLabel}</button>
          <div style={{textAlign:"center",marginTop:8}}><a href="/reset-password" style={{color:"#60a5fa",fontSize:13}}>Lupa Password?</a></div>
          <div style={S.links}>
            <span style={S.link} onClick={() => alert('Form pendaftaran akan segera tersedia.')}>Daftar Baru</span>
            <span style={S.link} onClick={() => alert('Cek status pendaftaran akan segera tersedia.')}>Cek Daftar</span>
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

      {/* Worker MFA Step */}
      {tab === 'worker' && loginStep === 'mfa' && (
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
            <input type="email" value={adminEmail} onChange={e => setAdminEmail(e.target.value)} placeholder="owner@insightwos.com" style={S.inp} required />
            <label style={S.label}>Password Admin</label>
            <input type="password" value={adminPass} onChange={e => setAdminPass(e.target.value)} placeholder="Masukkan password admin" style={S.inp} required />
          </div>

          <button type="submit" style={S.btn} disabled={loading}>{loading ? '...' : 'Verifikasi Password'}</button>
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
          <div style={S.field}>
            <label style={S.label}>NRP</label>
            <input value={nrp} onChange={e => setNrp(e.target.value)} placeholder="Masukkan NRP" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>NIK</label>
            <input value={nik} onChange={e => setNik(e.target.value)} placeholder="Masukkan NIK" style={S.inp} required />
          </div>
          <div style={S.field}>
            <label style={S.label}>Password</label>
            <input type="password" value={pass} onChange={e => setPass(e.target.value)} placeholder="Masukkan password" style={S.inp} required />
          </div>
          <button type="submit" style={S.btn} disabled={loading}>{btnLabel}</button>
        </form>
      )}

      {tab === 'dashboard' && loginStep === 'otp' && (
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

      <p style={{ marginTop: '32px', fontSize: '11px', color: '#475569' }}>{'\u00A9'} 2026 insightWOS</p>



    </div>
  );
}
