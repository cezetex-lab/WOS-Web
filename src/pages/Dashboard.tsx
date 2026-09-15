import { useState, useEffect, useRef } from 'react';
import { rpc, getSession, clearSession, signOutAuth } from '@/lib/supabase-browser';
import { MetricCard, GlassCard, QuickTile, Badge, ActionItem, EmptyState, LoadingSpinner, Avatar, SectionHeader, useToast } from '@/lib/design-system';
import { createPageErrorLogger } from '@/lib/log-error';
import { UserSession } from '@/types';

const logError = createPageErrorLogger('Dashboard');

function greetingTime() {
  const h = new Date().getHours();
  if (h < 6) return 'Selamat malam'; if (h < 11) return 'Selamat pagi'; if (h < 15) return 'Selamat siang'; if (h < 18) return 'Selamat sore'; return 'Selamat malam';
}

const MENU_CATEGORIES = [
  { title: 'Saya', items: [{ icon: '👤', label: 'Profil Saya', color: 'blue', detail: 'profile' }, { icon: '👥', label: 'Tim Saya', color: 'green', detail: 'team' }, { icon: '🌳', label: 'Struktur Org', color: 'purple', detail: 'tree' }] },
  { title: 'Analytics', items: [{ icon: '📈', label: 'KPI Divisi', color: 'teal', detail: 'kpi' }, { icon: '📊', label: 'Snapshot', color: 'orange', detail: 'snapshot' }, { icon: '💰', label: 'Keuangan', color: 'green', detail: 'financial' }, { icon: '⚠️', label: 'Flight Risk', color: 'red', detail: 'flight' }, { icon: '🔄', label: 'Turnover', color: 'purple', detail: 'turnover' }] },
  { title: 'Eksekutif', items: [{ icon: '🏢', label: 'Exec Summary', color: 'blue', detail: 'exec' }, { icon: '🏗️', label: 'Health Score', color: 'green', detail: 'health' }, { icon: '⚠️', label: 'Early Warning', color: 'red', detail: 'warning' }, { icon: '🤖', label: 'Auto-Healing', color: 'purple', detail: 'autoheal' }, { icon: '📋', label: 'Planning', color: 'teal', detail: 'planning' }] },
];

interface DashboardStatsData {
  attendance_rate?: number;
  avg_kpi?: number;
  ok?: boolean;
}

interface TeamData {
  id?: string;
  [key: string]: unknown;
}

interface RequestData {
  id: string;
  status: string;
  type?: string;
  nrp?: string;
  note?: string;
  created_at?: string;
}

interface ExecSummary {
  headcount?: number;
  avg_kpi?: number;
  turnover_rate?: number;
  ok?: boolean;
}

interface NarrativeData {
  narrative?: string;
  ok?: boolean;
}

interface WarningData {
  nrp?: string;
  title?: string;
  message?: string;
  ok?: boolean;
}

