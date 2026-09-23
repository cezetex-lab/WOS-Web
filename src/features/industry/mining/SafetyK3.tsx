// SafetyK3.tsx — Mining Safety K3 (Keselamatan & Kesehatan Kerja)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function SafetyK3() {
  const [loading, setLoading] = useState(true);
  const [incidents, setIncidents] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [formType, setFormType] = useState('INCIDENT');
  const [formDesc, setFormDesc] = useState('');
  const [formZone, setFormZone] = useState('PIT-1');
  const [formSeverity, setFormSeverity] = useState('MEDIUM');
  const [submitting, setSubmitting] = useState(false);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_safety_incidents');
      if (r?.ok && r.data) { setIncidents(r.data); setStats(r.summary); }
    } catch (e) {
      setIncidents([]);
    }
    setLoading(false);
  }

  async function handleSubmit() {
    if (!formDesc.trim()) {
      toast.error('Deskripsi wajib diisi');
      return;
    }
    setSubmitting(true);
    try {
      const r = await rpc('report_safety_incident', {
        p_type: formType,
        p_zone: formZone,
        p_desc: formDesc,
        p_severity: formSeverity,
      });
      if (r?.ok) {
        toast.success(r.msg || 'Laporan terkirim');
        setFormDesc('');
        loadData();
      } else {
        toast.error(r?.msg || 'Gagal mengirim laporan');
      }
    } catch (e) {
      toast.error('Gagal mengirim laporan');
    }
    setSubmitting(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data safety..." /></div>;

  const sevColor: Record<string, string> = { LOW: 'info', MEDIUM: 'warning', HIGH: 'danger' };
  const typeIcon: Record<string, string> = { INCIDENT: '🔴', NEAR_MISS: '🟡', OBSERVATION: '🔵' };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🛡️ Safety K3</h1>
        <p className="text-xs text-slate-400 mb-4">Incident reporting & near-miss tracking</p>

        {stats && (
          <div className="grid grid-cols-3 gap-2 mb-4">
            <GlassCard className="text-center p-3"><div className="text-xl font-bold text-emerald-400">{stats.lti || 0}</div><div className="text-[11px] text-slate-400">LTI (Lost Time)</div></GlassCard>
            <GlassCard className="text-center p-3"><div className="text-xl font-bold text-blue-400">{stats.total || incidents.length}</div><div className="text-[11px] text-slate-400">Total Reports</div></GlassCard>
            <GlassCard className="text-center p-3"><div className="text-xl font-bold text-amber-400">{stats.open || 0}</div><div className="text-[11px] text-slate-400">Open Cases</div></GlassCard>
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

        {/* Report Form */}
        <GlassCard title="📝 Laporkan Insiden" icon="📝" accent="red" className="mt-4">
          <div className="space-y-3">
            <select aria-label="Jenis laporan insiden" value={formType} onChange={e => setFormType(e.target.value)} className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
              <option value="INCIDENT">🔴 Incident (Ada cedera)</option>
              <option value="NEAR_MISS">🟡 Near Miss (Hampir terjadi)</option>
              <option value="OBSERVATION">🔵 Observation (Observasi)</option>
            </select>
            <div className="grid grid-cols-2 gap-2">
              <select aria-label="Zona lokasi" value={formZone} onChange={e => setFormZone(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option>PIT-1</option><option>PIT-2</option><option>PIT-3</option><option>CRUSHER</option><option>HAUL ROAD</option><option>WORKSHOP</option>
              </select>
              <select aria-label="Tingkat keparahan" value={formSeverity} onChange={e => setFormSeverity(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option value="LOW">LOW</option><option value="MEDIUM">MEDIUM</option><option value="HIGH">HIGH</option><option value="CRITICAL">CRITICAL</option>
              </select>
            </div>
            <textarea value={formDesc} onChange={e => setFormDesc(e.target.value)} className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white h-20" placeholder="Deskripsi kejadian..." />
            <button onClick={handleSubmit} disabled={submitting} className="w-full py-2 rounded-lg bg-red-500/20 text-red-400 text-sm font-bold hover:bg-red-500/30 transition-all disabled:opacity-50">
              {submitting ? '⏳ Mengirim...' : '📤 Kirim Laporan'}
            </button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
