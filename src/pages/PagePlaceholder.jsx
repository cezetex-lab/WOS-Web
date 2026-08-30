// ============================================================
// PagePlaceholder.jsx — Generic placeholder untuk halaman detail
// yang belum dibuat. Bisa dihapus saat halaman asli sudah jadi.
// ============================================================

import React from 'react';
import { useNavigate } from 'react-router-dom';
import { PageLayout } from '../lib/design-system';

const PAGE_META = {
  // KELOLA DATA
  'admin/employees':     { icon: '👥', title: 'Karyawan', desc: 'Kelola data seluruh karyawan' },
  'admin/org':           { icon: '🏢', title: 'Organisasi', desc: 'Struktur organisasi perusahaan' },
  'admin/divisions':     { icon: '📂', title: 'Divisi', desc: 'Manajemen divisi & departemen' },
  'admin/master':        { icon: '🗄️', title: 'Master Data', desc: 'Data referensi utama sistem' },
  'admin/roles':         { icon: '🔑', title: 'Role Matrix', desc: 'Mapping role & permission' },

  // OPERASIONAL HR
  'admin/requests':      { icon: '📝', title: 'Pengajuan', desc: 'Kelola semua pengajuan karyawan' },
  'admin/leave':         { icon: '🌴', title: 'Cuti', desc: 'Manajemen cuti karyawan' },
  'admin/overtime':      { icon: '⏰', title: 'Lembur', desc: 'Pengajuan & persetujuan lembur' },
  'admin/payroll':       { icon: '💰', title: 'Payroll', desc: 'Gaji & kompensasi karyawan' },
  'admin/timesheet':     { icon: '⏱️', title: 'Timesheet', desc: 'Catatan jam kerja harian' },
  'admin/shift-swap':    { icon: '🔄', title: 'Shift Swap', desc: 'Tukar jadwal shift' },

  // TALENT & PERFORMANCE
  'admin/kpi':           { icon: '📊', title: 'KPI', desc: 'Key Performance Indicator' },
  'admin/okr':           { icon: '🎯', title: 'OKR', desc: 'Objectives & Key Results' },
  'admin/learning':      { icon: '📚', title: 'Learning', desc: 'Program pelatihan & kursus' },
  'admin/certifications':{ icon: '📜', title: 'Sertifikasi', desc: 'Sertifikasi profesional' },
  'admin/badges':        { icon: '🏅', title: 'Badge & Gamifikasi', desc: 'Sistem penghargaan & poin' },
  'admin/talent':        { icon: '🎯', title: 'Talent Market', desc: 'Marketplace internal talent' },
  'admin/career':        { icon: '🧭', title: 'Career Path', desc: 'Jalur karir & promosi' },

  // ASET & FASILITAS
  'admin/assets':        { icon: '🛠️', title: 'Inventaris', desc: 'Inventaris aset perusahaan' },
  'admin/asset-assign':  { icon: '📦', title: 'Check-in/out', desc: 'Peminjaman & pengembalian aset' },
  'admin/estate':        { icon: '🌳', title: 'Estate Blocks', desc: 'Blok perumahan & fasilitas' },
  'admin/facility':      { icon: '🏗️', title: 'Facility Request', desc: 'Permintaan fasilitas kerja' },

  // ENGAGEMENT & BUDAYA
  'admin/surveys':       { icon: '📋', title: 'Survei (eNPS)', desc: 'Employee Net Promoter Score' },
  'admin/voice':         { icon: '💡', title: 'Ide & Voice', desc: 'Saran & masukan karyawan' },
  'admin/whistleblower': { icon: '🕊️', title: 'Whistleblowing', desc: 'Laporan pelanggaran anonim' },

  // OFFBOARDING
  'admin/exit':          { icon: '🚪', title: 'Exit Interview', desc: 'Wawancara keluar karyawan' },
  'admin/settlement':    { icon: '📄', title: 'Final Settlement', desc: 'Pelunasan hak karyawan' },
  'admin/clearance':     { icon: '✅', title: 'Clearance', desc: 'Checklist serah terima' },

  // SISTEM & KEAMANAN
  'admin/audit':         { icon: '📋', title: 'Audit Log', desc: 'Log aktivitas sistem' },
  'admin/export':        { icon: '📤', title: 'Export Data', desc: 'Ekspor data ke Excel/CSV' },
  'admin/features':      { icon: '⚙️', title: 'Feature Flags', desc: 'Toggle fitur aktif/nonaktif' },
  'admin/settings':      { icon: '🔐', title: 'Pengaturan', desc: 'Konfigurasi sistem' },
  'admin/chain':         { icon: '🔗', title: 'Audit Chain', desc: 'Rantai audit transparan' },

  // PERENCANAAN
  'admin/headcount':     { icon: '📊', title: 'Headcount Plan', desc: 'Perencanaan jumlah karyawan' },
  'admin/budget':        { icon: '💰', title: 'Budget Allocation', desc: 'Alokasi anggaran HR' },
  'admin/referral':      { icon: '🤝', title: 'Referral Program', desc: 'Program rekomendasi karyawan' },

  // WORKER SUB-PAGES
  'worker/attendance':   { icon: '📍', title: 'Kehadiran', desc: 'Riwayat kehadiran harian' },
  'worker/leave':        { icon: '🌴', title: 'Cuti', desc: 'Ajukan & lihat status cuti' },
  'worker/overtime':     { icon: '💼', title: 'Lembur', desc: 'Ajukan & lihat lembur' },
  'worker/kpi':          { icon: '📊', title: 'KPI Saya', desc: 'Target & pencapaian performa' },
  'worker/payroll':      { icon: '💰', title: 'Slip Gaji', desc: 'Lihat slip gaji bulanan' },
  'worker/learning':     { icon: '📚', title: 'Learning', desc: 'Kursus & pelatihan' },
  'worker/career':       { icon: '🚀', title: 'Karir', desc: 'Jalur karir & peluang' },
  'worker/tasks':        { icon: '✅', title: 'Tasks', desc: 'Daftar tugas harian' },
  'worker/profile':      { icon: '👤', title: 'Profil Saya', desc: 'Data profil & pengaturan' },
  'worker/activities':   { icon: '📋', title: 'Aktivitas', desc: 'Riwayat aktivitas terkini' },
};

export default function PagePlaceholder({ pageKey }) {
  const navigate = useNavigate();
  const meta = PAGE_META[pageKey] || { icon: '📄', title: pageKey, desc: 'Halaman dalam pengembangan' };

  return (
    <PageLayout backTo="-1" title={meta.title} subtitle={meta.desc}>
      <div className="flex flex-col items-center justify-center py-20 text-center animate-fade-in">
        <span className="text-6xl mb-4">{meta.icon}</span>
        <h2 className="text-xl font-bold text-white mb-2">{meta.title}</h2>
        <p className="text-sm text-slate-400 mb-6 max-w-xs">{meta.desc}</p>
        <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-amber-500/10 border border-amber-500/20">
          <span className="text-amber-400">🚧</span>
          <span className="text-xs font-semibold text-amber-300">Halaman ini sedang dalam pengembangan</span>
        </div>
        <button
          onClick={() => navigate(-1)}
          className="mt-8 px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-slate-300 text-sm font-semibold transition-all active:scale-95"
        >
          ← Kembali
        </button>
      </div>
    </PageLayout>
  );
}
