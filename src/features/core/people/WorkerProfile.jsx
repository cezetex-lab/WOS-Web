// ============================================================
// WorkerProfile.jsx — #11 Profil Karyawan + Update Profil
// RPC: get_worker_profile, update_worker_profile
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, rpc, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input, Badge, Avatar,
  LoadingSpinner, StatItem, SectionHeader, useToast
} from '../../../lib/design-system';

export default function WorkerProfile() {
  const navigate = useNavigate();
  const toast = useToast();
  const nrp = getSession()?.nrp || 'NRP001';

  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [profile, setProfile] = useState(null);
  const [form, setForm] = useState({});

  // ── FETCH PROFILE ──
  const fetchProfile = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_profile', { p_nrp: nrp });
      const p = result?.data || result || {};
      setProfile(p);
      setForm({
        no_hp: p.no_hp || p.phone || '',
        alamat: p.alamat || p.address || '',
        email: p.email || '',
        tanggal_lahir: p.tanggal_lahir || p.birth_date || '',
      });
    } catch (err) {
      console.error('Failed to load profile:', err);
    }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchProfile(); }, [fetchProfile]);

  // ── SAVE PROFILE ──
  const handleSave = async () => {
    setSaving(true);
    try {
      await rpc('worker_update_profile', {
        p_nrp: nrp,
        p_no_hp: form.no_hp,
        p_alamat: form.alamat,
      });
      toast.success('Profil berhasil diperbarui!');
      setEditing(false);
      fetchProfile();
    } catch (err) {
      console.error('Failed to save profile:', err);
      toast.error('Gagal memperbarui profil');
    }
    setSaving(false);
  };

  if (loading) {
    return (
      <PageLayout backTo="/worker" title="Profil Saya">
        <LoadingSpinner text="Memuat profil..." />
      </PageLayout>
    );
  }

  const p = profile || {};
  const statusColor = (p.status_kerja || '').toLowerCase() === 'aktif' ? 'success' : 'warning';

  // ── INFO ROWS ──
  const infoRows = [
    { label: 'NRP', value: p.nrp || nrp, icon: '🔑' },
    { label: 'NIK', value: p.nik || '-', icon: '🪪' },
    { label: 'Nama Lengkap', value: p.nama || '-', icon: '👤' },
    { label: 'Email', value: p.email || '-', icon: '📧' },
    { label: 'No. HP', value: p.no_hp || p.phone || '-', icon: '📱', editable: true, key: 'no_hp' },
    { label: 'Divisi', value: p.divisi || p.division || '-', icon: '🏢' },
    { label: 'Posisi', value: p.posisi || p.position || '-', icon: '💼' },
    { label: 'Status Kerja', value: p.status_kerja || p.status || '-', icon: '📌', isBadge: true, badgeType: statusColor },
    { label: 'Tanggal Masuk', value: p.tanggal_masuk || p.join_date || '-', icon: '📅' },
    { label: 'Tanggal Lahir', value: p.tanggal_lahir || '-', icon: '🎂', editable: true, key: 'tanggal_lahir' },
    { label: 'Jenis Kelamin', value: p.jenis_kelamin || '-', icon: '⚧' },
    { label: 'Alamat', value: p.alamat || '-', icon: '📍', editable: true, key: 'alamat', wide: true },
  ];

  return (
    <PageLayout backTo="/worker" title="Profil Saya" subtitle={p.nama || nrp}>
      {/* ── AVATAR + NAME ── */}
      <div className="flex items-center gap-4 mb-6">
        <Avatar name={p.nama} size="lg" />
        <div className="flex-1 min-w-0">
          <h2 className="text-xl font-bold text-white">{p.nama || '-'}</h2>
          <p className="text-xs text-slate-400">{p.nrp} • {p.posisi || '-'}</p>
          <div className="flex gap-2 mt-1">
            <Badge status={p.status_kerja || '-'} type={statusColor} />
            {p.jenis_kelamin && <Badge status={p.jenis_kelamin} type="info" />}
          </div>
        </div>
        <Button
          color={editing ? 'ghost' : 'teal'}
          size="sm"
          onClick={() => { setEditing(!editing); if (editing) fetchProfile(); }}
        >
          {editing ? '✕ Batal' : '✏️ Edit'}
        </Button>
      </div>

      {/* ── STAT ITEMS ── */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        <StatItem label="Masa Kerja" value={calcTenure(p.tanggal_masuk)} suffix=" bln" color="#38bdf8" />
        <StatItem label="Status" value={p.status_kerja || '-'} color="#34d399" />
      </div>

      {/* ── EDIT FORM ── */}
      {editing && (
        <GlassCard title="Edit Profil" icon="✏️" accent="teal" className="mb-6">
          <div className="space-y-4">
            <Input
              label="No. HP"
              placeholder="08xxx"
              value={form.no_hp}
              onChange={(e) => setForm({ ...form, no_hp: e.target.value })}
              icon="📱"
            />
            <Input
              label="Alamat"
              placeholder="Alamat lengkap"
              value={form.alamat}
              onChange={(e) => setForm({ ...form, alamat: e.target.value })}
              icon="📍"
            />
            <div className="flex gap-2 mt-3">
              <Button color="teal" onClick={handleSave} disabled={saving} className="flex-1">
                {saving ? 'Menyimpan...' : '💾 Simpan'}
              </Button>
              <Button color="ghost" onClick={() => setEditing(false)}>Batal</Button>
            </div>
          </div>
        </GlassCard>
      )}

      {/* ── INFO LIST ── */}
      <GlassCard title="Data Diri" icon="📋" accent="blue">
        <div className="space-y-1">
          {infoRows.map((row, i) => (
            <div key={i} className="flex items-center justify-between py-2.5 border-b border-white/3 last:border-0">
              <div className="flex items-center gap-2 min-w-0">
                <span className="text-sm">{row.icon}</span>
                <span className="text-xs text-slate-400">{row.label}</span>
              </div>
              {editing && row.editable ? (
                <input
                  type={row.key === 'tanggal_lahir' ? 'date' : 'text'}
                  value={form[row.key] || ''}
                  onChange={(e) => setForm({ ...form, [row.key]: e.target.value })}
                  className="text-xs text-right bg-slate-700/50 text-white rounded-lg px-2 py-1 border border-white/10 focus:border-teal-500/50 outline-none max-w-[50%]"
                />
              ) : row.isBadge ? (
                <Badge status={row.value} type={row.badgeType} />
              ) : (
                <span className={`text-xs font-semibold text-white text-right ${row.wide ? 'max-w-[60%] break-words' : ''}`}>
                  {row.value}
                </span>
              )}
            </div>
          ))}
        </div>
      </GlassCard>

      {/* ── SUPERVISOR INFO ── */}
      <GlassCard title="Atasan Langsung" icon="👔" accent="purple" className="mt-4">
        <SupervisorInfo nrp={nrp} />
      </GlassCard>
    </PageLayout>
  );
}

