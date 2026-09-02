// MedicalCheckup.jsx — Estate Medical (Puskesmas Kebun)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner } from '@/lib/design-system';

const RECORDS = [
  { nrp: 'EST0001', name: 'Andi Saputra', date: '2026-08-15', type: 'Annual Checkup', bpjs: '8801-0012-3456', status: 'COMPLETED', results: 'Sehat, BMI 23.5, Tensi 120/80' },
  { nrp: 'EST0002', name: 'Budi Hartono', date: '2026-08-18', type: 'Pre-shift Medical', bpjs: '8801-0012-3457', status: 'COMPLETED', results: 'Sehat, BP normal' },
  { nrp: 'EST0003', name: 'Rina Wati', date: '2026-08-20', type: 'Annual Checkup', bpjs: '8801-0012-3458', status: 'SCHEDULED', results: null },
  { nrp: 'EST0004', name: 'Dewi Sari', date: '2026-08-22', type: 'Injury Treatment', bpjs: '8801-0012-3459', status: 'COMPLETED', results: 'Luka gores tangan kanan, sudah diobati' },
  { nrp: 'EST0005', name: 'Hendra Wijaya', date: '2026-08-25', type: 'Vaccination (Hepatitis B)', bpjs: '8801-0012-3460', status: 'COMPLETED', results: 'Dosis 2/3 selesai' },
  { nrp: 'EST0006', name: 'Maya Putri', date: '2026-08-28', type: 'Pregnancy Checkup', bpjs: '8801-0012-3461', status: 'COMPLETED', results: 'Kehamilan 7 bulan, sehat' },
];

const HEALTH_STATS = { total: 6, completed: 4, scheduled: 1, pending: 1 };

export default function MedicalCheckup() {
  const [loading, setLoading] = useState(true);
  const [records, setRecords] = useState([]);

  useEffect(() => { rpc('get_medical_checkup', { p_nrp: '*' }).then(r => { setRecords(r?.data || []); setLoading(false); }).catch(() => setLoading(false)); }, []);

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data medical..." /></div>;

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🚑 Puskesmas Kebun</h1>
        <p className="text-xs text-slate-400 mb-4">Medical checkup & kesehatan karyawan kebun</p>

        <div className="grid grid-cols-3 gap-2 mb-4">
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-emerald-400">{HEALTH_STATS.completed}</div><div className="text-[11px] text-slate-400">Completed</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-amber-400">{HEALTH_STATS.scheduled}</div><div className="text-[11px] text-slate-400">Scheduled</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-blue-400">{HEALTH_STATS.pending}</div><div className="text-[11px] text-slate-400">Pending</div></GlassCard>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-2 gap-2 mb-4">
          <GlassCard className="p-3 text-center cursor-pointer hover:bg-white/5 transition-all">
            <div className="text-2xl mb-1">📞</div>
            <div className="text-xs font-semibold text-white">Hubungi Dokter</div>
            <div className="text-[11px] text-slate-500">ext 120</div>
          </GlassCard>
          <GlassCard className="p-3 text-center cursor-pointer hover:bg-white/5 transition-all">
            <div className="text-2xl mb-1">💊</div>
            <div className="text-xs font-semibold text-white">Ambil Obat</div>
            <div className="text-[11px] text-slate-500">Apotek kebun</div>
          </GlassCard>
        </div>

        <div className="space-y-2">
          {records.map((r, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-1">
                <div className="flex items-center gap-2">
                  <span className="text-lg">🩺</span>
                  <div>
                    <span className="text-sm font-bold text-white">{r.name}</span>
                    <span className="text-[11px] text-slate-500 ml-2">{r.nrp}</span>
                  </div>
                </div>
                <Badge status={r.status} type={r.status === 'COMPLETED' ? 'success' : r.status === 'SCHEDULED' ? 'warning' : 'info'} />
              </div>
              <div className="text-xs text-slate-300 mb-1">{r.type}</div>
              {r.results && <div className="text-[11px] text-emerald-400 bg-emerald-500/5 rounded p-1.5">✅ {r.results}</div>}
              <div className="flex justify-between text-[11px] text-slate-500 mt-1">
                <span>BPJS: {r.bpjs}</span>
                <span>📅 {r.date}</span>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
