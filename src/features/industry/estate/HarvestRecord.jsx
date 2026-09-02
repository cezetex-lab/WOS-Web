// HarvestRecord.jsx — Estate Harvest Record (TBS Tandan Buah Segar)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function HarvestRecord() {
  const [loading, setLoading] = useState(true);
  const [records, setRecords] = useState([]);
  const [summary, setSummary] = useState(null);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_harvest_records');
      if (r?.ok && r.data) { setRecords(r.data); setSummary(r.summary); }
    } catch (e) {
      setRecords([
        { id: 'HVT-001', block: 'BLOK-A1', date: '2026-08-28', weight_kg: 25000, ripe_pct: 85, worker: 'EST0001', quality: 'A' },
        { id: 'HVT-002', block: 'BLOK-A2', date: '2026-08-28', weight_kg: 22000, ripe_pct: 78, worker: 'EST0002', quality: 'A' },
        { id: 'HVT-003', block: 'BLOK-B1', date: '2026-08-28', weight_kg: 18000, ripe_pct: 72, worker: 'EST0003', quality: 'B' },
        { id: 'HVT-004', block: 'BLOK-B2', date: '2026-08-28', weight_kg: 28000, ripe_pct: 90, worker: 'EST0004', quality: 'A' },
        { id: 'HVT-005', block: 'BLOK-C1', date: '2026-08-28', weight_kg: 15000, ripe_pct: 65, worker: 'EST0005', quality: 'B' },
        { id: 'HVT-006', block: 'BLOK-A1', date: '2026-08-27', weight_kg: 24000, ripe_pct: 82, worker: 'EST0001', quality: 'A' },
        { id: 'HVT-007', block: 'BLOK-C2', date: '2026-08-27', weight_kg: 20000, ripe_pct: 75, worker: 'EST0006', quality: 'B' },
      ]);
      setSummary({ total_ton: 152, avg_ripe: 78, target_ton: 180, achievement: 84 });
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data panen..." /></div>;

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🌾 Record Panen</h1>
        <p className="text-xs text-slate-400 mb-4">Tonase TBS per blok kebun</p>

        {summary && (
          <div className="grid grid-cols-2 gap-2 mb-4">
            <GlassCard className="p-3">
              <div className="text-lg font-bold text-white">{summary.total_ton} ton</div>
              <div className="text-[11px] text-slate-400">Total Panen Hari Ini</div>
              <div className="w-full bg-slate-700 rounded-full h-1.5 mt-2">
                <div className="h-1.5 rounded-full bg-emerald-500" style={{ width: `${Math.min(summary.achievement, 100)}%` }} />
              </div>
              <div className="text-[11px] text-slate-500 mt-1">{summary.achievement}% dari target {summary.target_ton} ton</div>
            </GlassCard>
            <GlassCard className="p-3">
              <div className="text-lg font-bold text-amber-400">{summary.avg_ripe}%</div>
              <div className="text-[11px] text-slate-400">Rata-rata Kematangan</div>
              <div className="mt-2 text-[11px] text-slate-500">
                {summary.avg_ripe >= 80 ? '✅ Siap panen' : summary.avg_ripe >= 60 ? '⚠️ Belum optimal' : '❌ Masih mentah'}
              </div>
            </GlassCard>
          </div>
        )}

        <div className="space-y-2">
          {records.map((r, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-1">
                <div className="flex items-center gap-2">
                  <span className="text-lg">🌴</span>
                  <span className="text-sm font-bold text-white">{r.block}</span>
                  <Badge status={`Grade ${r.quality}`} type={r.quality === 'A' ? 'success' : 'warning'} />
                </div>
                <span className="text-sm font-bold text-emerald-400">{(r.weight_kg / 1000).toFixed(1)} ton</span>
              </div>
              <div className="flex justify-between text-[11px] text-slate-500">
                <span>📅 {r.date}</span>
                <span>👷 {r.worker}</span>
                <span>🍊 Kematangan: {r.ripe_pct}%</span>
              </div>
            </GlassCard>
          ))}
        </div>

        {/* Quick Log */}
        <GlassCard title="📝 Log Panen Baru" icon="📝" accent="green" className="mt-4">
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-2">
              <select className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option>BLOK-A1</option><option>BLOK-A2</option><option>BLOK-B1</option><option>BLOK-B2</option><option>BLOK-C1</option><option>BLOK-C2</option>
              </select>
              <input type="number" className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" placeholder="Berat (kg)" />
            </div>
            <button className="w-full py-2 rounded-lg bg-green-500/20 text-green-400 text-sm font-bold hover:bg-green-500/30">📤 Catat Panen</button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