// ── SUPERVISOR SUB-COMPONENT ──
function SupervisorInfo({ nrp }) {
  const [supervisor, setSupervisor] = useState(null);

  useEffect(() => {
    const load = async () => {
      try {
        const result = await rpc('get_worker_profile', { p_nrp: nrp });
        if (result?.atasan_nrp) {
          const supResult = await rpc('get_worker_profile', { p_nrp: result.atasan_nrp });
          setSupervisor(supResult);
        }
      } catch (e) { console.warn('Supervisor load failed:', e); }
    };
    load();
  }, [nrp]);

  if (!supervisor) return <p className="text-xs text-slate-500">Tidak ada atasan terdaftar</p>;

  return (
    <div className="flex items-center gap-3">
      <Avatar name={supervisor.nama} size="md" />
      <div>
        <p className="text-sm font-bold text-white">{supervisor.nama}</p>
        <p className="text-xs text-slate-400">{supervisor.nrp} • {supervisor.posisi || '-'}</p>
        <p className="text-xs text-slate-500">{supervisor.divisi || '-'}</p>
      </div>
    </div>
  );
}

// ── HELPER ──
function calcTenure(joinDate) {
  if (!joinDate) return '-';
  const start = new Date(joinDate);
  const now = new Date();
  const months = (now.getFullYear() - start.getFullYear()) * 12 + (now.getMonth() - start.getMonth());
  return Math.max(0, months);
}
