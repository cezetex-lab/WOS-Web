// ============================================================
// ResetPassword.jsx — Admin Reset Password Karyawan
// RPC: admin_reset_worker_password(nrp, new_password)
// ============================================================

import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { rpc } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input, LoadingSpinner,
  Badge, EmptyState, Avatar
} from '../../lib/design-system';

export default function ResetPassword() {
  const [searchParams] = useSearchParams();
  const preselectedNrp = searchParams.get('nrp') || '';

  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedEmp, setSelectedEmp] = useState(null);
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [resetting, setResetting] = useState(false);
  const [result, setResult] = useState(null);

  // Load employees list
  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const data = await rpc('admin_get_employees');
        const list = Array.isArray(data) ? data : data?.data || [];
        setEmployees(list);
      } catch (e) {
        console.error('Failed to load employees:', e);
      }
      setLoading(false);
    })();
  }, []);

  // Auto-select if NRP in URL
  useEffect(() => {
    if (preselectedNrp && employees.length > 0) {
      const emp = employees.find(e => e.nrp === preselectedNrp);
      if (emp) setSelectedEmp(emp);
    }
  }, [preselectedNrp, employees]);

  // Filter employees
  const filtered = employees.filter(emp => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (emp.nrp || '').toLowerCase().includes(s) ||
           (emp.nama || '').toLowerCase().includes(s) ||
           (emp.divisi || '').toLowerCase().includes(s);
  });

  // Generate random password
  const generatePassword = () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    let pw = '';
    for (let i = 0; i < 10; i++) pw += chars[Math.floor(Math.random() * chars.length)];
    setNewPassword(pw);
    setConfirmPassword(pw);
  };

  // Reset password
  const handleReset = async (e) => {
    e.preventDefault();
    setResult(null);

    if (!selectedEmp) {
      setResult({ type: 'error', text: 'Pilih karyawan terlebih dahulu' });
      return;
    }
    if (newPassword.length < 8) {
      setResult({ type: 'error', text: 'Password minimal 8 karakter' });
      return;
    }
    if (newPassword !== confirmPassword) {
      setResult({ type: 'error', text: 'Password tidak cocok' });
      return;
    }

    setResetting(true);
    try {
      const res = await rpc('admin_reset_worker_password', {
        p_nrp: selectedEmp.nrp,
        p_new_password: newPassword,
      });
      if (res?.ok) {
        setResult({ type: 'success', text: `✅ ${res.msg || 'Password berhasil direset!'}` });
        setNewPassword('');
        setConfirmPassword('');
      } else {
        setResult({ type: 'error', text: res?.msg || 'Gagal mereset password' });
      }
    } catch (e) {
      setResult({ type: 'error', text: 'Error: ' + e.message });
    }
    setResetting(false);
  };

  if (loading) return (
    <PageLayout backTo="/admin" title="🔑 Reset Password">
      <LoadingSpinner text="Memuat daftar karyawan..." />
    </PageLayout>
  );

  return (
    <PageLayout backTo="/admin" title="🔑 Reset Password" subtitle="Atur ulang password karyawan">
      {/* Selected employee info */}
      {selectedEmp ? (
        <GlassCard accent="blue" className="mb-4">
          <div className="flex items-center gap-3">
            <Avatar name={selectedEmp.nama} size="md" />
            <div className="flex-1 min-w-0">
              <p className="text-white font-semibold text-sm">{selectedEmp.nama}</p>
              <p className="text-slate-400 text-xs">{selectedEmp.nrp} • {selectedEmp.divisi || '-'}</p>
            </div>
            <Badge color="green">{selectedEmp.status || 'Aktif'}</Badge>
            <Button color="ghost" size="sm" onClick={() => setSelectedEmp(null)}>✕</Button>
          </div>
        </GlassCard>
      ) : (
        <>
          {/* Search + Employee List */}
          <GlassCard accent="slate" className="mb-4">
            <p className="text-xs text-slate-400 mb-3">Pilih karyawan yang password-nya akan direset:</p>
            <input
              type="text"
              placeholder="🔍 Cari nama atau NRP..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="w-full px-3 py-2 bg-slate-800 border border-white/10 rounded-xl text-white text-sm placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500 mb-3"
            />
            <div className="max-h-[300px] overflow-y-auto space-y-1">
              {filtered.length === 0 ? (
                <p className="text-xs text-slate-500 text-center py-4">Tidak ditemukan</p>
              ) : (
                filtered.slice(0, 50).map(emp => (
                  <button
                    key={emp.nrp}
                    onClick={() => setSelectedEmp(emp)}
                    className="w-full flex items-center gap-3 p-2 rounded-xl hover:bg-slate-700/50 text-left transition"
                  >
                    <Avatar name={emp.nama} size="sm" />
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-medium truncate">{emp.nama}</p>
                      <p className="text-slate-500 text-[10px]">{emp.nrp} • {emp.divisi || '-'}</p>
                    </div>
                    <Badge color={emp.status === 'Aktif' ? 'green' : 'red'}>{emp.status || '-'}</Badge>
                  </button>
                ))
              )}
            </div>
          </GlassCard>
        </>
      )}

      {/* Reset Form */}
      {selectedEmp && (
        <GlassCard accent="red" title="🔑 Reset Password" icon="🔐">
          <form onSubmit={handleReset} className="space-y-4">
            <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl">
              <p className="text-xs text-amber-300">
                ⚠️ Password karyawan akan diganti. Pastikan memberitahu karyawan password baru.
              </p>
            </div>

            <Input
              label="Password Baru"
              type="text"
              placeholder="Minimal 8 karakter"
              value={newPassword}
              onChange={e => setNewPassword(e.target.value)}
              icon="🔒"
            />
            <Input
              label="Konfirmasi Password"
              type="text"
              placeholder="Ulangi password baru"
              value={confirmPassword}
              onChange={e => setConfirmPassword(e.target.value)}
              icon="🔒"
            />

            <div className="flex gap-2">
              <Button type="button" color="slate" onClick={generatePassword} className="flex-1">
                🎲 Generate Random
              </Button>
              <Button type="submit" color="red" disabled={resetting || !newPassword} className="flex-1">
                {resetting ? '⏳ Resetting...' : '🔑 Reset Password'}
              </Button>
            </div>

            {result && (
              <div className={`p-3 rounded-xl text-sm font-semibold ${
                result.type === 'success'
                  ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                  : 'bg-red-500/20 text-red-300 border border-red-500/30'
              }`}>
                {result.text}
              </div>
            )}

            {newPassword && (
              <div className="p-3 bg-slate-800/50 rounded-xl border border-white/5">
                <p className="text-[10px] text-slate-500 mb-1">Password baru untuk {selectedEmp.nama}:</p>
                <code className="text-amber-400 text-sm font-mono">{newPassword}</code>
              </div>
            )}
          </form>
        </GlassCard>
      )}
    </PageLayout>
  );
}
