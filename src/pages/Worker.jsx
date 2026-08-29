import { useState, useEffect, useRef } from 'react';
import { rpc, getSession, clearSession } from '@/lib/supabase-browser';
import { BarChart, StatCard, ProgressBar, Sparkline, DarkModeToggle, useToast } from '@/lib/ui-components';
import { MultiStepForm, TaskBoard, OKRCard, SurveyCard } from '@/lib/components';
import { AppShell, MenuGrid, NotifList, RingkasanHari, QuickAccess } from '@/lib/app-shell';

const NEXT_POSITION = {
  1: 'Supervisor', 2: 'Manager', 3: 'Direktur', 4: 'Direktur Utama', 5: null
};

function greetingTime() {
  const hour = new Date().getHours();
  if (hour < 6) return 'Selamat malam';
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

export default function WorkerPage() {
  const [user, setUser] = useState(null);
  const [activeTab, setActiveTab] = useState('beranda');

  const [profile, setProfile] = useState(null);
  const [status, setStatus] = useState(null);
  const [announcements, setAnnouncements] = useState([]);
  const [requests, setRequests] = useState([]);
  const [payroll, setPayroll] = useState([]);
  const [leave, setLeave] = useState(null);
  const [learning, setLearning] = useState([]);
  const [engagement, setEngagement] = useState(null);
  const [notifications, setNotifications] = useState([]);
  const [careerPath, setCareerPath] = useState(null);
  const [skills, setSkills] = useState([]);
  const [benefits, setBenefits] = useState([]);
  const [narrative, setNarrative] = useState(null);
  const [loading, setLoading] = useState(true);
  const [expandedPayroll, setExpandedPayroll] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshY, setRefreshY] = useState(0);
  const [medical, setMedical] = useState([]);
  const [overtime, setOvertime] = useState([]);
  const [ideas, setIdeas] = useState([]);
  const [trainingCatalog, setTrainingCatalog] = useState([]);
  const [talentMarket, setTalentMarket] = useState([]);
  const [contPerf, setContPerf] = useState([]);
  const [compIntel, setCompIntel] = useState(null);
  const [capability, setCapability] = useState([]);
  const [exitInfo, setExitInfo] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [okrs, setOkrs] = useState([]);
  const [surveys, setSurveys] = useState([]);
  const [showForm, setShowForm] = useState(null);
  const [menuDetail, setMenuDetail] = useState(null);
  const pullStartY = useRef(0);
  const toast = useToast();

  function fmt(n) { return n ? "Rp " + Number(n).toLocaleString("id-ID") : "-"; }

  useEffect(() => {
    const u = getSession();
    if (!u || u.role === 'admin') { window.location.href = '/'; return; }
    setUser(u);
    loadData(u.nrp);
  }, []);

  async function loadData(nrp) {
    setLoading(true);
    try {
      const r = await Promise.all([
        rpc('get_worker_profile', { p_nrp: nrp }),
        rpc('get_worker_status', { p_nrp: nrp }),
        rpc('get_announcements'),
        rpc('get_worker_requests', { p_nrp: nrp }),
        rpc('get_worker_payroll', { p_nrp: nrp }),
        rpc('get_worker_leave', { p_nrp: nrp }),
        rpc('get_worker_learning', { p_nrp: nrp }),
        rpc('get_worker_engagement', { p_nrp: nrp }),
        rpc('get_worker_notifications', { p_nrp: nrp }),
        rpc('get_career_path', { p_nrp: nrp }),
        rpc('get_skills_intelligence', { p_nrp: nrp }),
        rpc('get_benefit_data', { p_nrp: nrp }),
        rpc('get_worker_narrative', { p_nrp: nrp }),
        rpc('get_worker_medical', { p_nrp: nrp }),
        rpc('get_worker_overtime', { p_nrp: nrp }),
        rpc('list_ideas', { p_nrp: nrp }),
        rpc('get_training_catalog'),
        rpc('get_talent_marketplace'),
        rpc('get_my_continuous_performance', { p_nrp: nrp }),
        rpc('get_my_compensation_intelligence', { p_nrp: nrp }),
        rpc('get_worker_capability', { p_nrp: nrp }),
        rpc('get_worker_exit', { p_nrp: nrp }),
        rpc('get_my_tasks', { p_nrp: nrp }),
        rpc('get_my_okrs', { p_nrp: nrp }),
        rpc('get_active_surveys')
      ]);
      const [p, s, a, req, pay, lv, learn, eng, notif, cp, sk, ben, nar, med, ot, ideas, tCat, tMkt, cPerf, cIntel, cap, ex, tk, ok, sv] = r;
      if(med.ok&&med.data)setMedical(med.data);
      if(ot.ok&&ot.data)setOvertime(ot.data);
      if(ideas.ok&&ideas.data)setIdeas(ideas.data);
      if(tCat.ok&&tCat.data)setTrainingCatalog(tCat.data);
      if(tMkt.ok&&tMkt.data)setTalentMarket(tMkt.data);
      if(cPerf.ok&&cPerf.data)setContPerf(cPerf.data);
      if(cIntel.ok)setCompIntel(cIntel);
      if(cap.ok&&cap.data)setCapability(cap.data);
      if(ex.ok&&ex.data)setExitInfo(ex.data);
      if(tk.ok&&tk.data)setTasks(tk.data);
      if(ok.ok&&ok.data)setOkrs(ok.data);
      if(sv.ok&&sv.data)setSurveys(sv.data);
      if (p.ok) setProfile(p);
      if (s.ok) setStatus(s);
      if (a.ok && a.data) setAnnouncements(a.data);
      if (req.ok && req.data) setRequests(req.data);
      if (pay.ok && pay.data) setPayroll(pay.data);
      if (lv.ok) setLeave(lv);
      if (learn.ok && learn.data) setLearning(learn.data);
      if (eng.ok) setEngagement(eng);
      if (notif.ok) setNotifications(notif);
      if (cp.ok) setCareerPath(cp);
      if (sk.ok && sk.data) setSkills(sk.data);
      if (ben.ok && ben.data) setBenefits(ben.data);
      if (nar.ok) setNarrative(nar);
    } catch (e) { console.error('Load error:', e); }
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
      await loadData(user.nrp);
      setRefreshing(false);
      toast.success('Data diperbarui');
    }
    setRefreshY(0);
  }

  function logout() { clearSession(); window.location.href = '/'; }
  const pct = (a, b) => b > 0 ? Math.round(a / b * 100) : 0;

  const uniquePayroll = [];
  const seenPeriode = new Set();
  payroll.forEach(p => {
    const key = p.periode;
    if (!seenPeriode.has(key)) {
      seenPeriode.add(key);
      uniquePayroll.push(p);
    }
  });

  const hasNotif = (notifications.unread || 0) > 0;
  const notifCount = notifications.unread || 0;
  const nextPos = profile?.level ? NEXT_POSITION[profile.level] : null;
  const isTopLevel = !nextPos || profile?.level >= 5;

  const S = {
    wrap: { minHeight:'100vh', background:'#0f172a', fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif', color:'#e2e8f0', paddingBottom:'70px' },
    header: { background:'linear-gradient(135deg,#1e3a5f,#0f172a)', padding:'16px', borderBottom:'1px solid #1e293b' },
    greeting: { fontSize:'20px', fontWeight:'700', margin:'0 0 4px 0' },
    meta: { fontSize:'13px', color:'#94a3b8' },
    content: { padding:'16px', maxWidth:'480px', margin:'0 auto', transform: refreshing ? 'translateY('+Math.min(refreshY * 0.4, 40)+'px)' : 'none', transition: refreshing ? 'none' : 'transform 0.3s ease' },
    card: { background:'#1e293b', borderRadius:'12px', padding:'16px', marginBottom:'12px', border:'1px solid #334155' },
    cardTitle: { fontSize:'14px', fontWeight:'700', color:'#38bdf8', marginBottom:'8px' },
    statGrid: { display:'grid', gridTemplateColumns:'1fr 1fr', gap:'8px' },
    statGrid3: { display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:'8px' },
    metricItem: { minWidth:'100px', background:'#0f172a', borderRadius:'8px', padding:'12px', textAlign:'center', border:'1px solid #334155', flexShrink:0 },
    metricVal: { fontSize:'24px', fontWeight:'700', color:'#38bdf8' },
    metricLabel: { fontSize:'11px', color:'#94a3b8', marginTop:'4px' },
    list: { listStyle:'none', padding:0, margin:0 },
    listItem: { padding:'10px 0', borderBottom:'1px solid #334155', fontSize:'13px' },
    badge: (s) => ({ display:'inline-block', padding:'2px 8px', borderRadius:'12px', fontSize:'11px', fontWeight:'600',
      background: s==='Approved'||s==='APPROVED'||s==='COMPLETED'?'#065f46':s==='Rejected'||s==='REJECTED'?'#7f1d1d':s==='Pending'||s==='PENDING'||s==='REQUESTED'?'#78350f':s==='IN_PROGRESS'?'#1e3a5f':'#334155',
      color: s==='Approved'||s==='APPROVED'||s==='COMPLETED'?'#34d399':s==='Rejected'||s==='REJECTED'?'#fca5a5':s==='Pending'||s==='PENDING'||s==='REQUESTED'?'#fbbf24':s==='IN_PROGRESS'?'#38bdf8':'#94a3b8'
    }),
    bottomNav: { position:'fixed', bottom:0, left:0, right:0, background:'#1e293b', borderTop:'1px solid #334155', display:'flex', justifyContent:'space-around', padding:'8px 0', paddingBottom:'calc(8px + env(safe-area-inset-bottom, 0px))' },
    navItem: (active) => ({ display:'flex', flexDirection:'column', alignItems:'center', gap:'2px', padding:'4px 8px', color: active?'#38bdf8':'#64748b', fontSize:'10px', fontWeight: active?'700':'500', cursor:'pointer', border:'none', background:'none' }),
    navIcon: { fontSize:'20px' },
    empty: { textAlign:'center', padding:'32px', color:'#64748b', fontSize:'13px' },
    subTab: (active) => ({ padding:'6px 12px', borderRadius:'6px', border:'none', background:active?'#38bdf8':'#0f172a', color:active?'#0f172a':'#94a3b8', fontSize:'11px', fontWeight:'600', cursor:'pointer', whiteSpace:'nowrap' }),
    bar: { background:'#0f172a', borderRadius:'4px', height:'8px', overflow:'hidden' },
    barFill: (pct, c) => ({ background:c||'#38bdf8', height:'100%', width:Math.min(pct,100)+'%', borderRadius:'4px' }),
    expandItem: { padding:'12px', borderBottom:'1px solid #334155', cursor:'pointer' },
    payDetail: { background:'#0f172a', borderRadius:'8px', padding:'12px', marginTop:'8px', fontSize:'12px' },
    payRow: { display:'flex', justifyContent:'space-between', padding:'4px 0', borderBottom:'1px solid #1e293b' },
    refreshBar: { textAlign:'center', padding:'8px', fontSize:'12px', color:'#38bdf8', overflow:'hidden' },
  };

  if (loading) return <div style={{...S.wrap, display:'flex', alignItems:'center', justifyContent:'center'}}><p style={{color:'#64748b'}}>Memuat data...</p></div>;

  const handleLogout = () => { clearSession(); window.location.href = '/'; };

  const menuCategories = [
    { title: 'Saya', items: [
      { icon: '\u{1F464}', label: 'Profil Saya', color:'#3b82f6', onClick:()=>setMenuDetail('profile') },
      { icon: '\u{1F4CA}', label: 'Status Saya', color:'#8b5cf6', onClick:()=>setMenuDetail('status') },
      { icon: '\u2699\uFE0F', label: 'Pengaturan', color:'#6b7280', onClick:()=>setMenuDetail('settings') }
    ]},
    { title: 'Hub Kerja', items: [
      { icon: '\u{1F465}', label: 'Tim Saya', color:'#10b981', onClick:()=>setMenuDetail('team') },
      { icon: '\u{1F4C5}', label: 'Kehadiran', color:'#06b6d4', onClick:()=>setMenuDetail('attendance') },
      { icon: '\u{1F3D6}\uFE0F', label: 'Cuti', color:'#f59e0b', onClick:()=>setMenuDetail('cuti') },
      { icon: '\u23F0', label: 'Lembur', color:'#ef4444', onClick:()=>setMenuDetail('overtime') },
      { icon: '\u{1F3AF}', label: 'KPI', color:'#3b82f6', onClick:()=>setMenuDetail('kpi') },
      { icon: '\u2705', label: 'Approval', color:'#10b981', onClick:()=>setMenuDetail('tasks') }
    ]},
    { title: 'Pengembangan', items: [
      { icon: '\u{1F4DA}', label: 'Learning', color:'#8b5cf6', onClick:()=>setMenuDetail('learning') },
      { icon: '\u{1F680}', label: 'Karir', color:'#f59e0b', onClick:()=>setMenuDetail('career') },
      { icon: '\u{1F3E2}', label: 'Talent Market', color:'#06b6d4', onClick:()=>setMenuDetail('market') },
      { icon: '\u{1F3AF}', label: 'OKR', color:'#ef4444', onClick:()=>setMenuDetail('okr') },
      { icon: '\u{1F4CB}', label: 'Survei', color:'#10b981', onClick:()=>setMenuDetail('survey') }
    ]},
    { title: 'Informasi', items: [
      { icon: '\u{1F4E2}', label: 'Pengumuman', color:'#f59e0b', onClick:()=>setMenuDetail('pengumuman') },
      { icon: '\u{1F4B0}', label: 'Slip Gaji', color:'#10b981', onClick:()=>setMenuDetail('gaji') },
      { icon: '\u{1F381}', label: 'Benefit', color:'#8b5cf6', onClick:()=>setMenuDetail('benefit') },
      { icon: '\u{1F4C2}', label: 'Dokumen', color:'#06b6d4', onClick:()=>setMenuDetail('dokumen') }
    ]}
  ];

  const quickItems = [
    { icon: '\u{1F4C5}', label: 'Kehadiran', color:'#06b6d4', onClick:()=>setMenuDetail('attendance') },
    { icon: '\u{1F3D6}\uFE0F', label: 'Cuti', color:'#f59e0b', onClick:()=>setMenuDetail('cuti') },
    { icon: '\u23F0', label: 'Lembur', color:'#ef4444', onClick:()=>setMenuDetail('overtime') },
    { icon: '\u{1F3AF}', label: 'KPI', color:'#3b82f6', onClick:()=>setMenuDetail('kpi') },
    { icon: '\u{1F4B0}', label: 'Slip Gaji', color:'#10b981', onClick:()=>setMenuDetail('gaji') },
    { icon: '\u{1F4DA}', label: 'Learning', color:'#8b5cf6', onClick:()=>setMenuDetail('learning') },
    { icon: '\u{1F680}', label: 'Karir', color:'#f59e0b', onClick:()=>setMenuDetail('career') },
    { icon: '\u2705', label: 'Tasks', color:'#10b981', onClick:()=>setMenuDetail('tasks') }
  ];

  const pendingItems = (requests || []).filter(r => r.status === 'Pending' || r.status === 'PENDING').map(r => ({
    title: r.type, detail: r.note || '', time: r.created_at || '', ...r
  }));

  const berandaContent = (
    <>
      <RingkasanHari stats={[
        { label:'Kehadiran', value: (status?.attendance_rate || 98)+'%', color:'#fff' },
        { label:'Pengajuan', value: requests?.length || 0, color:'#fff' },
        { label:'Menunggu', value: pendingItems.length, color:'#fff' },
        { label:'Notifikasi', value: notifications?.unread || 0, color:'#fff' }
      ]} />
      <QuickAccess items={quickItems} />
      {narrative && (
        <div style={S.card}>
          <div style={S.cardTitle}>{'\u{1F4A1}'} Insight Hari Ini</div>
          <div style={{fontSize:'13px',lineHeight:'1.5'}}>{narrative.narrative || '-'}</div>
        </div>
      )}
      {announcements.length > 0 && (
        <div style={S.card}>
          <div style={{display:'flex',justifyContent:'space-between',marginBottom:'8px'}}>
            <div style={S.cardTitle}>{'\u{1F4E2}'} Pengumuman Terbaru</div>
            <button onClick={()=>setMenuDetail('pengumuman')} style={{background:'none',border:'none',color:'#38bdf8',fontSize:'12px',cursor:'pointer'}}>Lihat Semua</button>
          </div>
          <div style={{padding:'12px',background:'#0f172a',borderRadius:'10px',borderLeft:'3px solid #f59e0b'}}>
            <div style={{fontWeight:'600',fontSize:'13px'}}>{announcements[0].title}</div>
            <div style={{fontSize:'12px',color:'#94a3b8',marginTop:'4px'}}>{announcements[0].message || ''}</div>
          </div>
        </div>
      )}
    </>
  );

  const menuContent = (q) => (
    <MenuGrid categories={menuCategories} searchQuery={q} />
  );

  const notifContent = (
    <NotifList
      notifications={notifications?.data || []}
      pendingItems={pendingItems}
    />
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
      notifCount={notifications?.unread || 0}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onLogout={logout}
      beranda={activeTab === 'beranda' ? berandaContent : null}
      menu={activeTab === 'menu' ? menuContent : null}
      notifikasi={activeTab === 'notifikasi' ? notifContent : null}
    />
  );
}