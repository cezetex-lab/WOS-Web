// SimperPage.jsx — Mining SIMPER (Surat Izin Masuk Pertambangan)
import { useState, useEffect } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, EmptyState, SectionHeader, useToast } from '@/lib/design-system';

const ZONE_COLORS = { 'PIT-1': 'red', 'PIT-2': 'orange', 'PIT-3': 'yellow', 'WORKSHOP': 'blue', 'OFFICE': 'slate', 'CRUSHER': 'purple', 'HAUL ROAD': 'teal' };

export default function SimperPage() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [permits, setPermits] = useState([]);
  const [myPermits, setMyPermits] = useState([]);
  const [tab, setTab] = useState('active');
  const toast = useToast();

  useEffect(() => {
    const u = getSession();
    if (!u) { window.location.href = '/'; return; }
    setUser(u);
    loadData(u.nrp);
  }, []);

  async function loadData(nrp) {
    setLoading(true);
    try {
      const r = await rpc('get_simper_list', { p_nrp: nrp });
      if (r?.ok && r.data) {
        setMyPermits(r.data.filter(p => p.nrp === nrp));
        setPermits(r.data);
      }
    } catch (e) {
      // Seed fallback
      setPermits([
        { id: 'SIM-001', nrp, zone: 'PIT-1', purpose: 'Operasi excavator', status: 'ACTIVE', valid_until: '2026-09-01', issued_by: 'Safety Manager' },
        { id: 'SIM-002', nrp, zone: 'CRUSHER', purpose: 'Maintenance crusher', status: 'ACTIVE', valid_until: '2026-09-15', issued_by: 'Safety Manager' },
        { id: 'SIM-003', nrp, zone: 'WORKSHOP', purpose: 'Perbaikan alat berat', status: 'EXPIRED', valid_until: '2026-08-15', issued_by: 'Safety Manager' },
      ]);
      setMyPermits([
        { id: 'SIM-001', nrp, zone: 'PIT-1', purpose: 'Operasi excavator', status: 'ACTIVE', valid_until: '2026-09-01', issued_by: 'Safety Manager' },
        { id: 'SIM-002', nrp, zone: 'CRUSHER', purpose: 'Maintenance crusher', status: 'ACTIVE', valid_until: '2026-09-15', issued_by: 'Safety Manager' },
      ]);
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat SIMPER..." /></div>;

  const activePermits = permits.filter(p => p.status === 'ACTIVE');
  const expiredPermits = permits.filter(p => p.status !== 'ACTIVE');

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">⛏️ SIMPER</h1>
        <p className="text-xs text-slate-400 mb-4">Surat Izin Masuk Pertambangan</p>

        {/* Stats */}
        <div className="grid grid-cols-3 gap-2 mb-4">
          <GlassCard className="text-center p-3">
            <div className="text-2xl font-bold text-emerald-400">{activePermits.length}</div>
            <div className="text-[10px] text-slate-400">Aktif</div>
          </GlassCard>
          <GlassCard className="text-center p-3">
            <div className="text-2xl font-bold text-red-400">{expiredPermits.length}</div>
            <div className="text-[10px] text-slate-400">Expired</div>
          </GlassCard>
          <GlassCard className="text-center p-3">
            <div className="text-2xl font-bold text-blue-400">{new Set(permits.map(p => p.zone)).size}</div>
            <div className="text-[10px] text-slate-400">Zones</div>
          </GlassCard>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 mb-4">
          {['active', 'expired', 'all'].map(t => (
            <button key={t} onClick={() => setTab(t)} className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${tab === t ? 'bg-teal-500/20 text-teal-400' : 'bg-white/5 text-slate-400 hover:text-white'}`}>
              {t === 'active' ? '✅ Aktif' : t === 'expired' ? '❌ Expired' : '📋 Semua'} ({t === 'active' ? activePermits.length : t === 'expired' ? expiredPermits.length : permits.length})
            </button>
          ))}
        </div>

        {/* Permit List */}
        <div className="space-y-2">
          {(tab === 'active' ? activePermits : tab === 'expired' ? expiredPermits : permits).map((p, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-bold text-white">{p.id}</span>
                  <Badge status={p.status === 'ACTIVE' ? 'Approved' : 'Rejected'} type={p.status === 'ACTIVE' ? 'success' : 'danger'} />
                </div>
                <span className={`px-2 py-0.5 rounded text-[10px] font-bold bg-${ZONE_COLORS[p.zone] || 'slate'}-500/20 text-${ZONE_COLORS[p.zone] || 'slate'}-400`}>
                  {p.zone}
                </span>
              </div>
              <p className="text-xs text-slate-300 mb-1">📌 {p.purpose}</p>
              <div className="flex justify-between text-[10px] text-slate-500">
                <span>Issued: {p.issued_by}</span>
                <span>Valid until: {p.valid_until}</span>
              </div>
            </GlassCard>
          ))}
        </div>

        {permits.length === 0 && <EmptyState icon="⛏️" title="Belum ada SIMPER" subtitle="Ajukan SIMPER baru melalui form di bawah" />}

        {/* Request New SIMPER */}
        <GlassCard title="📝 Ajukan SIMPER Baru" icon="📝" accent="blue" className="mt-4">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-slate-400 mb-1 block">Zona Tujuan</label>
              <select className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option>PIT-1</option><option>PIT-2</option><option>PIT-3</option>
                <option>CRUSHER</option><option>HAUL ROAD</option><option>WORKSHOP</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1 block">Tujuan</label>
              <input className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" placeholder="Contoh: Operasi excavator, Maintenance, dll" />
            </div>
            <button className="w-full py-2 rounded-lg bg-teal-500/20 text-teal-400 text-sm font-bold hover:bg-teal-500/30 transition-all">
              📤 Kirim Permohonan
            </button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
