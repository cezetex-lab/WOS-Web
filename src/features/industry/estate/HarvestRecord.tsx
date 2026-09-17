// HarvestRecord.tsx — Estate Harvest Record (TBS Tandan Buah Segar)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function HarvestRecord() {
  const [loading, setLoading] = useState(true);
  const [records, setRecords] = useState<any[]>([]);
  const [summary, setSummary] = useState<any>(null);
  const [formBlock, setFormBlock] = useState('BLOK-A1');
  const [formWeight, setFormWeight] = useState('');
  const [formRipe, setFormRipe] = useState('80');
  const [formQuality, setFormQuality] = useState('A');
  const [submitting, setSubmitting] = useState(false);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_harvest_records');
      if (r?.ok && r.data) { setRecords(r.data); setSummary(r.summary); }
    } catch (e) {
      setRecords([]);
    }
    setLoading(false);
  }

  async function handleSubmit() {
    if (!formWeight || Number(formWeight) <= 0) {
      toast.error('Berat harus lebih dari 0');
      return;
    }
    setSubmitting(true);
    try {
      const r = await rpc('create_harvest_record', {
        p_block: formBlock,
        p_weight_kg: Number(formWeight),
        p_ripe_pct: Number(formRipe),
        p_quality: formQuality,
      });
      if (r?.ok) {
        toast.success(r.msg || 'Panen tercatat');
        setFormWeight('');
        loadData();
      } else {
        toast.error(r?.msg || 'Gagal mencatat panen');
      }
    } catch (e) {
      toast.error('Gagal mencatat panen');
    }
    setSubmitting(false);
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
              <select value={formBlock} onChange={e => setFormBlock(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option>BLOK-A1</option><option>BLOK-A2</option><option>BLOK-B1</option><option>BLOK-B2</option><option>BLOK-C1</option><option>BLOK-C2</option>
              </select>
              <select value={formQuality} onChange={e => setFormQuality(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option value="A">Grade A</option><option value="B">Grade B</option><option value="C">Grade C</option>
              </select>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <input type="number" value={formWeight} onChange={e => setFormWeight(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" placeholder="Berat (kg)" />
              <input type="number" value={formRipe} onChange={e => setFormRipe(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" placeholder="Kematangan %" min="0" max="100" />
            </div>
            <button onClick={handleSubmit} disabled={submitting} className="w-full py-2 rounded-lg bg-green-500/20 text-green-400 text-sm font-bold hover:bg-green-500/30 disabled:opacity-50">
              {submitting ? '⏳ Menyimpan...' : '📤 Catat Panen'}
            </button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
