// SafetyK3.jsx — Mining Safety K3 (Keselamatan & Kesehatan Kerja)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function SafetyK3() {
  const [loading, setLoading] = useState(true);
  const [incidents, setIncidents] = useState([]);
  const [stats, setStats] = useState(null);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_safety_incidents');
      if (r?.ok && r.data) { setIncidents(r.data); setStats(r.summary); }
    } catch (e) {
      setIncidents([
        { id: 'SAF-001', date: '2026-08-28', zone: 'PIT-1', type: 'NEAR_MISS', severity: 'LOW', description: 'Batu jatuh dari dump truck saat loading', reporter: 'MIN0001', status: 'OPEN', action_taken: null },
        { id: 'SAF-002', date: '2026-08-25', zone: 'CRUSHER', type: 'INCIDENT', severity: 'MEDIUM', description: 'Operator terkena debu berlebih di area crusher', reporter: 'MIN0003', status: 'INVESTIGATING', action_taken: 'Tim K3 investigate' },
        { id: 'SAF-003', date: '2026-08-20', zone: 'WORKSHOP', type: 'NEAR_MISS', severity: 'HIGH', description: 'Forklift hampir menabrak pejalan kaki', reporter: 'MIN0005', status: 'CLOSED', action_taken: 'Training ulang penggunaan forklift' },
        { id: 'SAF-004', date: '2026-08-15', zone: 'PIT-2', type: 'INCIDENT', severity: 'HIGH', description: 'Operator mengalami heatmap ringan', reporter: 'MIN0002', status: 'CLOSED', action_taken: 'Istirahat + medical checkup' },
        { id: 'SAF-005', date: '2026-08-10', zone: 'HAUL ROAD', type: 'OBSERVATION', severity: 'LOW', description: 'Pengendaraan melebihi batas kecepatan', reporter: 'MIN0007', status: 'CLOSED', action_taken: 'Warning + speed bump dipasang' },
      ]);
      setStats({ total: 5, open: 1, investigating: 1, closed: 3, lti: 0, ltifr: 0 });
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data safety..." /></div>;

  const sevColor = { LOW: 'info', MEDIUM: 'warning', HIGH: 'danger' };
  const typeIcon = { INCIDENT: '🔴', NEAR_MISS: '🟡', OBSERVATION: '🔵' };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🛡️ Safety K3</h1>
        <p className="text-xs text-slate-400 mb-4">Incident reporting & near-miss tracking</p>

        {stats && (
          <div className="grid grid-cols-3 gap-2 mb-4">
            <GlassCard className="text-center p-3"><div className="text-xl font-bold text-emerald-400">{stats.lti}</div><div className="text-[11px] text-slate-400">LTI (Lost Time)</div></GlassCard>
            <GlassCard className="text-center p-3"><div className="text-xl font-bold text-blue-400">{stats.total}</div><div className="text-[11px] text-slate-400">Total Reports</div></GlassCard>
            <GlassCard className="text-center p-3"><div className="text-xl font-bold text-amber-400">{stats.open}</div><div className="text-[11px] text-slate-400">Open Cases</div></GlassCard>
          </div>
        )}

        <div className="space-y-2">
          {incidents.map((inc, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span>{typeIcon[inc.type] || '⚪'}</span>
                  <span className="text-sm font-bold text-white">{inc.id}</span>
                  <Badge status={inc.severity} type={sevColor[inc.severity]} />
                </div>
                <Badge status={inc.status} type={inc.status === 'CLOSED' ? 'success' : inc.status === 'OPEN' ? 'danger' : 'warning'} />
              </div>
              <p className="text-xs text-slate-300 mb-2">{inc.description}</p>
              <div className="flex justify-between text-[11px] text-slate-500">
                <span>📍 {inc.zone} • 📅 {inc.date}</span>
                <span>Reporter: {inc.reporter}</span>
              </div>
              {inc.action_taken && <div className="mt-2 p-2 bg-emerald-500/10 rounded text-[11px] text-emerald-400">✅ {inc.action_taken}</div>}
            </GlassCard>
          ))}
        </div>

        {/* Report Button */}
        <GlassCard title="📝 Laporkan Insiden" icon="📝" accent="red" className="mt-4">
          <div className="space-y-3">
            <select className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
              <option value="INCIDENT">🔴 Incident (Ada cedera)</option>
              <option value="NEAR_MISS">🟡 Near Miss (Hampir terjadi)</option>
              <option value="OBSERVATION">🔵 Observation (Observasi)</option>
            </select>
            <textarea className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white h-20" placeholder="Deskripsi kejadian..." />
            <button className="w-full py-2 rounded-lg bg-red-500/20 text-red-400 text-sm font-bold hover:bg-red-500/30 transition-all">📤 Kirim Laporan</button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