export default function DashboardPage() {
  const toast = useToast();
  const [user, setUser] = useState<UserSession | null>(null);
  const [noAccess, setNoAccess] = useState(false);
  const [activeTab, setActiveTab] = useState('beranda');
  const [menuDetail, setMenuDetail] = useState<string | null>(null);
  const [menuSearch, setMenuSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<DashboardStatsData | null>(null);
  const [team, setTeam] = useState<TeamData[]>([]);
  const [teamRequests, setTeamRequests] = useState<RequestData[]>([]);
  const [execSummary, setExecSummary] = useState<ExecSummary | null>(null);
  const [teamNarrative, setTeamNarrative] = useState<NarrativeData | null>(null);
  const [earlyWarning, setEarlyWarning] = useState<WarningData[]>([]);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshY, setRefreshY] = useState(0);
  const pullStartY = useRef(0);

  useEffect(() => {
    const u = getSession();
    if (!u) { window.location.href = '/'; return; }
    if (u.entry && u.entry !== 'dashboard' && u.role !== 'owner') {
      console.warn('[Dashboard] Session entry mismatch:', u.entry, '→ login ulang');
      window.location.href = '/';
      return;
    }
    if (u.role === 'worker') { setNoAccess(true); setLoading(false); return; }
    setUser(u); loadData(u.nrp as string);
  }, []);

  function toArray<T>(val: unknown): T[] {
    if (Array.isArray(val)) return val as T[];
    return [];
  }

  async function loadData(nrp: string) {
    setLoading(true);
    try {
      const r = await Promise.all([
        rpc<{ data?: DashboardStatsData }>('get_dashboard_stats'), 
        rpc<{ data?: TeamData[] }>('get_team_data', { p_nrp: nrp }), 
        rpc<{ data?: RequestData[] }>('get_team_requests', { p_nrp: nrp }), 
        rpc<{ data?: ExecSummary }>('get_executive_summary'), 
        rpc<{ data?: NarrativeData }>('get_team_narrative', { p_nrp: nrp }), 
        rpc<{ data?: WarningData[] }>('get_early_warning')
      ]);
      const [s, t, tr, es, tn, ew] = r;
      
      const sr = s as { ok?: boolean; data?: DashboardStatsData } | null;
      if (sr?.ok && sr.data) setStats(sr.data);
      else if (sr?.ok) setStats(sr as unknown as DashboardStatsData);

      const trr = t as { ok?: boolean; data?: TeamData[] } | null;
      if (trr?.ok && trr.data) setTeam(toArray<TeamData>(trr.data));

      const trd = tr as { ok?: boolean; data?: RequestData[] } | null;
      if (trd?.ok && trd.data) setTeamRequests(toArray<RequestData>(trd.data));

      const er = es as { ok?: boolean; data?: ExecSummary } | null;
      if (er?.ok && er.data) setExecSummary(er.data);
      else if (er?.ok) setExecSummary(er as unknown as ExecSummary);

      const tnr = tn as { ok?: boolean; data?: NarrativeData } | null;
      if (tnr?.ok && tnr.data) setTeamNarrative(tnr.data);
      else if (tnr?.ok) setTeamNarrative(tnr as unknown as NarrativeData);

      const ewr = ew as { ok?: boolean; data?: WarningData[] } | null;
      if (ewr?.ok && ewr.data) setEarlyWarning(toArray<WarningData>(ewr.data));
    } catch (e) { logError('loadData', e); }
    setLoading(false);
  }

  function onTouchStart(e: React.TouchEvent) { pullStartY.current = e.touches[0].clientY; }
  function onTouchMove(e: React.TouchEvent) { const dy = e.touches[0].clientY - pullStartY.current; if (dy > 0 && dy < 150) setRefreshY(dy); }
  async function onTouchEnd() { if (refreshY > 80) { setRefreshing(true); await loadData((user?.nrp as string) || ''); setRefreshing(false); toast.success('Data diperbarui'); } setRefreshY(0); }

  async function handleRequestAction(id: string, status: string) {
    setActionLoading(id);
    try { await rpc('approve_team_request', { p_id: id, p_status: status, p_note: status }); setTeamRequests(teamRequests.filter(r => r.id !== id)); toast.success('Request ' + status); } catch (e) { logError('handleRequestAction', e); toast.error('Gagal memproses request'); }
    setActionLoading(null);
  }

  async function logout() { clearSession(); try { await signOutAuth(); } catch(e) {} window.location.href = '/'; }
  const pendingItems = (teamRequests || []).filter(r => r.status === 'Pending' || r.status === 'PENDING');

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat dashboard..." /></div>;

  // Role worker tidak punya akses dashboard — arahkan login ulang via tab dashboard.
  if (noAccess) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><div className="text-center max-w-sm px-6"><p className="text-4xl mb-4">🔒</p><p className="text-white text-lg font-bold mb-2">Akses Dashboard Ditolak</p><p className="text-slate-400 text-sm mb-6">Akun worker tidak punya akses dashboard. Silakan login ulang via tab Dashboard.</p><button onClick={logout} className="px-6 py-3 bg-teal-500 hover:bg-teal-600 text-white font-semibold rounded-xl transition-all">Kembali ke Login</button></div></div>;

  if (menuDetail) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900"><div className="max-w-7xl mx-auto px-4 py-4 pb-24"><button onClick={() => setMenuDetail(null)} className="text-teal-400 text-sm font-semibold mb-4 hover:text-teal-300 transition-colors">← Kembali ke Menu</button><GlassCard title={menuDetail.charAt(0).toUpperCase() + menuDetail.slice(1)} icon="📄" accent="blue"><EmptyState icon="🚧" title="Halaman dalam pengembangan" subtitle={`Detail ${menuDetail} segera tersedia`} /></GlassCard></div></div>;

  const berandaContent = (<>
    {refreshY > 0 && <div className="text-center py-2 text-xs text-slate-400">{refreshing ? '🔄 Memperbarui...' : refreshY > 80 ? '↓ Lepas untuk refresh' : '↓ Tarik ke bawah'}</div>}
    <GlassCard title="Ringkasan Hari Ini" icon="📊" accent="blue" className="mb-4">
      <div className="grid grid-cols-4 gap-2">
        {[{ l: 'Kehadiran', v: (stats?.attendance_rate || 98) + '%' }, { l: 'KPI Avg', v: stats?.avg_kpi || 0 }, { l: 'Tim', v: team.length }, { l: 'Pending', v: pendingItems.length }].map((s, i) => <div key={i} className="text-center p-2 bg-white/5 rounded-xl"><div className="text-lg font-bold text-white">{s.v}</div><div className="text-[11px] text-slate-400">{s.l}</div></div>)}
      </div>
    </GlassCard>
    <SectionHeader title="Quick Access" />
    <div className="grid grid-cols-3 gap-2 mb-4">
      {[{ icon: '👥', label: 'Tim', color: 'green' as const, d: 'team' }, { icon: '📈', label: 'KPI', color: 'teal' as const, d: 'kpi' }, { icon: '⚠️', label: 'Flight Risk', color: 'red' as const, d: 'flight' }, { icon: '🏢', label: 'Exec Summary', color: 'blue' as const, d: 'exec' }, { icon: '💰', label: 'Keuangan', color: 'green' as const, d: 'financial' }, { icon: '🌳', label: 'Org Tree', color: 'purple' as const, d: 'tree' }].map((item, i) => <QuickTile key={i} icon={item.icon} label={item.label} color={item.color} onClick={() => setMenuDetail(item.d)} />)}
    </div>
    {teamNarrative?.narrative && <GlassCard title="💡 Insight Tim" accent="teal" className="mb-4"><p className="text-sm text-slate-300 leading-relaxed">{teamNarrative.narrative}</p></GlassCard>}
    {execSummary && <GlassCard title="🏢 Executive Summary" accent="blue" className="mb-4"><div className="grid grid-cols-3 gap-3 text-center"><div><div className="text-xl font-bold text-blue-400">{execSummary.headcount || 0}</div><div className="text-[11px] text-slate-400">Headcount</div></div><div><div className="text-xl font-bold text-emerald-400">{execSummary.avg_kpi || 0}</div><div className="text-[11px] text-slate-400">Avg KPI</div></div><div><div className="text-xl font-bold text-amber-400">{execSummary.turnover_rate || 0}%</div><div className="text-[11px] text-slate-400">Turnover</div></div></div></GlassCard>}
    {earlyWarning.length > 0 && <GlassCard title={`⚠️ Early Warnings (${earlyWarning.length})`} accent="red" className="mb-4"><div className="space-y-1">{earlyWarning.slice(0, 3).map((w, i) => <div key={i} className="flex items-center gap-2 py-2 border-b border-white/5 last:border-0"><span className="text-xs font-bold text-white">{w.nrp || ''}</span><span className="text-xs text-slate-400">— {w.title || w.message || ''}</span></div>)}</div></GlassCard>}
    {pendingItems.length > 0 && <GlassCard title={`📋 Perlu Tindakan (${pendingItems.length})`} accent="orange" className="mb-4"><div className="space-y-2">{pendingItems.slice(0, 5).map((req, i) => <div key={i} className="flex items-center justify-between p-2 bg-slate-900/40 rounded-xl border border-white/5"><div className="flex-1 min-w-0"><div className="flex items-center gap-2"><span className="text-xs font-semibold text-white">{req.type || '-'}</span><Badge status="Pending" type="warning" /></div><p className="text-[11px] text-slate-400 truncate mt-0.5">{req.nrp || ''} • {req.note || ''}</p></div><div className="flex gap-1 ml-2"><button onClick={() => handleRequestAction(req.id, 'Approved')} disabled={actionLoading === req.id} className="px-2 py-1 rounded-lg text-[11px] font-bold bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30 transition-all disabled:opacity-40">✓</button><button onClick={() => handleRequestAction(req.id, 'Rejected')} disabled={actionLoading === req.id} className="px-2 py-1 rounded-lg text-[11px] font-bold bg-red-500/20 text-red-400 hover:bg-red-500/30 transition-all disabled:opacity-40">✕</button></div></div>)}</div></GlassCard>}
  </>);

  const menuContent = (<>
    <div className="flex items-center gap-2 bg-slate-800/50 rounded-xl px-3 py-2.5 border border-white/5 mb-4">
      <svg className="w-4 h-4 text-slate-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
      <input type="text" placeholder="Cari menu atau fitur..." value={menuSearch} onChange={e => setMenuSearch(e.target.value)} className="flex-1 bg-transparent text-sm text-white placeholder-slate-500 outline-none" />
      {menuSearch && <button onClick={() => setMenuSearch('')} className="text-slate-500 hover:text-white text-xs">✕</button>}
    </div>
    {MENU_CATEGORIES.map(cat => { const f = cat.items.filter(item => !menuSearch || item.label.toLowerCase().includes(menuSearch.toLowerCase())); if (f.length === 0) return null; return <div key={cat.title} className="mb-4"><SectionHeader title={cat.title} /><div className="grid grid-cols-4 gap-2">{f.map((item, i) => <QuickTile key={i} icon={item.icon} label={item.label} color={item.color as 'blue' | 'teal' | 'orange' | 'red' | 'purple' | 'green' | 'slate'} onClick={() => setMenuDetail(item.detail)} />)}</div></div>; })}
  </>);

  const notifContent = (<>
    {pendingItems.length > 0 && <><SectionHeader title={`⚡ Perlu Tindakan (${pendingItems.length})`} /><div className="space-y-2 mb-4">{pendingItems.map((item, i) => <ActionItem key={i} title={`${item.type || '-'} — ${item.nrp || ''}`} subtitle={item.note || ''} date={item.created_at} badge="Pending" badgeType="warning" />)}</div></>}
    <SectionHeader title="Notifikasi" icon="🔔" />
    <EmptyState icon="📭" title="Tidak ada notifikasi baru" />
  </>);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900" onTouchStart={onTouchStart} onTouchMove={onTouchMove} onTouchEnd={onTouchEnd}>
      <div className="sticky top-0 z-30 backdrop-blur-xl bg-slate-900/80 border-b border-white/5">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3"><Avatar name={user?.nama} size="md" /><div><div className="text-xs text-slate-400">{greetingTime()}</div><div className="text-sm font-bold text-white">{user?.nama || 'User'}</div></div></div>
          <div className="flex items-center gap-2">
            <button onClick={() => setActiveTab('notifikasi')} className="relative flex items-center justify-center w-9 h-9 rounded-xl bg-slate-800/50 border border-white/5 text-slate-400 hover:text-white transition-all">🔔{pendingItems.length > 0 && <span className="absolute -top-1 -right-1 min-w-[16px] h-4 flex items-center justify-center bg-red-500 text-white text-[11px] font-bold rounded-full px-1">{pendingItems.length > 9 ? '9+' : pendingItems.length}</span>}</button>
            <button onClick={logout} className="flex items-center justify-center w-9 h-9 rounded-xl bg-slate-800/50 border border-white/5 text-red-400 hover:text-red-300 transition-all" title="Logout">🚪</button>
          </div>
        </div>
      </div>
      <div className="max-w-7xl mx-auto px-4 py-4 pb-24">
        {activeTab === 'beranda' && berandaContent}
        {activeTab === 'menu' && menuContent}
        {activeTab === 'notifikasi' && notifContent}
      </div>
      <div className="fixed bottom-0 left-0 right-0 z-40 bg-slate-900/90 backdrop-blur-xl border-t border-white/10">
        <div className="max-w-7xl mx-auto flex items-center justify-around h-16">
          {[{ id: 'beranda', icon: '🏠', label: 'Beranda', badge: 0 }, { id: 'menu', icon: '📋', label: 'Menu', badge: 0 }, { id: 'notifikasi', icon: '🔔', label: 'Notifikasi', badge: pendingItems.length }].map(tab => (
            <button key={tab.id} onClick={() => setActiveTab(tab.id)} className={`flex flex-col items-center justify-center w-16 h-14 rounded-2xl transition-all ${activeTab === tab.id ? 'text-teal-400 bg-teal-400/10' : 'text-slate-400 hover:text-white'}`}>
              <span className="text-xl relative">{tab.icon}{tab.badge > 0 && <span className="absolute -top-1 -right-2 min-w-[14px] h-3.5 flex items-center justify-center bg-red-500 text-white text-[8px] font-bold rounded-full px-0.5">{tab.badge > 9 ? '9+' : tab.badge}</span>}</span>
              <span className="text-[11px] font-medium mt-0.5">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
