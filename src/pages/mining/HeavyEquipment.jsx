// HeavyEquipment.jsx — Mining Heavy Equipment Monitor
import { useState, useEffect } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, EmptyState, SectionHeader, useToast } from '@/lib/design-system';

const STATUS_COLOR = { 'OPERATIONAL': 'success', 'MAINTENANCE': 'warning', 'BREAKDOWN': 'danger', 'IDLE': 'info' };
const EQUIPMENT_TYPES = ['Excavator', 'Dump Truck', 'Bulldozer', 'Wheel Loader', 'Drill Rig', 'Grader'];

export default function HeavyEquipment() {
  const [loading, setLoading] = useState(true);
  const [equipment, setEquipment] = useState([]);
  const [filter, setFilter] = useState('ALL');
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_heavy_equipment');
      if (r?.ok && r.data) setEquipment(r.data);
    } catch (e) {
      setEquipment([
        { id: 'EXC-001', type: 'Excavator', brand: 'Caterpillar 320D', status: 'OPERATIONAL', operator: 'MIN0001', zone: 'PIT-1', hours: 12450, fuel_level: 78, next_service: '2026-09-15' },
        { id: 'EXC-002', type: 'Excavator', brand: 'Komatsu PC200', status: 'OPERATIONAL', operator: 'MIN0003', zone: 'PIT-2', hours: 8900, fuel_level: 62, next_service: '2026-09-20' },
        { id: 'TRK-001', type: 'Dump Truck', brand: 'Cat 777F', status: 'OPERATIONAL', operator: 'MIN0005', zone: 'HAUL ROAD', hours: 15600, fuel_level: 45, next_service: '2026-09-10' },
        { id: 'TRK-002', type: 'Dump Truck', brand: 'Komatsu HD785', status: 'MAINTENANCE', operator: null, zone: 'WORKSHOP', hours: 22300, fuel_level: 90, next_service: '2026-08-28' },
        { id: 'BDO-001', type: 'Bulldozer', brand: 'Cat D6T', status: 'OPERATIONAL', operator: 'MIN0007', zone: 'PIT-3', hours: 9800, fuel_level: 55, next_service: '2026-10-01' },
        { id: 'WLD-001', type: 'Wheel Loader', brand: 'Cat 966M', status: 'IDLE', operator: null, zone: 'WORKSHOP', hours: 6500, fuel_level: 82, next_service: '2026-10-15' },
        { id: 'DRL-001', type: 'Drill Rig', brand: 'Atlas Copco FlexiROC', status: 'BREAKDOWN', operator: null, zone: 'PIT-1', hours: 4200, fuel_level: 30, next_service: 'OVERDUE' },
        { id: 'GRD-001', type: 'Grader', brand: 'Cat 140M', status: 'OPERATIONAL', operator: 'MIN0002', zone: 'HAUL ROAD', hours: 11200, fuel_level: 70, next_service: '2026-09-25' },
      ]);
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat alat berat..." /></div>;

  const operational = equipment.filter(e => e.status === 'OPERATIONAL').length;
  const maintenance = equipment.filter(e => e.status === 'MAINTENANCE').length;
  const breakdown = equipment.filter(e => e.status === 'BREAKDOWN').length;
  const filtered = filter === 'ALL' ? equipment : equipment.filter(e => e.status === filter);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🏗️ Heavy Equipment</h1>
        <p className="text-xs text-slate-400 mb-4">Monitor unit alat berat pertambangan</p>

        {/* Stats */}
        <div className="grid grid-cols-4 gap-2 mb-4">
          <GlassCard className="text-center p-2"><div className="text-xl font-bold text-white">{equipment.length}</div><div className="text-[10px] text-slate-400">Total Unit</div></GlassCard>
          <GlassCard className="text-center p-2"><div className="text-xl font-bold text-emerald-400">{operational}</div><div className="text-[10px] text-slate-400">Operasional</div></GlassCard>
          <GlassCard className="text-center p-2"><div className="text-xl font-bold text-amber-400">{maintenance}</div><div className="text-[10px] text-slate-400">Maintenance</div></GlassCard>
          <GlassCard className="text-center p-2"><div className="text-xl font-bold text-red-400">{breakdown}</div><div className="text-[10px] text-slate-400">Breakdown</div></GlassCard>
        </div>

        {/* Filter */}
        <div className="flex gap-2 mb-4 overflow-x-auto pb-2">
          {['ALL', 'OPERATIONAL', 'MAINTENANCE', 'BREAKDOWN', 'IDLE'].map(f => (
            <button key={f} onClick={() => setFilter(f)} className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${filter === f ? 'bg-teal-500/20 text-teal-400' : 'bg-white/5 text-slate-400 hover:text-white'}`}>
              {f === 'ALL' ? '📋 Semua' : f === 'OPERATIONAL' ? '✅ Operasional' : f === 'MAINTENANCE' ? '🔧 Maintenance' : f === 'BREAKDOWN' ? '❌ Breakdown' : '⏸️ Idle'} ({f === 'ALL' ? equipment.length : equipment.filter(e => e.status === f).length})
            </button>
          ))}
        </div>

        {/* Equipment Cards */}
        <div className="space-y-2">
          {filtered.map((eq, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="text-lg">{eq.type === 'Excavator' ? '🏗️' : eq.type === 'Dump Truck' ? '🚛' : eq.type === 'Bulldozer' ? '🚜' : eq.type === 'Drill Rig' ? '🔩' : '🏗️'}</span>
                  <div>
                    <span className="text-sm font-bold text-white">{eq.id}</span>
                    <span className="text-[10px] text-slate-500 ml-2">{eq.brand}</span>
                  </div>
                </div>
                <Badge status={eq.status} type={STATUS_COLOR[eq.status]} />
              </div>
              <div className="grid grid-cols-2 gap-2 text-[10px]">
                <div className="bg-slate-800/40 rounded-lg p-2">
                  <div className="text-slate-500">Operator</div>
                  <div className="text-white font-semibold">{eq.operator || '—'}</div>
                </div>
                <div className="bg-slate-800/40 rounded-lg p-2">
                  <div className="text-slate-500">Zone</div>
                  <div className="text-white font-semibold">{eq.zone}</div>
                </div>
                <div className="bg-slate-800/40 rounded-lg p-2">
                  <div className="text-slate-500">Engine Hours</div>
                  <div className="text-white font-semibold">{eq.hours.toLocaleString()}h</div>
                </div>
                <div className="bg-slate-800/40 rounded-lg p-2">
                  <div className="text-slate-500">Fuel Level</div>
                  <div className={`font-semibold ${eq.fuel_level < 30 ? 'text-red-400' : eq.fuel_level < 60 ? 'text-amber-400' : 'text-emerald-400'}`}>{eq.fuel_level}%</div>
                </div>
              </div>
              <div className="mt-2 text-[10px] text-slate-500">Next service: <span className={eq.next_service === 'OVERDUE' ? 'text-red-400 font-bold' : 'text-slate-400'}>{eq.next_service}</span></div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
