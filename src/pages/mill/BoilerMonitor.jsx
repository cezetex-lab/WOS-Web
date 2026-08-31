import { useState, useEffect } from 'react';
import { supabase, getSession } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner, Badge } from '@/lib/design-system';

const STATUS_COLORS = {
  RUNNING: 'bg-green-500/20 text-green-400 border-green-500/30',
  STANDBY: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
  MAINTENANCE: 'bg-orange-500/20 text-orange-400 border-orange-500/30',
  OFFLINE: 'bg-slate-500/20 text-slate-400 border-slate-500/30',
};

export default function BoilerMonitor() {
  const [boilers, setBoilers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.rpc('get_boiler_status');
      setBoilers(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat data boiler..." />;

  const running = boilers.filter(b => b.status === 'RUNNING');
  const totalSteam = running.reduce((s, b) => s + (b.steam_flow || 0), 0);
  const avgEfficiency = running.length > 0 ? (running.reduce((s, b) => s + (b.efficiency || 0), 0) / running.length).toFixed(1) : 0;

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">🔥 Boiler Monitor</h1>
      <p className="text-slate-400 text-sm mb-6">Real-time status ketel uap — Pabrik PKS</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="🔥" value={running.length} label="Boiler Running" trend={`dari ${boilers.length} unit`} color="green" />
        <MetricCard icon="💨" value={`${(totalSteam / 1000).toFixed(1)}K`} label="Steam Flow" trend="kg/jam" color="blue" />
        <MetricCard icon="⚡" value={`${avgEfficiency}%`} label="Avg Efficiency" trend="Target: 80%" color="teal" />
        <MetricCard icon="🌡️" value={running[0]?.temperature || 0} label="Suhu Utama" trend="°C" color="orange" />
      </div>

      <div className="space-y-4">
        {boilers.map((b) => (
          <GlassCard key={b.id} title={`${b.code} — ${b.name}`} icon="🔥" accent={b.status === 'RUNNING' ? 'green' : 'slate'}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Status</p>
                <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-bold border ${STATUS_COLORS[b.status]}`}>{b.status}</span>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Suhu</p>
                <p className="text-lg font-bold text-white">{b.temperature}°C</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Tekanan</p>
                <p className="text-lg font-bold text-white">{b.pressure} bar</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Steam Flow</p>
                <p className="text-lg font-bold text-white">{b.steam_flow?.toLocaleString()} kg/jam</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Efisiensi</p>
                <p className="text-lg font-bold text-teal-400">{b.efficiency}%</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Bahan Bakar</p>
                <p className="text-sm text-white">{b.fuel_type}</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Konsumsi BB</p>
                <p className="text-sm text-white">{b.fuel_consumption?.toLocaleString()} kg/jam</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Maintenance</p>
                <p className="text-xs text-slate-300">Next: {b.next_maintenance || '-'}</p>
              </div>
            </div>
          </GlassCard>
        ))}
      </div>
    </div>
  );
}
