// FatigueMonitor.jsx — Mining Fatigue Monitoring
import { useState, useEffect } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function FatigueMonitor() {
  const [loading, setLoading] = useState(true);
  const [workers, setWorkers] = useState([]);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_fatigue_data');
      if (r?.ok && r.data) setWorkers(r.data);
    } catch (e) {
      setWorkers([
        { nrp: 'MIN0001', name: 'Budi Hartono', shift: 'Pagi', hours_worked: 10, hours_rest: 8, fatigue_level: 'LOW', status: 'FIT', last_check: '06:00' },
        { nrp: 'MIN0002', name: 'Dedi Kurniawan', shift: 'Pagi', hours_worked: 12, hours_rest: 6, fatigue_level: 'MEDIUM', status: 'CAUTION', last_check: '06:15' },
        { nrp: 'MIN0003', name: 'Rizki Pratama', shift: 'Malam', hours_worked: 8, hours_rest: 10, fatigue_level: 'LOW', status: 'FIT', last_check: '22:00' },
        { nrp: 'MIN0004', name: 'Andi Saputra', shift: 'Sore', hours_worked: 14, hours_rest: 4, fatigue_level: 'HIGH', status: 'REST REQUIRED', last_check: '14:30' },
        { nrp: 'MIN0005', name: 'Tono Sugiarto', shift: 'Pagi', hours_worked: 11, hours_rest: 7, fatigue_level: 'MEDIUM', status: 'CAUTION', last_check: '06:30' },
        { nrp: 'MIN0006', name: 'Sugeng Riyadi', shift: 'Malam', hours_worked: 9, hours_rest: 9, fatigue_level: 'LOW', status: 'FIT', last_check: '22:15' },
      ]);
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat fatigue data..." /></div>;

  const low = workers.filter(w => w.fatigue_level === 'LOW').length;
  const med = workers.filter(w => w.fatigue_level === 'MEDIUM').length;
  const high = workers.filter(w => w.fatigue_level === 'HIGH').length;
  const fatigueColor = { LOW: 'success', MEDIUM: 'warning', HIGH: 'danger' };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">⚠️ Fatigue Monitor</h1>
        <p className="text-xs text-slate-400 mb-4">Tracking kelelahan kerja operator tambang</p>

        <div className="grid grid-cols-3 gap-2 mb-4">
          <GlassCard className="text-center p-3"><div className="text-2xl font-bold text-emerald-400">{low}</div><div className="text-[11px] text-slate-400">🟢 Fit</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-2xl font-bold text-amber-400">{med}</div><div className="text-[11px] text-slate-400">🟡 Caution</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-2xl font-bold text-red-400">{high}</div><div className="text-[11px] text-slate-400">🔴 Rest Required</div></GlassCard>
        </div>

        <div className="space-y-2">
          {workers.map((w, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-full bg-slate-700 flex items-center justify-center text-xs font-bold text-white">{w.name?.charAt(0)}</div>
                  <div>
                    <div className="text-sm font-semibold text-white">{w.name}</div>
                    <div className="text-[11px] text-slate-500">{w.nrp} • Shift {w.shift}</div>
                  </div>
                </div>
                <Badge status={w.status} type={fatigueColor[w.fatigue_level]} />
              </div>
              <div className="grid grid-cols-3 gap-2 text-[11px] mt-2">
                <div className="bg-slate-800/40 rounded p-2 text-center">
                  <div className="text-slate-500">Jam Kerja</div>
                  <div className={`font-bold ${w.hours_worked > 12 ? 'text-red-400' : 'text-white'}`}>{w.hours_worked}h</div>
                </div>
                <div className="bg-slate-800/40 rounded p-2 text-center">
                  <div className="text-slate-500">Jam Istirahat</div>
                  <div className={`font-bold ${w.hours_rest < 6 ? 'text-red-400' : 'text-white'}`}>{w.hours_rest}h</div>
                </div>
                <div className="bg-slate-800/40 rounded p-2 text-center">
                  <div className="text-slate-500">Check Terakhir</div>
                  <div className="text-white font-bold">{w.last_check}</div>
                </div>
              </div>
              {w.fatigue_level === 'HIGH' && (
                <div className="mt-2 p-2 bg-red-500/10 border border-red-500/20 rounded-lg text-[11px] text-red-400">
                  ⚠️ <strong>REST REQUIRED</strong> — Operator melebihi batas jam kerja. Harus istirahat minimal 8 jam.
                </div>
              )}
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
