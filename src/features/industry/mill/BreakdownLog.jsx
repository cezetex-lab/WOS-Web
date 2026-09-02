import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner } from '@/lib/design-system';

export default function BreakdownLog() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('ALL');

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.rpc('get_breakdown_log', { p_limit: 50 });
      setLogs(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat log breakdown..." />;

  const open = logs.filter(l => l.status === 'OPEN' || l.status === 'IN_PROGRESS').length;
  const critical = logs.filter(l => l.severity === 'CRITICAL' || l.severity === 'HIGH').length;
  const totalDowntime = logs.reduce((s, l) => s + (l.downtime || 0), 0);
  const totalCost = logs.reduce((s, l) => s + (l.cost || 0), 0);
  const filtered = filter === 'ALL' ? logs : logs.filter(l => l.status === filter);

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">🚨 Breakdown Report</h1>
      <p className="text-slate-400 text-sm mb-6">Log kerusakan equipment — Pabrik PKS</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="🚨" value={open} label="Open Issues" trend="Belum selesai" color="red" />
        <MetricCard icon="⚠️" value={critical} label="Critical/High" trend="Prioritas" color="orange" />
        <MetricCard icon="⏱️" value={`${totalDowntime}h`} label="Total Downtime" trend="Jam" color="blue" />
        <MetricCard icon="💰" value={`Rp ${(totalCost / 1000000).toFixed(0)}Jt`} label="Total Biaya" trend="维修费用" color="purple" />
      </div>

      <div className="flex gap-2 mb-4 overflow-x-auto pb-2">
        {['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map(s => (
          <button key={s} onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold whitespace-nowrap ${filter === s ? 'bg-teal-500 text-white' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'}`}>
            {s === 'ALL' ? 'Semua' : s}
          </button>
        ))}
      </div>

      <div className="space-y-3">
        {filtered.map((l) => (
          <GlassCard key={l.id} title={`${l.equipment} — ${l.equipment_name}`} icon="🚨"
            accent={l.severity === 'CRITICAL' || l.severity === 'HIGH' ? 'red' : l.severity === 'MEDIUM' ? 'orange' : 'slate'}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Severity</p>
                <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                  l.severity === 'CRITICAL' ? 'bg-red-500/20 text-red-400' :
                  l.severity === 'HIGH' ? 'bg-orange-500/20 text-orange-400' :
                  l.severity === 'MEDIUM' ? 'bg-yellow-500/20 text-yellow-400' :
                  'bg-slate-500/20 text-slate-400'
                }`}>{l.severity}</span>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Kategori</p>
                <p className="text-sm text-white">{l.category}</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Status</p>
                <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                  l.status === 'OPEN' ? 'bg-red-500/20 text-red-400' :
                  l.status === 'IN_PROGRESS' ? 'bg-yellow-500/20 text-yellow-400' :
                  'bg-green-500/20 text-green-400'
                }`}>{l.status}</span>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Downtime</p>
                <p className="text-sm text-white font-bold">{l.downtime} jam</p>
              </div>
              <div className="col-span-2">
                <p className="text-[11px] text-slate-500 uppercase">Deskripsi</p>
                <p className="text-sm text-slate-300">{l.description}</p>
              </div>
              {l.root_cause && (
                <div className="col-span-2">
                  <p className="text-[11px] text-slate-500 uppercase">Root Cause</p>
                  <p className="text-sm text-slate-300">{l.root_cause}</p>
                </div>
              )}
              {l.action && (
                <div className="col-span-2">
                  <p className="text-[11px] text-slate-500 uppercase">Action Taken</p>
                  <p className="text-sm text-slate-300">{l.action}</p>
                </div>
              )}
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Biaya</p>
                <p className="text-sm text-white">Rp {l.cost?.toLocaleString()}</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Dilaporkan</p>
                <p className="text-sm text-white">{l.reported_by}</p>
              </div>
            </div>
          </GlassCard>
        ))}
      </div>
    </div>
  );
}
