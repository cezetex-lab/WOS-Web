import { useState, useEffect, useRef } from 'react';
import { rpc, getSession, clearSession } from '@/lib/supabase-browser';
import { BarChart, StatCard, DarkModeToggle, useToast } from '@/lib/ui-components';
import { AppShell, MenuGrid, NotifList, RingkasanHari, QuickAccess } from '@/lib/app-shell';

const SHORT_NAMES = {
  'OPERATIONAL': 'Ops', 'OPERATION': 'Ops', 'PRODUCTION': 'Prod',
  'INFORMATION TECHNOLOGY / IT': 'IT', 'IT': 'IT', 'TECHNOLOGY': 'Tech',
  'FINANCE': 'Fin', 'FINANCE & ACCOUNTING': 'Fin',
  'HRD': 'HRD', 'HUMAN RESOURCES': 'HRD', 'HR': 'HRD',
  'MARKETING': 'Mkt', 'SALES': 'Sales', 'LOGISTIC': 'Log',
  'LEGAL': 'Legal', 'GA': 'GA', 'GENERAL AFFAIRS': 'GA',
};
function shortDiv(name) {
  return SHORT_NAMES[name?.toUpperCase()] || (name?.length > 6 ? name.substring(0, 5) + '.' : name);
}

function greetingTime() {
  const hour = new Date().getHours();
  if (hour < 6) return 'Selamat malam';
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

export default function AdminClient() {
  const [user, setUser] = useState(null);
  const [activeTab, setActiveTab] = useState('beranda');
  const [menuDetail, setMenuDetail] = useState(null);
  const [summary, setSummary] = useState(null);
  const [pending, setPending] = useState([]);
  const [pendingRequests, setPendingRequests] = useState([]);
  const [auditLog, setAuditLog] = useState([]);
  const [divisions, setDivisions] = useState([]);
  const [orgStructure, setOrgStructure] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [expandedDiv, setExpandedDiv] = useState(null);
  const [trainingCatalog, setTrainingCatalog] = useState([]);
  const [kpiConfig, setKpiConfig] = useState([]);
  const [coachingCatalog, setCoachingCatalog] = useState([]);
  const [complianceCatalog, setComplianceCatalog] = useState([]);
  const [benefitCatalog, setBenefitCatalog] = useState([]);
  const [pendingTab, setPendingTab] = useState('daftar');
  const [refreshing, setRefreshing] = useState(false);
  const [refreshY, setRefreshY] = useState(0);
  const pullStartY = useRef(0);
  const toast = useToast();

  function fmt(n) { return n ? "Rp " + Number(n).toLocaleString("id-ID") : "-"; }

  useEffect(() => {
    const u = getSession();
    if (!u || u.role !== 'admin') { window.location.href = '/'; return; }
    setUser(u);
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await Promise.all([
        rpc('admin_get_summary'),
        rpc('admin_get_pending'),
        rpc('admin_get_pending_requests'),
        rpc('admin_get_audit_log'),
        rpc('admin_get_divisions'),
        rpc('admin_get_org_structure'),
        rpc('get_training_catalog'),
        rpc('get_kpi_config_all'),
        rpc('get_coaching_catalog'),
        rpc('get_compliance_catalog'),
        rpc('get_benefit_catalog')
      ]);
      const [s, p, pr, a, d, o, tCat, kCfg, cCat, coCat, bCat] = r;
      if(tCat.ok&&tCat.data)setTrainingCatalog(tCat.data);
      if(kCfg.ok&&kCfg.data)setKpiConfig(kCfg.data);
      if(cCat.ok&&cCat.data)setCoachingCatalog(cCat.data);
      if(coCat.ok&&coCat.data)setComplianceCatalog(coCat.data);
      if(bCat.ok&&bCat.data)setBenefitCatalog(bCat.data);
      if (s.ok) setSummary(s);
      if (p.ok && p.data) setPending(p.data);
      if (pr.ok && pr.data) setPendingRequests(pr.data);
      if (a.ok && a.data) setAuditLog(a.data);
      if (d.ok && d.data) setDivisions(d.data);
      if (o.ok && o.data) setOrgStructure(o.data);
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
      await loadData();
      setRefreshing(false);
      toast.success('Data diperbarui');
    }
    setRefreshY(0);
  }

  async function approvePending(id) {
    setActionLoading(id);
    try {
      const d = await rpc('admin_approve_pending', { p_id: id });
      if (d.ok) { setPending(pending.filter(x => x.id !== id)); toast.success('Pendaftaran disetujui'); }
      else toast.error(d.msg || 'Gagal menyetujui');
    } catch (e) { toast.error('Error: ' + e.message); }
    setActionLoading(null);
  }

  async function rejectPending(id) {
    const reason = prompt('Alasan penolakan:');
    if (!reason) return;
    setActionLoading(id);
    try {
      const d = await rpc('admin_reject_pending', { p_id: id, p_reason: reason });
      if (d.ok) { setPending(pending.filter(x => x.id !== id)); toast.info('Pendaftaran ditolak'); }
      else toast.error(d.msg || 'Gagal menolak');
    } catch (e) { toast.error('Error: ' + e.message); }
    setActionLoading(null);
  }

  async function approveRequest(id) {
    setActionLoading(id);
    try {
      const d = await rpc('admin_approve_request', { p_id: id });
      if (d.ok) { setPendingRequests(pendingRequests.filter(x => x.id !== id)); toast.success('Request disetujui'); }
      else toast.error(d.msg || 'Gagal');
    } catch (e) { toast.error('Error: ' + e.message); }
    setActionLoading(null);
  }

  async function rejectRequest(id) {
    const reason = prompt('Alasan penolakan:');
    if (!reason) return;
    setActionLoading(id);
    try {
      const d = await rpc('admin_reject_request', { p_id: id, p_reason: reason });
      if (d.ok) { setPendingRequests(pendingRequests.filter(x => x.id !== id)); toast.info('Request ditolak'); }
      else toast.error(d.msg || 'Gagal');
    } catch (e) { toast.error('Error: ' + e.message); }
    setActionLoading(null);
  }

  function logout() { clearSession(); window.location.href = '/'; }

  const grouped = {};
  if (orgStructure.length > 0) {
    orgStructure.forEach(o => {
      const d = o.divisi || 'Lainnya';
      if (!grouped[d]) grouped[d] = [];
      grouped[d].push(o);
    });
  }

  const pendingNrp = new Set(pendingRequests.map(r => r.nrp));

  const S = {
    wrap: { minHeight:'100vh', background:'#0f172a', fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif', color:'#e2e8f0', paddingBottom:'70px' },
    header: { background:'linear-gradient(135deg,#1e3a5f,#0f172a)', padding:'16px', borderBottom:'1px solid #1e293b' },
    greeting: { fontSize:'20px', fontWeight:'700', margin:'0 0 4px 0' },
    meta: { fontSize:'13px', color:'#94a3b8' },
    content: { padding:'16px', maxWidth:'480px', margin:'0 auto', transform: refreshing ? 'translateY('+Math.min(refreshY * 0.4, 40)+'px)' : 'none', transition: refreshing ? 'none' : 'transform 0.3s ease' },
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
    { title: 'Kelola Data', items: [
      { icon: '\u{1F465}', label: 'Karyawan', color:'#3b82f6', badge: summary?.total_workers, onClick:()=>setMenuDetail('employees') },
      { icon: '\u{1F3E2}', label: 'Organisasi', color:'#8b5cf6', onClick:()=>setMenuDetail('org') },
      { icon: '\u{1F4CA}', label: 'Divisi', color:'#06b6d4', badge: summary?.total_divisions, onClick:()=>setMenuDetail('divisions') },
      { icon: '\u2699\uFE0F', label: 'Master Data', color:'#6b7280', onClick:()=>setMenuDetail('master') }
    ]},
    { title: 'Operasional HR', items: [
      { icon: '\u{1F4E8}', label: 'Pengajuan', color:'#f59e0b', badge: pending.length + pendingRequests.length, onClick:()=>setMenuDetail('pending') },
      { icon: '\u{1F3D6}\uFE0F', label: 'Cuti', color:'#10b981', onClick:()=>setMenuDetail('cuti') },
      { icon: '\u23F0', label: 'Lembur', color:'#ef4444', onClick:()=>setMenuDetail('overtime') },
      { icon: '\u{1F4CA}', label: 'Payroll', color:'#3b82f6', onClick:()=>setMenuDetail('payroll') }
    ]},
    { title: 'Talent & Performance', items: [
      { icon: '\u{1F3AF}', label: 'KPI', color:'#f59e0b', onClick:()=>setMenuDetail('kpi') },
      { icon: '\u{1F4C8}', label: 'Analytics', color:'#10b981', onClick:()=>setMenuDetail('analytics') },
      { icon: '\u{1F4CB}', label: 'Laporan', color:'#8b5cf6', onClick:()=>setMenuDetail('reports') }
    ]},
    { title: 'Sistem', items: [
      { icon: '\u{1F4CE}', label: 'Audit Log', color:'#6b7280', onClick:()=>setMenuDetail('audit') },
      { icon: '\u{1F4E4}', label: 'Export', color:'#06b6d4', onClick:()=>setMenuDetail('export') },
      { icon: '\u2699\uFE0F', label: 'Pengaturan', color:'#ef4444', onClick:()=>setMenuDetail('settings') }
    ]}
  ];

  const quickItems = [
    { icon: '\u{1F4E8}', label: 'Pengajuan', color:'#f59e0b', badge: pending.length + pendingRequests.length, onClick:()=>setMenuDetail('pending') },
    { icon: '\u{1F465}', label: 'Karyawan', color:'#3b82f6', onClick:()=>setMenuDetail('employees') },
    { icon: '\u{1F3E2}', label: 'Organisasi', color:'#8b5cf6', onClick:()=>setMenuDetail('org') },
    { icon: '\u{1F4CA}', label: 'Payroll', color:'#10b981', onClick:()=>setMenuDetail('payroll') }
  ];

  const notifPendingItems = [
    ...pending.map(p => ({ title: 'Daftar: ' + (p.nama||p.nrp), detail: p.divisi||'', time: p.created_at||'', ...p })),
    ...pendingRequests.map(r => ({ title: 'Request: ' + r.type, detail: r.note||'', time: r.created_at||'', ...r }))
  ];

  const berandaContent = (
    <>
      <RingkasanHari stats={[
        { label:'Karyawan', value:summary?.total_workers||0, color:'#fff' },
        { label:'Divisi', value:summary?.total_divisions||0, color:'#fff' },
        { label:'Pengajuan', value:notifPendingItems.length, color:'#fff' },
        { label:'PKWT', value:summary?.contract_expiring||0, color:'#fff' }
      ]} />
      <QuickAccess items={quickItems} />
      {summary && (
        <div style={S.card}>
          <div style={S.cardTitle}>{'\u{1F4CA}'} Insight Utama</div>
          <div style={S.statGrid3}>
            <div style={S.statItem}><div style={{fontSize:'20px',fontWeight:'700',color:'#38bdf8'}}>{summary.pkwtt_count||0}</div><div style={{fontSize:'10px',color:'#94a3b8'}}>PKWTT</div></div>
            <div style={S.statItem}><div style={{fontSize:'20px',fontWeight:'700',color:'#f59e0b'}}>{summary.pkwt_count||0}</div><div style={{fontSize:'10px',color:'#94a3b8'}}>PKWT</div></div>
            <div style={S.statItem}><div style={{fontSize:'20px',fontWeight:'700',color:'#ef4444'}}>{summary.retiring_soon||0}</div><div style={{fontSize:'10px',color:'#94a3b8'}}>Pensiun</div></div>
          </div>
        </div>
      )}
    </>
  );

  const menuContent = (q) => <MenuGrid categories={menuCategories} searchQuery={q} />;
  const notifContent = <NotifList notifications={[]} pendingItems={notifPendingItems} />;

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
      notifCount={notifPendingItems.length}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onLogout={logout}
      beranda={activeTab === 'beranda' ? berandaContent : null}
      menu={activeTab === 'menu' ? menuContent : null}
      notifikasi={activeTab === 'notifikasi' ? notifContent : null}
    />
  );
}