import { useState, useEffect } from 'react';
import { rpc, setSession, getSession } from '@/lib/supabase-browser';

export default function Home() {
  const [tab, setTab] = useState('worker');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [nrp, setNrp] = useState('');
  const [nik, setNik] = useState('');
  const [pass, setPass] = useState('');
  const [adminPass, setAdminPass] = useState('');
  const [otp, setOtp] = useState('');
  const [otpCode, setOtpCode] = useState('');

  const [loginStep, setLoginStep] = useState('credentials');
  const [mfaRequired, setMfaRequired] = useState(false);
  const [mfaCode, setMfaCode] = useState('');
  const [mfaNrp, setMfaNrp] = useState('');
  const [validatedNrp, setValidatedNrp] = useState('');
  const [adminValidated, setAdminValidated] = useState(false);

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
    setNrp('');
    setNik('');
    setPass('');
    setAdminPass('');
  }

  async function submitWorkerCredentials(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const d = await rpc('generate_worker_otp', { p_nrp: nrp, p_nik: nik, p_password: pass });
      if (d.ok) {
        setValidatedNrp(nrp);
        setOtpCode(d.otp || '');
        setLoginStep('otp');
      } else {
        setError(d.msg || 'Validasi gagal');
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
      const d = await rpc('login_admin', { p_password: adminPass });
      if (d.ok) {
        setAdminValidated(true);
      } else {
        setError(d.msg || 'Password salah');
      }
    } catch (err) {
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
        // Role detection: admin_pusat/admin_hrd/admin_finance/admin_produksi → /admin, manager → /dashboard, worker → /worker

const MFA_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mfa-service`;
async function checkMfaLogin(nrp, code) {
  const res = await fetch(MFA_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}` },
    body: JSON.stringify({ action: 'verify_login', nrp, code }),
  });
  return res.json();
}

        const userRole = d.role || 'worker';
        let loginRole, redirectPath;
        if (userRole.startsWith('admin_')) {
          loginRole = userRole;
          redirectPath = '/admin';
        } else if (userRole === 'manager') {
          loginRole = 'manager';
          redirectPath = '/dashboard';
        } else {
          loginRole = 'worker';
          redirectPath = '/worker';
        }
        setSession({ ...d, role: loginRole });
        window.location.href = redirectPath;
      } else {
        setError(d.msg || 'OTP salah');
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
        setSession({ token: d.token, role: d.role || 'admin_pusat', nama: d.nama || 'Administrator', nrp: d.nrp || 'ADMIN' });
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

  const btnLabel = loading ? '...' : (loginStep === 'otp' ? 'Verifikasi OTP' : 'Verifikasi & Minta OTP');

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
          <div style={S.links}>
            <span style={S.link} onClick={() => alert('Form pendaftaran akan segera tersedia.')}>Daftar Baru</span>
            <span style={S.link} onClick={() => alert('Cek status pendaftaran akan segera tersedia.')}>Cek Daftar</span>
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
            <button type="button" style={S.btnBack} onClick={goBack}>{'\u2190'} Kembali</button>
            <button type="button" style={S.btnSmall} onClick={resendOtp} disabled={loading}>Kirim Ulang OTP</button>
          </div>
        </form>
      )}

      {/* Admin Login */}
      {tab === 'admin' && loginStep === 'credentials' && !adminValidated && (
        <form onSubmit={submitAdminCredentials} style={S.form}>
          <div style={S.field}>
            <label style={S.label}>Password Admin</label>
            <input type="password" value={adminPass} onChange={e => setAdminPass(e.target.value)} placeholder="Masukkan password admin" style={S.inp} required />
          </div>
          <div style={{ fontSize: '11px', color: '#64748b', textAlign: 'center' }}>Default: Admin123</div>
          <button type="submit" style={S.btn} disabled={loading}>{loading ? '...' : 'Verifikasi Password'}</button>
        </form>
      )}

      {tab === 'admin' && loginStep === 'credentials' && adminValidated && (
        <div style={S.form}>
          <div style={{ ...S.otpInfo, background: '#065f46', borderColor: '#22c55e', color: '#34d399' }}>
            {'\u2705'} Password diverifikasi. Klik tombol di bawah untuk mendapatkan OTP.
          </div>
          <button onClick={requestAdminOtp} style={S.btn} disabled={loading}>{loading ? '...' : '\u{1F511} Minta OTP (via Email)'}</button>
          <div style={{ textAlign: 'center', marginTop: '8px' }}>
            <button type="button" style={S.btnBack} onClick={() => { setAdminValidated(false); setError(''); }}>{'\u2190'} Ganti Password</button>
          </div>
        </div>
      )}

      {tab === 'admin' && loginStep === 'otp' && (
        <form onSubmit={submitAdminOtp} style={S.form}>
          <div style={S.otpInfo}>Kode OTP admin</div>
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
            <button type="button" style={S.btnBack} onClick={goBack}>{'\u2190'} Kembali</button>
            <button type="button" style={S.btnSmall} onClick={resendOtp} disabled={loading}>Kirim Ulang OTP</button>
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
            <button type="button" style={S.btnBack} onClick={goBack}>{'\u2190'} Kembali</button>
            <button type="button" style={S.btnSmall} onClick={resendOtp} disabled={loading}>Kirim Ulang OTP</button>
          </div>
        </form>
      )}

      <p style={{ marginTop: '32px', fontSize: '11px', color: '#475569' }}>{'\u00A9'} 2026 insightWOS</p>

      {/* MFA Verification Step */}
      {loginStep === 'mfa' && (
        <div className="space-y-4">
          <div className="bg-slate-800/50 border border-blue-500/30 rounded-xl p-4 text-center">
            <p className="text-2xl mb-2">🔐</p>
            <p className="text-white font-semibold">Verifikasi MFA</p>
            <p className="text-sm text-slate-400">Masukkan 6 digit kode dari authenticator app</p>
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">Kode TOTP</label>
            <input
              type="text"
              value={mfaCode}
              onChange={e => setMfaCode(e.target.value)}
              placeholder="000000"
              maxLength={6}
              className="w-full bg-slate-800 border border-slate-600 rounded-lg px-4 py-3 text-white text-center text-2xl tracking-[0.5em] font-mono focus:outline-none focus:border-blue-500"
              onKeyDown={async e => {
                if (e.key === 'Enter' && mfaCode.length === 6) {
                  const d = await checkMfaLogin(mfaNrp, mfaCode);
                  if (d.ok && d.mfa_verified) {
                    navigate('/worker');
                  } else {
                    setError(d.msg || 'Kode TOTP salah');
                  }
                }
              }}
            />
          </div>
          {error && <p className="text-red-400 text-sm text-center">{error}</p>}
          <button
            onClick={async () => {
              const d = await checkMfaLogin(mfaNrp, mfaCode);
              if (d.ok && d.mfa_verified) {
                navigate('/worker');
              } else {
                setError(d.msg || 'Kode TOTP salah');
              }
            }}
            className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors"
          >
            Verifikasi
          </button>
          <button
            onClick={() => { setLoginStep('otp'); setError(''); }}
            className="w-full text-slate-400 hover:text-white text-sm py-2"
          >
            Kembali
          </button>
        </div>
      )}

    </div>
  );
}