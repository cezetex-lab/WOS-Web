import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner } from '@/lib/design-system';

const STATUS_COLORS = {
  RUNNING: 'bg-green-500/20 text-green-400 border-green-500/30',
  STANDBY: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
  MAINTENANCE: 'bg-orange-500/20 text-orange-400 border-orange-500/30',
  OFFLINE: 'bg-slate-500/20 text-slate-400 border-slate-500/30',
};

export default function MesinPress() {
  const [presses, setPresses] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.rpc('get_press_status');
      setPresses(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat data mesin press..." />;

  const running = presses.filter(p => p.status === 'RUNNING');
  const avgRpm = running.length > 0 ? (running.reduce((s, p) => s + (p.rpm || 0), 0) / running.length).toFixed(0) : 0;
  const avgVibration = running.length > 0 ? (running.reduce((s, p) => s + (p.vibration || 0), 0) / running.length).toFixed(1) : 0;
  const totalCapacity = presses.filter(p => p.status === 'RUNNING').reduce((s, p) => s + (p.capacity || 0), 0);

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">⚙️ Mesin Press</h1>
      <p className="text-slate-400 text-sm mb-6">Monitor screw press CPO — Pabrik PKS</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="⚙️" value={running.length} label="Press Running" trend={`dari ${presses.length}`} color="green" />
        <MetricCard icon="🔄" value={avgRpm} label="Avg RPM" trend="Target: 28" color="blue" />
        <MetricCard icon="📊" value={`${totalCapacity.toFixed(1)}`} label="Total Output" trend="ton/jam" color="teal" />
        <MetricCard icon="⚠️" value={avgVibration} label="Avg Vibration" trend="mm/s (warn: >3)" color={parseFloat(avgVibration) > 3 ? 'red' : 'green'} />
      </div>

      <div className="space-y-4">
        {presses.map((p) => (
          <GlassCard key={p.id} title={`${p.code} — ${p.name}`} icon="⚙️" accent={p.status === 'RUNNING' ? 'green' : 'slate'}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Status</p>
                <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-bold border ${STATUS_COLORS[p.status]}`}>{p.status}</span>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">RPM</p>
                <p className="text-lg font-bold text-white">{p.rpm}</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Torque</p>
                <p className="text-lg font-bold text-white">{p.torque} Nm</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Suhu</p>
                <p className="text-lg font-bold text-white">{p.temperature}°C</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Vibrasi</p>
                <p className={`text-lg font-bold ${p.vibration > 3 ? 'text-red-400' : 'text-green-400'}`}>{p.vibration} mm/s</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Oil Quality</p>
                <p className={`text-sm font-bold ${p.oil_quality === 'GOOD' ? 'text-green-400' : 'text-orange-400'}`}>{p.oil_quality}</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Kapasitas</p>
                <p className="text-sm text-white">{p.capacity} ton/jam</p>
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase">Maintenance</p>
                <p className="text-xs text-slate-300">Next: {p.next_maintenance || '-'}</p>
              </div>
            </div>
          </GlassCard>
        ))}
      </div>
    </div>
  );
}
