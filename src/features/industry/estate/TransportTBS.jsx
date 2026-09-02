// TransportTBS.jsx — Estate Transport TBS (Truck Dispatch)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function TransportTBS() {
  const [loading, setLoading] = useState(true);
  const [dispatches, setDispatches] = useState([]);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_transport_dispatch');
      if (r?.ok && r.data) setDispatches(r.data);
    } catch (e) {
      setDispatches([
        { id: 'DSP-001', truck: 'T-001', driver: 'EST0002', from: 'BLOK-A1', weight_ton: 25, status: 'DELIVERED', depart: '06:00', arrive: '07:30', destination: 'MILL-01' },
        { id: 'DSP-002', truck: 'T-002', driver: 'EST0003', from: 'BLOK-B2', weight_ton: 28, status: 'IN_TRANSIT', depart: '07:00', arrive: null, destination: 'MILL-01' },
        { id: 'DSP-003', truck: 'T-003', driver: 'EST0004', from: 'BLOK-A2', weight_ton: 22, status: 'LOADING', depart: null, arrive: null, destination: 'MILL-01' },
        { id: 'DSP-004', truck: 'T-001', driver: 'EST0002', from: 'BLOK-C1', weight_ton: 20, status: 'SCHEDULED', depart: null, arrive: null, destination: 'MILL-01' },
        { id: 'DSP-005', truck: 'T-004', driver: 'EST0006', from: 'BLOK-C2', weight_ton: 24, status: 'DELIVERED', depart: '05:30', arrive: '07:00', destination: 'MILL-01' },
      ]);
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat transport..." /></div>;

  const statusColor = { DELIVERED: 'success', IN_TRANSIT: 'info', LOADING: 'warning', SCHEDULED: 'default' };
  const delivered = dispatches.filter(d => d.status === 'DELIVERED').reduce((s, d) => s + d.weight_ton, 0);
  const total = dispatches.reduce((s, d) => s + d.weight_ton, 0);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🚛 Transport TBS</h1>
        <p className="text-xs text-slate-400 mb-4">Jadwal & tracking pengiriman TBS ke pabrik</p>

        <div className="grid grid-cols-2 gap-2 mb-4">
          <GlassCard className="p-3"><div className="text-lg font-bold text-emerald-400">{delivered} ton</div><div className="text-[11px] text-slate-400">Terkirim Hari Ini</div></GlassCard>
          <GlassCard className="p-3"><div className="text-lg font-bold text-white">{total} ton</div><div className="text-[11px] text-slate-400">Total Dispatch</div></GlassCard>
        </div>

        <div className="space-y-2">
          {dispatches.map((d, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-1">
                <div className="flex items-center gap-2">
                  <span className="text-xl">🚛</span>
                  <div>
                    <span className="text-sm font-bold text-white">{d.id}</span>
                    <span className="text-[11px] text-slate-500 ml-2">{d.truck} • {d.driver}</span>
                  </div>
                </div>
                <Badge status={d.status} type={statusColor[d.status]} />
              </div>
              <div className="grid grid-cols-3 gap-1 text-[11px] mt-2">
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Dari</div><div className="text-white font-bold">{d.from}</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Tonase</div><div className="text-emerald-400 font-bold">{d.weight_ton} ton</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">ETA</div><div className="text-white font-bold">{d.arrive || d.depart || '—'}</div></div>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
