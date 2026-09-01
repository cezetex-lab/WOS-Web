// Irrigation.jsx — Estate Irrigation System Monitoring
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner } from '@/lib/design-system';

const ZONES = [
  { id: 'IRR-001', zone: 'BLK-A', system: 'Drip', status: 'ACTIVE', flow_lpm: 45, pressure_bar: 2.1, soil_moisture: 68, last_irrigation: '2026-08-28 06:00', water_source: 'River Pump', ph: 6.5 },
  { id: 'IRR-002', zone: 'BLK-B', system: 'Sprinkler', status: 'ACTIVE', flow_lpm: 120, pressure_bar: 3.5, soil_moisture: 72, last_irrigation: '2026-08-28 05:30', water_source: 'Reservoir', ph: 6.8 },
  { id: 'IRR-003', zone: 'BLK-C', system: 'Drip', status: 'MAINTENANCE', flow_lpm: 0, pressure_bar: 0, soil_moisture: 45, last_irrigation: '2026-08-26', water_source: 'River Pump', ph: 6.5 },
  { id: 'IRR-004', zone: 'BLK-D', system: 'Rainfed', status: 'MONITORING', flow_lpm: 0, pressure_bar: 0, soil_moisture: 55, last_irrigation: 'Rainfall only', water_source: 'Rain', ph: 7.0 },
  { id: 'IRR-005', zone: 'BLK-E', system: 'Drip', status: 'ACTIVE', flow_lpm: 50, pressure_bar: 2.3, soil_moisture: 70, last_irrigation: '2026-08-28 04:30', water_source: 'Well', ph: 6.7 },
];

export default function Irrigation() {
  const [loading, setLoading] = useState(true);
  const [zones, setZones] = useState([]);

  useEffect(() => { setTimeout(() => { setZones(ZONES); setLoading(false); }, 500); }, []);

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data irigrasi..." /></div>;

  const activeZones = zones.filter(z => z.status === 'ACTIVE').length;
  const avgMoisture = Math.round(zones.reduce((s, z) => s + z.soil_moisture, 0) / zones.length);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">💧 Irigrasi</h1>
        <p className="text-xs text-slate-400 mb-4">Monitoring sistem pengairan kebun</p>

        <div className="grid grid-cols-3 gap-2 mb-4">
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-blue-400">{activeZones}</div><div className="text-[10px] text-slate-400">Active Zones</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-emerald-400">{avgMoisture}%</div><div className="text-[10px] text-slate-400">Avg Moisture</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-amber-400">{zones.filter(z => z.soil_moisture < 50).length}</div><div className="text-[10px] text-slate-400">Low Moisture</div></GlassCard>
        </div>

        <div className="space-y-2">
          {zones.map((z, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-bold text-white">{z.zone} — {z.system}</span>
                <Badge status={z.status} type={z.status === 'ACTIVE' ? 'success' : z.status === 'MAINTENANCE' ? 'warning' : 'info'} />
              </div>
              <div className="grid grid-cols-3 gap-1 text-[10px]">
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Flow</div><div className="text-blue-400 font-bold">{z.flow_lpm} LPM</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Pressure</div><div className="text-white font-bold">{z.pressure_bar} bar</div></div>
                <div className="bg-slate-800/40 rounded p-1.5 text-center"><div className="text-slate-500">Moisture</div><div className={`font-bold ${z.soil_moisture < 50 ? 'text-red-400' : z.soil_moisture < 65 ? 'text-amber-400' : 'text-emerald-400'}`}>{z.soil_moisture}%</div></div>
              </div>
              <div className="flex justify-between text-[10px] text-slate-500 mt-2">
                <span>💧 {z.water_source} • pH {z.ph}</span>
                <span>Last: {z.last_irrigation}</span>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
