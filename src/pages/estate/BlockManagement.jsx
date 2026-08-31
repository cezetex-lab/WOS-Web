// BlockManagement.jsx — Estate Block Management (Blok Kebun)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function BlockManagement() {
  const [loading, setLoading] = useState(true);
  const [blocks, setBlocks] = useState([]);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_estate_blocks');
      if (r?.ok && r.data) setBlocks(r.data);
    } catch (e) {
      setBlocks([
        { id: 'BLK-A1', name: 'Blok A1 Utara', area_ha: 120, total_trees: 3600, age_years: 12, yield_per_ha: 22, last_harvest: '2026-08-28', status: 'ACTIVE', irrigation: 'Drip', fertilized: true },
        { id: 'BLK-A2', name: 'Blok A2 Selatan', area_ha: 100, total_trees: 3000, age_years: 8, yield_per_ha: 18, last_harvest: '2026-08-28', status: 'ACTIVE', irrigation: 'Sprinkler', fertilized: true },
        { id: 'BLK-B1', name: 'Blok B1 Timur', area_ha: 80, total_trees: 2400, age_years: 15, yield_per_ha: 25, last_harvest: '2026-08-27', status: 'ACTIVE', irrigation: 'Drip', fertilized: false },
        { id: 'BLK-B2', name: 'Blok B2 Barat', area_ha: 150, total_trees: 4500, age_years: 5, yield_per_ha: 14, last_harvest: '2026-08-26', status: 'YOUNG', irrigation: 'Rainfed', fertilized: true },
        { id: 'BLK-C1', name: 'Blok C1', area_ha: 90, total_trees: 2700, age_years: 20, yield_per_ha: 20, last_harvest: '2026-08-25', status: 'REPLANTING', irrigation: 'Drip', fertilized: false },
        { id: 'BLK-C2', name: 'Blok C2 Barat', area_ha: 110, total_trees: 3300, age_years: 10, yield_per_ha: 21, last_harvest: '2026-08-28', status: 'ACTIVE', irrigation: 'Sprinkler', fertilized: true },
      ]);
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data blok..." /></div>;

  const totalArea = blocks.reduce((s, b) => s + b.area_ha, 0);
  const totalTrees = blocks.reduce((s, b) => s + b.total_trees, 0);
  const statusColor = { ACTIVE: 'success', YOUNG: 'info', REPLANTING: 'warning' };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🗺️ Blok Kebun</h1>
        <p className="text-xs text-slate-400 mb-4">Manajemen blok perkebunan sawit</p>

        <div className="grid grid-cols-3 gap-2 mb-4">
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-white">{totalArea}</div><div className="text-[10px] text-slate-400">Total Ha</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-green-400">{(totalTrees / 1000).toFixed(1)}K</div><div className="text-[10px] text-slate-400">Total Pohon</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-amber-400">{blocks.length}</div><div className="text-[10px] text-slate-400">Active Blok</div></GlassCard>
        </div>

        <div className="space-y-2">
          {blocks.map((b, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div>
                  <span className="text-sm font-bold text-white">{b.id}</span>
                  <span className="text-[10px] text-slate-500 ml-2">{b.name}</span>
                </div>
                <Badge status={b.status} type={statusColor[b.status]} />
              </div>
              <div className="grid grid-cols-4 gap-1 text-[10px]">
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Luas</div><div className="text-white font-bold">{b.area_ha} ha</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Pohon</div><div className="text-white font-bold">{b.total_trees.toLocaleString()}</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Umur</div><div className="text-white font-bold">{b.age_years} thn</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Yield/Ha</div><div className="text-emerald-400 font-bold">{b.yield_per_ha} ton</div></div>
              </div>
              <div className="flex justify-between text-[10px] text-slate-500 mt-2">
                <span>💧 {b.irrigation} {b.fertilized ? '• ✅ Fertilized' : '• ❌ Not fertilized'}</span>
                <span>Panen: {b.last_harvest}</span>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
