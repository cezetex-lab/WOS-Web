import { useState, useEffect } from 'react';
import { rpc, supabase } from '../../../lib/supabase-browser';
import { PageLayout, SectionHeader } from '../../../lib/design-system';
import { Button, Input, Badge, GlassCard, MetricCard, LoadingSpinner, EmptyState } from '../../../lib/design-system';

const MFA_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mfa-service`;

async function mfaAction(action, data = {}) {
  const { data: { session } } = await supabase.auth.getSession();
  const res = await fetch(MFA_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify({ action, ...data }),
  });
  return res.json();
}

export default function MfaSetup() {
  const [step, setStep] = useState('loading'); // loading | status | enroll | verify | success
  const [mfaEnabled, setMfaEnabled] = useState(false);
  const [factorId, setFactorId] = useState('');
  const [secret, setSecret] = useState('');
  const [otpauthUrl, setOtpauthUrl] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [msg, setMsg] = useState('');
  const [nrp, setNrp] = useState('');

  useEffect(() => {
    // Get NRP from session
    const raw = sessionStorage.getItem('wos_user');
    if (raw) {
      try {
        const u = JSON.parse(raw);
        setNrp(u.nrp || u.id || '');
      } catch {}
    }
    checkStatus();
  }, []);

  async function checkStatus() {
    try {
      const raw = sessionStorage.getItem('wos_user');
      const u = raw ? JSON.parse(raw) : null;
      const userNrp = u?.nrp || u?.id || '';
      if (!userNrp) { setStep('error'); return; }
      
      const d = await mfaAction('check', { nrp: userNrp });
      setMfaEnabled(d.mfa_enabled);
      setStep(d.mfa_enabled ? 'status' : 'status');
    } catch (e) {
      setStep('status');
    }
  }

  async function handleEnroll() {
    setError('');
    setMsg('');
    try {
      const d = await mfaAction('enroll', { nrp, label: 'insightWOS' });
      if (d.ok) {
        setFactorId(d.factor_id);
        setSecret(d.secret);
        setOtpauthUrl(d.otpauth_url);
        setStep('enroll');
      } else {
        setError(d.msg || 'Gagal enroll MFA');
      }
    } catch (e) {
      setError('Gagal menghubungi server');
    }
  }

  async function handleActivate() {
    setError('');
    if (!code || code.length !== 6) {
      setError('Masukkan 6 digit kode TOTP');
      return;
    }
    try {
      const d = await mfaAction('verify_activate', { nrp, factor_id: factorId, code });
      if (d.ok) {
        setMfaEnabled(true);
        setStep('success');
        setMsg('MFA berhasil diaktifkan!');
      } else {
        setError(d.msg || 'Kode salah');
      }
    } catch (e) {
      setError('Gagal verifikasi');
    }
  }

  async function handleDisable() {
    setError('');
    if (!code || code.length !== 6) {
      setError('Masukkan 6 digit kode TOTP untuk disable');
      return;
    }
    try {
      const d = await mfaAction('disable', { nrp, code });
      if (d.ok) {
        setMfaEnabled(false);
        setStep('status');
        setMsg('MFA dinonaktifkan');
      } else {
        setError(d.msg || 'Gagal disable');
      }
    } catch (e) {
      setError('Gagal disable MFA');
    }
  }

  // QR Code via Google Charts API (no library needed)
  const qrUrl = otpauthUrl
    ? `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(otpauthUrl)}`
    : '';

  if (step === 'loading') return <PageLayout><LoadingSpinner /></PageLayout>;

  return (
    <PageLayout>
      <SectionHeader title="🔐 Multi-Factor Authentication" desc="Keamanan tambahan untuk akun Anda" />

      {/* Status */}
      {step === 'status' && (
        <div className="space-y-4">
          <GlassCard>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-white font-semibold">Status MFA</p>
                <p className="text-sm text-slate-400">
                  {mfaEnabled ? 'Aktif — akun Anda terlindungi dengan TOTP' : 'Nonaktif — akun hanya menggunakan OTP'}
                </p>
              </div>
              <Badge variant={mfaEnabled ? 'success' : 'warning'}>
                {mfaEnabled ? 'AKTIF' : 'NONAKTIF'}
              </Badge>
            </div>
          </GlassCard>

          {msg && <p className="text-green-400 text-sm">{msg}</p>}
          {error && <p className="text-red-400 text-sm">{error}</p>}

          <div className="flex gap-3">
            {!mfaEnabled ? (
              <Button onClick={handleEnroll} variant="primary">
                Aktifkan MFA
              </Button>
            ) : (
              <div className="space-y-3 w-full">
                <p className="text-slate-400 text-sm">Untuk nonaktifkan MFA, masukkan kode TOTP:</p>
                <Input
                  label="Kode TOTP"
                  value={code}
                  onChange={e => setCode(e.target.value)}
                  placeholder="000000"
                  maxLength={6}
                />
                <Button onClick={handleDisable} variant="danger">
                  Nonaktifkan MFA
                </Button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Enroll — show QR code */}
      {step === 'enroll' && (
        <div className="space-y-4">
          <GlassCard>
            <p className="text-white font-semibold mb-2">Langkah 1: Scan QR Code</p>
            <p className="text-sm text-slate-400 mb-4">
              Buka Google Authenticator / Authy / 1Password, lalu scan QR code di bawah:
            </p>
            {qrUrl && (
              <div className="flex justify-center mb-4">
                <img src={qrUrl} alt="MFA QR Code" className="bg-white p-2 rounded-lg" width={200} height={200} />
              </div>
            )}
            <div className="bg-slate-800 p-3 rounded-lg">
              <p className="text-xs text-slate-400 mb-1">Atau masukkan manual:</p>
              <code className="text-green-400 text-sm break-all">{secret}</code>
            </div>
          </GlassCard>

          <GlassCard>
            <p className="text-white font-semibold mb-2">Langkah 2: Verifikasi Kode</p>
            <p className="text-sm text-slate-400 mb-3">
              Masukkan 6 digit kode dari authenticator app:
            </p>
            <Input
              label="Kode TOTP"
              value={code}
              onChange={e => setCode(e.target.value)}
              placeholder="000000"
              maxLength={6}
            />
            {error && <p className="text-red-400 text-sm mt-2">{error}</p>}
          </GlassCard>

          <div className="flex gap-3">
            <Button onClick={handleActivate} variant="primary">
              Aktifkan MFA
            </Button>
            <Button onClick={() => setStep('status')} variant="secondary">
              Batal
            </Button>
          </div>
        </div>
      )}

      {/* Success */}
      {step === 'success' && (
        <GlassCard>
          <div className="text-center py-8">
            <p className="text-4xl mb-4">✅</p>
            <p className="text-white text-xl font-bold mb-2">MFA Berhasil Diaktifkan!</p>
            <p className="text-slate-400 mb-6">
              Setiap kali login, Anda akan diminta memasukkan kode dari authenticator app.
            </p>
            <Button onClick={() => setStep('status')} variant="primary">
              Kembali
            </Button>
          </div>
        </GlassCard>
      )}
    </PageLayout>
  );
}
