// ============================================================
// WorkerProfile.jsx — #11 Profil Karyawan + Update Profil
// RPC: get_worker_profile, update_worker_profile
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { requireNrp } from '@/lib/supabase-browser';
import { rpcGetWorkerProfile, rpcWorkerUpdateProfile, isRpcError } from '@/lib/supabase-rpc';
import {
  PageLayout, GlassCard, Button, Input, Badge, Avatar,
  LoadingSpinner, StatItem, SectionHeader, useToast
} from '@/lib/design-system';

interface WorkerProfileData {
  nrp?: string;
  nik?: string;
  nama?: string;
  email?: string;
  no_hp?: string;
  phone?: string;
  alamat?: string;
  address?: string;
  divisi?: string;
  division?: string;
  posisi?: string;
  position?: string;
  status_kerja?: string;
  status?: string;
  tanggal_masuk?: string;
  join_date?: string;
  tanggal_lahir?: string;
  birth_date?: string;
  jenis_kelamin?: string;
  atasan_nrp?: string;
  agama?: string;
  media_sosial?: string | Record<string, any>;
  jenjang_pendidikan?: string;
  no_bpjs_kesehatan?: string;
  no_bpjs_ketenagakerjaan?: string;
  riwayat_penyakit?: string;
  komorbid?: string;
  alergi?: string;
  nama_bank?: string;
  no_rekening?: string;
  nama_rekening?: string;
  lokasi_penempatan?: string;
  updated_by?: string;
  status_kerja_internal?: string;
  [key: string]: unknown;
}

interface ProfileForm {
  no_hp: string;
  alamat: string;
  email: string;
  tanggal_lahir: string;
  agama: string;
  media_sosial: string;
  jenjang_pendidikan: string;
  no_bpjs_kesehatan: string;
  no_bpjs_ketenagakerjaan: string;
  riwayat_penyakit: string;
  komorbid: string;
  alergi: string;
  nama_bank: string;
  no_rekening: string;
  nama_rekening: string;
  lokasi_penempatan: string;
  [key: string]: string;
}

