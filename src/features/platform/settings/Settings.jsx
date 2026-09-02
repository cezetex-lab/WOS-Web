// ============================================================
// Settings.jsx — Settings + PKWT Expiry + Password Change
// Wave 1: Critical P1 Features
// ============================================================

import React, { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input, LoadingSpinner, Badge,
  MetricCard, ActionItem, SectionHeader
} from '@/lib/design-system';

export default function Settings() {
  const [loading, setLoading] = useState(true);
  const [pkwtAlerts, setPkwtAlerts] = useState([]);
  const [passwordForm, setPasswordForm] = useState({ old: '', new: '', confirm: '' });
  const [passwordMsg, setPasswordMsg] = useState(null);
  const [changing, setChanging] = useState(false);

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const { data } = await rpc('get_pkwt_expiry_alert');
      setPkwtAlerts(data?.data || []);
    } catch (e) { }
    setLoading(false);
  }

  async function handleChangePassword(e) {
    e.preventDefault();
    setPasswordMsg(null);
    if (passwordForm.new !== passwordForm.confirm) {
      setPasswordMsg({ type: 'error', text: 'Password baru tidak cocok' }); return;
    }
    if (passwordForm.new.length < 8) {
      setPasswordMsg({ type: 'error', text: 'Password minimal 8 karakter' }); return;
    }
    setChanging(true);
    try {
      const result = await rpc('admin_change_password', { p_old_password: passwordForm.old, p_new_password: passwordForm.new });
      if (result?.ok) { setPasswordMsg({ type: 'success', text: result.msg }); setPasswordForm({ old: '', new: '', confirm: '' }); }
      else { setPasswordMsg({ type: 'error', text: result?.msg || 'Gagal' }); }
    } catch (e) { setPasswordMsg({ type: 'error', text: 'Error: ' + e.message }); }
    setChanging(false);
  }

  const expired = pkwtAlerts.filter(a => a.risk_level === 'EXPIRED');
  const critical = pkwtAlerts.filter(a => a.risk_level === 'CRITICAL');
  const warning = pkwtAlerts.filter(a => a.risk_level === 'WARNING');

  if (loading) return <LoadingSpinner text="Memuat pengaturan..." />;

  return (
    <PageLayout backTo="/admin" title="Pengaturan" subtitle="Konfigurasi sistem & keamanan">
      {/* PKWT EXPIRY ALERTS */}
      <SectionHeader title="PKWT Expiry Alert" icon="⚠️" />
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="🔴" value={expired.length} label="Expired" color="red" />
        <MetricCard icon="🟡" value={critical.length} label="< 30 Hari" color="orange" />
        <MetricCard icon="🟠" value={warning.length} label="< 90 Hari" color="purple" />
      </div>

      {pkwtAlerts.length > 0 ? (
        <GlassCard title="Daftar PKWT" icon="👥" accent="orange" className="mb-6">
          {pkwtAlerts.map((a, i) => (
            <ActionItem key={i} title={`${a.nama} (${a.nrp})`} subtitle={`${a.posisi} • ${a.divisi}`}
              date={a.expiry_date} badge={a.risk_level}
              badgeType={a.risk_level === 'EXPIRED' ? 'danger' : a.risk_level === 'CRITICAL' ? 'warning' : 'info'} />
          ))}
        </GlassCard>
      ) : (
        <GlassCard title="Status PKWT" icon="✅" accent="green" className="mb-6">
          <p className="text-sm text-slate-300">✅ Tidak ada PKWT yang akan expired dalam 90 hari.</p>
        </GlassCard>
      )}

      {/* CHANGE ADMIN PASSWORD */}
      <SectionHeader title="Ubah Password Admin" icon="🔑" />
      <GlassCard title="Password Admin" icon="🔐" accent="blue" className="mb-6">
        <form onSubmit={handleChangePassword} className="space-y-4">
          <Input label="Password Lama" type="password" placeholder="Masukkan password lama"
            value={passwordForm.old} onChange={e => setPasswordForm({ ...passwordForm, old: e.target.value })} icon="🔑" />
          <Input label="Password Baru" type="password" placeholder="Minimal 8 karakter"
            value={passwordForm.new} onChange={e => setPasswordForm({ ...passwordForm, new: e.target.value })} icon="🔒" />
          <Input label="Konfirmasi Password Baru" type="password" placeholder="Ulangi password baru"
            value={passwordForm.confirm} onChange={e => setPasswordForm({ ...passwordForm, confirm: e.target.value })} icon="🔒" />
          {passwordMsg && (
            <div className={`p-3 rounded-xl text-sm font-semibold ${passwordMsg.type === 'success' ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' : 'bg-red-500/20 text-red-300 border border-red-500/30'}`}>
              {passwordMsg.type === 'success' ? '✓' : '✕'} {passwordMsg.text}
            </div>
          )}
          <Button type="submit" color="teal" disabled={changing || !passwordForm.old || !passwordForm.new}>
            {changing ? 'Mengubah...' : 'Ubah Password'}
          </Button>
        </form>
        <div className="mt-4 p-3 bg-slate-900/50 rounded-xl border border-white/5">
          <p className="text-[11px] text-slate-500">Default password: <code className="text-amber-400">Admin123</code></p>
        </div>
      </GlassCard>

      {/* SYSTEM INFO */}
      <SectionHeader title="System Info" icon="📊" />
      <GlassCard title="insightWOS" icon="📊" accent="teal">
        <div className="space-y-2 text-xs">
          <div className="flex justify-between"><span className="text-slate-400">Version</span><span className="text-white font-semibold">v3.0.0</span></div>
          <div className="flex justify-between"><span className="text-slate-400">Branch</span><span className="text-white font-semibold">migrasi-vite</span></div>
          <div className="flex justify-between"><span className="text-slate-400">Tables</span><span className="text-white font-semibold">57</span></div>
          <div className="flex justify-between"><span className="text-slate-400">RPC Functions</span><span className="text-white font-semibold">65+</span></div>
          <div className="flex justify-between"><span className="text-slate-400">Features</span><span className="text-white font-semibold">141 planned, 53+ done</span></div>
        </div>
      </GlassCard>
    </PageLayout>
  );
}
