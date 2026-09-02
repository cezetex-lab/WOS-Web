import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { syncSupabaseAuth, rpc, setSession } from '@/lib/supabase-browser';

export default function OwnerLogin() {
  const navigate = useNavigate();
  const [step, setStep] = useState('login'); // login | otp | mfa
  const [email, setEmail] = useState('owner@insightwos.com');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [mfaCode, setMfaCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleLogin(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const auth = await syncSupabaseAuth(email, password);
      if (!auth) {
        setError('Email atau password salah');
        setLoading(false);
        return;
      }
      // Get owner context
      const ctx = await rpc('owner_login', { p_email: email, p_password: password });
      if (!ctx?.ok) {
        setError(ctx?.msg || 'Gagal login');
        setLoading(false);
        return;
      }
      // Check MFA
      const mfa = await rpc('check_mfa_status', { p_nrp: 'OWNER001' });
      if (mfa?.enabled) {
        setSession({ ...ctx, token: auth.session?.access_token });
        setStep('mfa');
        setLoading(false);
        return;
      }
      // No MFA — go directly to admin
      setSession({ ...ctx, token: auth.session?.access_token });
      navigate('/owner/dashboard');
    } catch (err) {
      setError('Error: ' + err.message);
    }
    setLoading(false);
  }

  async function handleMfa(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await rpc('verify_mfa', { p_nrp: 'OWNER001', p_code: mfaCode });
      if (res?.ok) {
        navigate('/owner/dashboard');
      } else {
        setError('Kode MFA salah');
      }
    } catch (err) {
      setError('Error: ' + err.message);
    }
    setLoading(false);
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)' }}>
      <div style={{ width: 380, padding: 32, borderRadius: 16, background: '#1e293b', border: '1px solid #334155', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.5)' }}>
        
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <div style={{ fontSize: 32, marginBottom: 8 }}>🔐</div>
          <h1 style={{ fontSize: 20, fontWeight: 700, color: '#f8fafc', margin: 0 }}>System Owner</h1>
          <p style={{ fontSize: 12, color: '#94a3b8', margin: '4px 0 0' }}>Installer Access Only</p>
        </div>

        {/* Error */}
        {error && (
          <div style={{ padding: '10px 14px', borderRadius: 8, background: '#451a1a', border: '1px solid #7f1d1d', color: '#fca5a5', fontSize: 12, marginBottom: 16 }}>
            {error}
          </div>
        )}

        {/* Login Form */}
        {step === 'login' && (
          <form onSubmit={handleLogin}>
            <div style={{ marginBottom: 14 }}>
              <label style={label}>Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} style={input} required />
            </div>
            <div style={{ marginBottom: 20 }}>
              <label style={label}>Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)} style={input} required />
            </div>
            <button type="submit" disabled={loading} style={{ width: '100%', padding: '12px 0', borderRadius: 8, background: '#3b82f6', color: '#fff', border: 'none', fontWeight: 600, fontSize: 14, cursor: 'pointer', opacity: loading ? 0.6 : 1 }}>
              {loading ? 'Masuk...' : '🔑 Masuk sebagai Owner'}
            </button>
          </form>
        )}

        {/* MFA Form */}
        {step === 'mfa' && (
          <form onSubmit={handleMfa}>
            <p style={{ fontSize: 12, color: '#94a3b8', marginBottom: 14, textAlign: 'center' }}>
              Masukkan kode MFA dari aplikasi authenticator Anda
            </p>
            <div style={{ marginBottom: 20 }}>
              <input type="text" value={mfaCode} onChange={e => setMfaCode(e.target.value)} 
                style={{ ...input, textAlign: 'center', fontSize: 20, letterSpacing: 8 }}
                placeholder="000000" maxLength={6} required autoFocus />
            </div>
            <button type="submit" disabled={loading} style={{ width: '100%', padding: '12px 0', borderRadius: 8, background: '#10b981', color: '#fff', border: 'none', fontWeight: 600, fontSize: 14, cursor: 'pointer', opacity: loading ? 0.6 : 1 }}>
              {loading ? 'Verifikasi...' : '✅ Verifikasi MFA'}
            </button>
            <button type="button" onClick={() => setStep('login')} style={{ width: '100%', padding: '10px 0', marginTop: 8, borderRadius: 8, background: 'transparent', color: '#94a3b8', border: '1px solid #334155', fontSize: 12, cursor: 'pointer' }}>
              ← Kembali ke login
            </button>
          </form>
        )}

        {/* Footer */}
        <p style={{ fontSize: 10, color: '#475569', textAlign: 'center', marginTop: 20 }}>
          ⚠️ Akses terbatas untuk System Installer
        </p>
      </div>
    </div>
  );
}

const label = { display: 'block', fontSize: 11, fontWeight: 600, color: '#94a3b8', marginBottom: 4 };
const input = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid #334155', background: '#0f172a', color: '#f8fafc', fontSize: 13 };
