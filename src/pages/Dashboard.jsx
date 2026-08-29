import { useState, useEffect, useRef } from 'react';
import { rpc, getSession, clearSession } from '@/lib/supabase-browser';
import { BarChart, StatCard, ProgressBar, DonutChart, DarkModeToggle, useToast } from '@/lib/ui-components';
import { AppShell, MenuGrid, NotifList, RingkasanHari, QuickAccess } from '@/lib/app-shell';

function greetingTime() {
  const hour = new Date().getHours();
  if (hour < 6) return 'Selamat malam';
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

export default function DashboardPage() {
  const [user, setUser] = useState(null);
  const [activeTab, setActiveTab] = useState('beranda');
  const [menuDetail, setMenuDetail] = useState(null);
  const [stats, setStats] = useState(null);
  const [health, setHealth] = useState(null);
  const [kpiByDiv, setKpiByDiv] = useState([]);
  const [team, setTeam] = useState([]);
  const [teamRequests, setTeamRequests] = useState([]);
  const [flightRisk, setFlightRisk] = useState([]);
  const [safety, setSafety] = useState(null);
  const [turnover, setTurnover] = useState([]);
  const [actionCenter, setActionCenter] = useState(null);
  const [snapshot, setSnapshot] = useState([]);
  const [execSummary, setExecSummary] = useState(null);
  const [financial, setFinancial] = useState([]);
  const [anomalies, setAnomalies] = useState([]);
  const [teamNarrative, setTeamNarrative] = useState(null);
  const [financialTrend, setFinancialTrend] = useState([]);
  const [earlyWarning, setEarlyWarning] = useState([]);
  const [workforceHealth, setWorkforceHealth] = useState(null);
  const [autoHealing, setAutoHealing] = useState([]);
  const [costPerUnit, setCostPerUnit] = useState(null);
  const [workforcePlanning, setWorkforcePlanning] = useState([]);
  const [treeData, setTreeData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [expandedRow, setExpandedRow] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshY, setRefreshY] = useState(0);
  const pullStartY = useRef(0);
  const toast = useToast();

  function fmt(n) { return n ? "Rp " + Number(n).toLocaleString("id-ID") : "-"; }

  useEffect(() => {
    const u = getSession();
    if (!u) { window.location.href = '/'; return; }
    setUser(u);
    loadData(u.nrp);
  }, []);

  async function loadData(nrp) {
    setLoading(true);
    try {
      const r = await Promise.all([
        rpc('get_dashboard_stats'),
        rpc('get_kpi_by_division'),
        rpc('get_team_data', { p_nrp: nrp }),
        rpc('get_team_requests', { p_nrp: nrp }),
        rpc('get_flight_risk_list'),
        rpc('get_safety_summary'),
        rpc('get_turnover_data'),
        rpc('get_organization_health'),
        rpc('get_action_center'),
        rpc('get_monthly_snapshot_trend'),
        rpc('get_executive_summary'),
        rpc('get_financial_stats'),
        rpc('get_anomaly_details'),
        rpc('get_team_narrative', { p_nrp: nrp }),
        rpc('get_financial_trend'),
        rpc('get_early_warning'),
        rpc('get_workforce_health_score'),
        rpc('get_auto_healing_actions'),
        rpc('get_cost_per_unit'),
        rpc('get_workforce_planning'),
        rpc('get_subtree_data', { p_nrp: nrp })
      ]);
      const [s, k, t, tr, fr, sf, to, oh, ac, ss, es, fin, anom, tn, fTrend, ew, wHealth, aHeal, cpu, wp, tree] = r;
      if(fTrend.ok&&fTrend.data)setFinancialTrend(fTrend.data);
      if(ew.ok&&ew.data)setEarlyWarning(ew.data);
      if(wHealth.ok)setWorkforceHealth(wHealth);
      if(aHeal.ok&&aHeal.data)setAutoHealing(aHeal.data);
      if(cpu.ok)setCostPerUnit(cpu);
      if(wp.ok&&wp.data)setWorkforcePlanning(wp.data);
      if(tree.ok&&tree.data)setTreeData(tree.data);
      if (s.ok) setStats(s);
      if (k.ok && k.data) setKpiByDiv(k.data);
      if (t.ok && t.data) setTeam(t.data);
      if (tr.ok && tr.data) setTeamRequests(tr.data);
      if (fr.ok && fr.data) setFlightRisk(fr.data);
      if (sf.ok) setSafety(sf);
      if (to.ok && to.data) setTurnover(to.data);
      if (oh.ok) setHealth(oh);
      if (ac.ok) setActionCenter(ac);
      if (ss.ok && ss.data) setSnapshot(ss.data);
      if (es.ok) setExecSummary(es);
      if (fin.ok && fin.data) setFinancial(fin.data);
      if (anom.ok && anom.data) setAnomalies(anom.data);
      if (tn.ok) setTeamNarrative(tn);
    } catch (e) { console.error(e); }
    setLoading(false);
  }

  function onTouchStart(e) { pullStartY.current = e.touches[0].clientY; }
  function onTouchMove(e) {
    const dy = e.touches[0].clientY - pullStartY.current;
    if (dy > 0 && dy < 150) setRefreshY(dy);
  }
  async function onTouchEnd() {
    if (refreshY > 80) {
      setRefreshing(true);
      await loadData(user?.nrp);
      setRefreshing(false);
      toast.success('Data diperbarui');
    }
    setRefreshY(0);
  }

  async function handleRequestAction(id, status) {
    setActionLoading(id);
    try {
      await rpc('approve_team_request', { p_id: id, p_status: status, p_note: status });
      setTeamRequests(teamRequests.filter(r => r.id !== id));
      toast.success('Request ' + status);
    } catch (e) { toast.error('Gagal memproses request'); }
    setActionLoading(null);
  }

  function logout() { clearSession(); window.location.href = '/'; }

  const S = {
    wrap: { minHeight:'100vh', background:'#0f172a', fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif', color:'#e2e8f0', paddingBottom:'70px' },
    header: { background:'linear-gradient(135deg,#1e3a5f,#0f172a)', padding:'16px', borderBottom:'1px solid #1e293b' },
    greeting: { fontSize:'20px', fontWeight:'700', margin:'0 0 4px 0' },
    meta: { fontSize:'13px', color:'#94a3b8' },
    content: { padding:'16px', maxWidth:'480px', margin:'0 auto' },
    card: { background:'#1e293b', borderRadius:'12px', padding:'16px', marginBottom:'12px', border:'1px solid #334155' },
    cardTitle: { fontSize:'14px', fontWeight:'700', marginBottom:'12px', color:'#e2e8f0' },
    statGrid3: { display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:'12px', textAlign:'center' },
    statItem: { padding:'8px 0' },
    statGrid: { display:'grid', gridTemplateColumns:'1fr 1fr', gap:'8px' },
    metricItem: { minWidth:'100px', background:'#0f172a', borderRadius:'8px', padding:'12px', textAlign:'center', border:'1px solid #334155', flexShrink:0 },
    metricVal: { fontSize:'24px', fontWeight:'700', color:'#38bdf8' },
    metricLabel: { fontSize:'11px', color:'#94a3b8', marginTop:'4px' },
    list: { listStyle:'none', padding:0, margin:0 },
    listItem: { padding:'10px 0', borderBottom:'1px solid #334155', fontSize:'13px' },
    badge: (s) => ({ display:'inline-block', padding:'2px 8px', borderRadius:'12px', fontSize:'11px', fontWeight:'600',
      background: s==='Approved'||s==='APPROVED'||s==='COMPLETED'?'#065f46':s==='Rejected'||s==='REJECTED'?'#7f1d1d':s==='Pending'||s==='PENDING'||s==='REQUESTED'?'#78350f':s==='IN_PROGRESS'?'#1e3a5f':'#334155',
      color: s==='Approved'||s==='APPROVED'||s==='COMPLETED'?'#34d399':s==='Rejected'||s==='REJECTED'?'#fca5a5':s==='Pending'||s==='PENDING'||s==='REQUESTED'?'#fbbf24':s==='IN_PROGRESS'?'#38bdf8':'#94a3b8'
    }),
    empty: { textAlign:'center', padding:'32px', color:'#64748b', fontSize:'13px' },
  };

  const menuCategories = [
    { title: 'Saya', items: [
      { icon: '\u{1F464}', label: 'Profil Saya', color:'#3b82f6', onClick:()=>setMenuDetail('profile') },
      { icon: '\u{1F465}', label: 'Tim Saya', color:'#10b981', onClick:()=>setMenuDetail('team') },
      { icon: '\u{1F333}', label: 'Struktur Org', color:'#8b5cf6', onClick:()=>setMenuDetail('tree') }
    ]},
    { title: 'Analytics', items: [
      { icon: '\u{1F4C8}', label: 'KPI Divisi', color:'#06b6d4', onClick:()=>setMenuDetail('kpi') },
      { icon: '\u{1F4CA}', label: 'Snapshot', color:'#f59e0b', onClick:()=>setMenuDetail('snapshot') },
      { icon: '\u{1F4B0}', label: 'Keuangan', color:'#10b981', onClick:()=>setMenuDetail('financial') },
      { icon: '\u26A0\uFE0F', label: 'Flight Risk', color:'#ef4444', onClick:()=>setMenuDetail('flight') },
      { icon: '\u{1F504}', label: 'Turnover', color:'#8b5cf6', onClick:()=>setMenuDetail('turnover') }
    ]},
    { title: 'Eksekutif', items: [
      { icon: '\u{1F3E2}', label: 'Exec Summary', color:'#3b82f6', onClick:()=>setMenuDetail('exec') },
      { icon: '\u{1F3D7}\uFE0F', label: 'Health Score', color:'#10b981', onClick:()=>setMenuDetail('health') },
      { icon: '\u26A0\uFE0F', label: 'Early Warning', color:'#ef4444', onClick:()=>setMenuDetail('warning') },
      { icon: '\u{1F916}', label: 'Auto-Healing', color:'#8b5cf6', onClick:()=>setMenuDetail('autoheal') },
      { icon: '\u{1F4CB}', label: 'Planning', color:'#06b6d4', onClick:()=>setMenuDetail('planning') }
    ]}
  ];

  const quickItems = [
    { icon: '\u{1F465}', label: 'Tim', color:'#10b981', onClick:()=>setMenuDetail('team') },
    { icon: '\u{1F4C8}', label: 'KPI', color:'#06b6d4', onClick:()=>setMenuDetail('kpi') },
    { icon: '\u26A0\uFE0F', label: 'Flight Risk', color:'#ef4444', onClick:()=>setMenuDetail('flight') },
    { icon: '\u{1F3E2}', label: 'Exec Summary', color:'#3b82f6', onClick:()=>setMenuDetail('exec') },
    { icon: '\u{1F4B0}', label: 'Keuangan', color:'#10b981', onClick:()=>setMenuDetail('financial') },
    { icon: '\u{1F333}', label: 'Org Tree', color:'#8b5cf6', onClick:()=>setMenuDetail('tree') }
  ];

  const pendingItems = (teamRequests || []).filter(r => r.status === 'Pending' || r.status === 'PENDING').map(r => ({
    title: r.type + ' - ' + (r.nrp||''), detail: r.note || '', time: r.created_at || '', ...r
  }));

  const berandaContent = (
    <>
      <RingkasanHari stats={[
        { label:'Kehadiran', value:(stats?.attendance_rate||98)+'%', color:'#fff' },
        { label:'KPI Avg', value:(stats?.avg_kpi||0), color:'#fff' },
        { label:'Tim', value:team.length, color:'#fff' },
        { label:'Pending', value:pendingItems.length, color:'#fff' }
      ]} />
      <QuickAccess items={quickItems} />
      {teamNarrative && teamNarrative.narrative && (
        <div style={S.card}><div style={S.cardTitle}>{'\u{1F4A1}'} Insight Tim</div>
          <div style={{fontSize:'13px',lineHeight:'1.5'}}>{teamNarrative.narrative}</div></div>
      )}
      {execSummary && (
        <div style={S.card}><div style={S.cardTitle}>{'\u{1F3E2}'} Executive Summary</div>
          <div style={S.statGrid3}>
            <div style={S.statItem}><div style={{fontSize:'20px',fontWeight:'700',color:'#38bdf8'}}>{execSummary.headcount||0}</div><div style={{fontSize:'10px',color:'#94a3b8'}}>Headcount</div></div>
            <div style={S.statItem}><div style={{fontSize:'20px',fontWeight:'700',color:'#34d399'}}>{execSummary.avg_kpi||0}</div><div style={{fontSize:'10px',color:'#94a3b8'}}>Avg KPI</div></div>
            <div style={S.statItem}><div style={{fontSize:'20px',fontWeight:'700',color:'#f59e0b'}}>{execSummary.turnover_rate||0}%</div><div style={{fontSize:'10px',color:'#94a3b8'}}>Turnover</div></div>
          </div></div>
      )}
      {earlyWarning.length > 0 && (
        <div style={S.card}><div style={S.cardTitle}>{'\u26A0\uFE0F'} Early Warnings ({earlyWarning.length})</div>
          {earlyWarning.slice(0,3).map((w,i) => (
            <div key={i} style={{padding:'8px 0',borderBottom:'1px solid #334155',fontSize:'12px'}}>
              <span style={{fontWeight:'600'}}>{w.nrp||''}</span> - {w.title||w.message||''}
            </div>
          ))}</div>
      )}
    </>
  );

  const menuContent = (q) => <MenuGrid categories={menuCategories} searchQuery={q} />;

  const notifContent = (
    <NotifList notifications={[]} pendingItems={pendingItems} />
  );

  if (menuDetail) {
    return (
      <div style={{minHeight:'100vh',background:'#0f172a',color:'#e2e8f0',padding:'16px',maxWidth:'480px',margin:'0 auto'}}>
        <button onClick={()=>setMenuDetail(null)} style={{background:'none',border:'none',color:'#38bdf8',fontSize:'14px',cursor:'pointer',marginBottom:'16px'}}>{'\u2190'} Kembali ke Menu</button>
        <div style={{fontSize:'18px',fontWeight:'700',marginBottom:'16px'}}>{menuDetail}</div>
        <div style={{textAlign:'center',color:'#64748b',padding:'32px'}}>Detail view coming soon...</div>
      </div>
    );
  }

  return (
    <AppShell
      user={user || {}}
      greeting={greetingTime()}
      notifCount={pendingItems.length}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onLogout={logout}
      beranda={activeTab === 'beranda' ? berandaContent : null}
      menu={activeTab === 'menu' ? menuContent : null}
      notifikasi={activeTab === 'notifikasi' ? notifContent : null}
    />
  );
}