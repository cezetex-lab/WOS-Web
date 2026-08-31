// Nursery.jsx — Estate Nursery (Persemaian Bibit)
import { useState, useEffect } from 'react';
import { GlassCard, Badge, LoadingSpinner } from '@/lib/design-system';

const SEEDLINGS = [
  { id: 'NRS-001', variety: 'Tenera', batch: 'Batch-2026-Q3', total: 5000, stage: 'SEEDLING', age_months: 2, health: 'GOOD', target_field: 'BLK-D1', ready_date: '2026-12-01' },
  { id: 'NRS-002', variety: 'DxP', batch: 'Batch-2026-Q2', total: 8000, stage: 'NURSERY', age_months: 8, health: 'EXCELLENT', target_field: 'BLK-E1', ready_date: '2026-10-01' },
  { id: 'NRS-003', variety: 'Tenera', batch: 'Batch-2026-Q1', total: 6000, stage: 'PRE_NURSERY', age_months: 12, health: 'GOOD', target_field: 'BLK-C1', ready_date: '2026-09-15' },
  { id: 'NRS-004', variety: 'DxP', batch: 'Batch-2025-Q4', total: 4000, stage: 'READY', age_months: 18, health: 'EXCELLENT', target_field: 'BLK-F1', ready_date: 'READY NOW' },
  { id: 'NRS-005', variety: 'Besoi', batch: 'Batch-2026-Q3', total: 3000, stage: 'SEEDLING', age_months: 1, health: 'FAIR', target_field: 'BLK-G1', ready_date: '2027-01-01' },
];

const STAGE_ORDER = ['SEEDLING', 'PRE_NURSERY', 'NURSERY', 'READY'];
const STAGE_COLOR = { SEEDLING: 'info', PRE_NURSERY: 'warning', NURSERY: 'success', READY: 'success' };
const HEALTH_COLOR = { EXCELLENT: 'success', GOOD: 'success', FAIR: 'warning', POOR: 'danger' };

export default function Nursery() {
  const [loading, setLoading] = useState(true);
  const [seedlings, setSeedlings] = useState([]);

  useEffect(() => { setTimeout(() => { setSeedlings(SEEDLINGS); setLoading(false); }, 500); }, []);

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat nursery..." /></div>;

  const totalSeedlings = seedlings.reduce((s, n) => s + n.total, 0);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🌱 Nursery</h1>
        <p className="text-xs text-slate-400 mb-4">Persemaian bibit sawit</p>

        <div className="grid grid-cols-2 gap-2 mb-4">
          <GlassCard className="p-3"><div className="text-lg font-bold text-green-400">{(totalSeedlings / 1000).toFixed(1)}K</div><div className="text-[10px] text-slate-400">Total Bibit</div></GlassCard>
          <GlassCard className="p-3"><div className="text-lg font-bold text-blue-400">{seedlings.filter(s => s.stage === 'READY').length}</div><div className="text-[10px] text-slate-400">Siap Tanam</div></GlassCard>
        </div>

        {/* Stage Pipeline */}
        <GlassCard title="📊 Pipeline Stages" icon="📊" accent="teal" className="mb-4">
          <div className="flex gap-1 items-center">
            {STAGE_ORDER.map((stage, i) => (
              <div key={stage} className="flex-1 text-center">
                <div className={`text-lg font-bold text-${STAGE_COLOR[stage] === 'success' ? 'emerald' : STAGE_COLOR[stage] === 'warning' ? 'amber' : 'blue'}-400`}>
                  {seedlings.filter(s => s.stage === stage).reduce((sum, s) => sum + s.total, 0).toLocaleString()}
                </div>
                <div className="text-[8px] text-slate-500">{stage.replace('_', ' ')}</div>
                {i < STAGE_ORDER.length - 1 && <span className="text-slate-600 text-xs">→</span>}
              </div>
            ))}
          </div>
        </GlassCard>

        <div className="space-y-2">
          {seedlings.map((n, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="text-lg">🌱</span>
                  <div>
                    <span className="text-sm font-bold text-white">{n.id}</span>
                    <span className="text-[10px] text-slate-500 ml-2">{n.variety}</span>
                  </div>
                </div>
                <Badge status={n.stage.replace('_', ' ')} type={STAGE_COLOR[n.stage]} />
              </div>
              <div className="grid grid-cols-4 gap-1 text-[10px]">
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Batch</div><div className="text-white font-bold">{n.batch}</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Jumlah</div><div className="text-white font-bold">{n.total.toLocaleString()}</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Umur</div><div className="text-white font-bold">{n.age_months} bln</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Health</div><div className="text-white font-bold"><Badge status={n.health} type={HEALTH_COLOR[n.health]} /></div></div>
              </div>
              <div className="text-[10px] text-slate-500 mt-2">Target: {n.target_field} • Ready: {n.ready_date}</div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