export default function WorkerProfile() {
  const navigate = useNavigate();
  const toast = useToast();
  const nrp = requireNrp();

  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [profile, setProfile] = useState<WorkerProfileData | null>(null);
  const [form, setForm] = useState<ProfileForm>({
    no_hp: '',
    alamat: '',
    email: '',
    tanggal_lahir: '',
    agama: '',
    media_sosial: '',
    jenjang_pendidikan: '',
    no_bpjs_kesehatan: '',
    no_bpjs_ketenagakerjaan: '',
    riwayat_penyakit: '',
    komorbid: '',
    alergi: '',
    nama_bank: '',
    no_rekening: '',
    nama_rekening: '',
    lokasi_penempatan: '',
  });

  // ── FETCH PROFILE ──
  const fetchProfile = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpcGetWorkerProfile({ p_nrp: nrp });
      if (isRpcError(result)) {
        toast.error(result.msg || 'Gagal memuat profil');
        setLoading(false);
        return;
      }
      const p = (result?.data || {}) as WorkerProfileData;
      setProfile(p);
      setForm({
        no_hp: p.no_hp || p.phone || '',
        alamat: p.alamat || p.address || '',
        email: p.email || '',
        tanggal_lahir: p.tanggal_lahir || p.birth_date || '',
        agama: (p.agama as string) || '',
        media_sosial: typeof p.media_sosial === 'string' ? (p.media_sosial as string) : '',
        jenjang_pendidikan: (p.jenjang_pendidikan as string) || '',
        no_bpjs_kesehatan: (p.no_bpjs_kesehatan as string) || '',
        no_bpjs_ketenagakerjaan: (p.no_bpjs_ketenagakerjaan as string) || '',
        riwayat_penyakit: (p.riwayat_penyakit as string) || '',
        komorbid: (p.komorbid as string) || '',
        alergi: (p.alergi as string) || '',
        nama_bank: (p.nama_bank as string) || '',
        no_rekening: (p.no_rekening as string) || '',
        nama_rekening: (p.nama_rekening as string) || '',
        lokasi_penempatan: (p.lokasi_penempatan as string) || '',
      });
    } catch (err) {
      toast.error('Gagal memuat profil');
    }
    setLoading(false);
  }, [nrp, toast]);

  useEffect(() => { fetchProfile(); }, [fetchProfile]);

  // ── SAVE PROFILE ──
  const handleSave = async () => {
    setSaving(true);
    try {
      const result = await rpcWorkerUpdateProfile({
        p_nrp: nrp,
        p_no_hp: form.no_hp || null,
        p_alamat: form.alamat || null,
        p_agama: form.agama || null,
        p_media_sosial: form.media_sosial || null,
        p_jenjang_pendidikan: form.jenjang_pendidikan || null,
        p_no_bpjs_kesehatan: form.no_bpjs_kesehatan || null,
        p_no_bpjs_ketenagakerjaan: form.no_bpjs_ketenagakerjaan || null,
        p_riwayat_penyakit: form.riwayat_penyakit || null,
        p_komorbid: form.komorbid || null,
        p_alergi: form.alergi || null,
        p_nama_bank: form.nama_bank || null,
        p_no_rekening: form.no_rekening || null,
        p_nama_rekening: form.nama_rekening || null,
        p_lokasi_penempatan: form.lokasi_penempatan || null,
      });
      if (isRpcError(result)) {
        toast.error(result.msg || 'Gagal memperbarui profil');
        setSaving(false);
        return;
      }
      toast.success('Profil berhasil diperbarui!');
      setEditing(false);
      fetchProfile();
    } catch (err) {
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

  const p: WorkerProfileData = profile || {};
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
    { label: 'Agama', value: p.agama || '-', icon: '🕌', editable: true, key: 'agama' },
    { label: 'Media Sosial', value: typeof p.media_sosial === 'string' ? (p.media_sosial as string) : '-', icon: '🌐', editable: true, key: 'media_sosial' },
    { label: 'Pendidikan', value: p.jenjang_pendidikan || '-', icon: '🎓', editable: true, key: 'jenjang_pendidikan' },
    { label: 'BPJS Kesehatan', value: p.no_bpjs_kesehatan || '-', icon: '🏥', editable: true, key: 'no_bpjs_kesehatan' },
    { label: 'BPJS Ketenagakerjaan', value: p.no_bpjs_ketenagakerjaan || '-', icon: '🛡️', editable: true, key: 'no_bpjs_ketenagakerjaan' },
    { label: 'Riwayat Penyakit', value: p.riwayat_penyakit || '-', icon: '🩺', editable: true, key: 'riwayat_penyakit', wide: true },
    { label: 'Komorbid', value: p.komorbid || '-', icon: '⚠️', editable: true, key: 'komorbid', wide: true },
    { label: 'Alergi', value: p.alergi || '-', icon: '🚫', editable: true, key: 'alergi', wide: true },
    { label: 'Bank', value: p.nama_bank || '-', icon: '🏦', editable: true, key: 'nama_bank' },
    { label: 'No. Rekening', value: p.no_rekening || '-', icon: '💳', editable: true, key: 'no_rekening' },
    { label: 'Atas Nama Rekening', value: p.nama_rekening || '-', icon: '👤', editable: true, key: 'nama_rekening' },
    { label: 'Lokasi Penempatan', value: p.lokasi_penempatan || '-', icon: '📍', editable: true, key: 'lokasi_penempatan' },
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
        <StatItem label="Masa Kerja" value={calcTenure(p.tanggal_masuk) as number} suffix=" bln" color="#38bdf8" />
        <StatItem label="Status" value={(p.status_kerja || '-') as unknown as number} color="#34d399" />
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
            <Input
              label="Agama"
              placeholder="Agama"
              value={form.agama}
              onChange={(e) => setForm({ ...form, agama: e.target.value })}
              icon="🕌"
            />
            <Input
              label="Media Sosial"
              placeholder="Media Sosial"
              value={form.media_sosial}
              onChange={(e) => setForm({ ...form, media_sosial: e.target.value })}
              icon="🌐"
            />
            <Input
              label="Jenjang Pendidikan"
              placeholder="Jenjang Pendidikan"
              value={form.jenjang_pendidikan}
              onChange={(e) => setForm({ ...form, jenjang_pendidikan: e.target.value })}
              icon="🎓"
            />
            <Input
              label="No. BPJS Kesehatan"
              placeholder="No. BPJS Kesehatan"
              value={form.no_bpjs_kesehatan}
              onChange={(e) => setForm({ ...form, no_bpjs_kesehatan: e.target.value })}
              icon="🏥"
            />
            <Input
              label="No. BPJS Ketenagakerjaan"
              placeholder="No. BPJS Ketenagakerjaan"
              value={form.no_bpjs_ketenagakerjaan}
              onChange={(e) => setForm({ ...form, no_bpjs_ketenagakerjaan: e.target.value })}
              icon="🛡️"
            />
            <Input
              label="Riwayat Penyakit"
              placeholder="Riwayat Penyakit"
              value={form.riwayat_penyakit}
              onChange={(e) => setForm({ ...form, riwayat_penyakit: e.target.value })}
              icon="🩺"
            />
            <Input
              label="Komorbid"
              placeholder="Komorbid"
              value={form.komorbid}
              onChange={(e) => setForm({ ...form, komorbid: e.target.value })}
              icon="⚠️"
            />
            <Input
              label="Alergi"
              placeholder="Alergi"
              value={form.alergi}
              onChange={(e) => setForm({ ...form, alergi: e.target.value })}
              icon="🚫"
            />
            <Input
              label="Nama Bank"
              placeholder="Nama Bank"
              value={form.nama_bank}
              onChange={(e) => setForm({ ...form, nama_bank: e.target.value })}
              icon="🏦"
            />
            <Input
              label="No. Rekening"
              placeholder="No. Rekening"
              value={form.no_rekening}
              onChange={(e) => setForm({ ...form, no_rekening: e.target.value })}
              icon="💳"
            />
            <Input
              label="Nama Rekening"
              placeholder="Nama Rekening"
              value={form.nama_rekening}
              onChange={(e) => setForm({ ...form, nama_rekening: e.target.value })}
              icon="👤"
            />
            <Input
              label="Lokasi Penempatan"
              placeholder="Lokasi Penempatan"
              value={form.lokasi_penempatan}
              onChange={(e) => setForm({ ...form, lokasi_penempatan: e.target.value })}
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
function SupervisorInfo({ nrp }: { nrp: string }) {
  const [supervisor, setSupervisor] = useState<WorkerProfileData | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const result = await rpcGetWorkerProfile({ p_nrp: nrp });
        if (!isRpcError(result) && result?.data?.atasan_nrp) {
          const supResult = await rpcGetWorkerProfile({ p_nrp: result.data.atasan_nrp });
          if (!isRpcError(supResult)) {
            setSupervisor(supResult.data || null);
          }
        }
      } catch (e) { }
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
function calcTenure(joinDate: string | undefined): string | number {
  if (!joinDate) return '-';
  const start = new Date(joinDate);
  const now = new Date();
  const months = (now.getFullYear() - start.getFullYear()) * 12 + (now.getMonth() - start.getMonth());
  return Math.max(0, months);
}
