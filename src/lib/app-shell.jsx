'use client';

import { useState } from 'react';

// ============================================================
// APP SHELL — 3-Tab Layout (Beranda / Menu / Notifikasi)
// ============================================================
export function AppShell({ user, greeting, notifCount, activeTab, onTabChange, beranda, menu, notifikasi, onLogout, style }) {
  const [searchQuery, setSearchQuery] = useState('');

  const tabs = [
    { id: 'beranda', icon: '\u{1F3E0}', label: 'Beranda' },
    { id: 'menu', icon: '\u{1F4CB}', label: 'Menu' },
    { id: 'notifikasi', icon: '\u{1F514}', label: 'Notifikasi', badge: notifCount || 0 }
  ];

  return (
    <div style={{...S.wrap, ...style}}>
      {/* HEADER */}
      <div style={S.header}>
        <div style={S.headerLeft}>
          <div style={S.avatar}>
            <div style={S.avatarText}>{user?.nama?.[0] || 'U'}</div>
          </div>
          <div>
            <div style={{fontSize:'13px',color:'#94a3b8'}}>{greeting || 'Selamat datang'}</div>
            <div style={{fontSize:'16px',fontWeight:'700'}}>{user?.nama || 'User'}</div>
          </div>
        </div>
	<div style={S.headerRight}>
  	<button onClick={() => onTabChange('notifikasi')} style={S.notifBtn}>
    	{'\u{1F514}'}
    	{notifCount > 0 && <span style={S.notifBadge}>{notifCount > 9 ? '9+' : notifCount}</span>}
  	</button>
  	<button onClick={() => onLogout?.()} style={{...S.notifBtn, color:'#f87171'}} title="Logout">
    	{'\u{1F6AA}'}
  	</button>
	</div>
	</div>
      {/* CONTENT */}
      <div style={S.content}>
        {activeTab === 'beranda' && beranda}
        {activeTab === 'menu' && (
          <div>
            <div style={S.searchWrap}>
              <span style={{color:'#64748b'}}>{'\u{1F50D}'}</span>
              <input
                placeholder="Cari menu atau fitur..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={S.searchInput}
              />
            </div>
            {typeof menu === 'function' ? menu(searchQuery) : menu}
          </div>
        )}
        {activeTab === 'notifikasi' && notifikasi}
      </div>

      {/* BOTTOM NAV */}
      <div style={S.bottomNav}>
        {tabs.map(t => (
          <button key={t.id} onClick={() => onTabChange(t.id)} style={S.navItem(activeTab === t.id)}>
            <span style={{position:'relative'}}>
              {t.icon}
              {t.badge > 0 && <span style={S.navBadge}>{t.badge > 9 ? '9+' : t.badge}</span>}
            </span>
            <span style={{fontSize:'11px',marginTop:'2px'}}>{t.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ============================================================
// MENU GRID — Categorized icon grid with search
// ============================================================
export function MenuGrid({ categories, searchQuery }) {
  const q = (searchQuery || '').toLowerCase();

  return (
    <div>
      {categories.map(cat => {
        const filtered = cat.items.filter(item =>
          !q || item.label.toLowerCase().includes(q) || (item.keywords || []).some(k => k.toLowerCase().includes(q))
        );
        if (filtered.length === 0) return null;
        return (
          <div key={cat.title} style={S.menuSection}>
            <div style={S.menuSectionTitle}>{cat.title}</div>
            <div style={S.menuGrid}>
              {filtered.map((item, i) => (
                <button key={i} onClick={item.onClick} style={S.menuItem}>
                  <div style={{...S.menuIcon, background: item.color || '#1e293b'}}>{item.icon}</div>
                  <span style={S.menuLabel}>{item.label}</span>
                  {item.badge && <span style={S.menuBadge}>{item.badge}</span>}
                </button>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ============================================================
// NOTIF LIST — Unified notifications + pending items
// ============================================================
export function NotifList({ notifications, pendingItems, onItemClick }) {
  return (
    <div>
      {pendingItems && pendingItems.length > 0 && (
        <div style={S.notifSection}>
          <div style={S.notifSectionTitle}>{'\u26A1'} Perlu Tindakan ({pendingItems.length})</div>
          {pendingItems.map((item, i) => (
            <div key={i} style={S.notifCard} onClick={() => onItemClick?.(item)}>
              <div style={{display:'flex',alignItems:'center',gap:'10px'}}>
                <div style={{width:'8px',height:'8px',borderRadius:'50%',background:'#f59e0b'}} />
                <div style={{flex:1}}>
                  <div style={{fontSize:'13px',fontWeight:'600'}}>{item.title || item.type}</div>
                  <div style={{fontSize:'12px',color:'#94a3b8'}}>{item.detail || item.note || ''}</div>
                  <div style={{fontSize:'11px',color:'#64748b',marginTop:'2px'}}>{item.time || item.created_at || ''}</div>
                </div>
                <span style={{color:'#94a3b8'}}>{'\u203A'}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      <div style={S.notifSection}>
        <div style={S.notifSectionTitle}>{'\u{1F514}'} Notifikasi</div>
        {(!notifications || notifications.length === 0) ? (
          <div style={{textAlign:'center',color:'#64748b',padding:'32px',fontSize:'13px'}}>Tidak ada notifikasi baru</div>
        ) : notifications.map((n, i) => (
          <div key={i} style={{...S.notifCard, opacity: n.is_read ? 0.6 : 1}} onClick={() => onItemClick?.(n)}>
            <div style={{display:'flex',alignItems:'center',gap:'10px'}}>
              <div style={{width:'8px',height:'8px',borderRadius:'50%',background: n.is_read ? '#475569' : '#38bdf8'}} />
              <div style={{flex:1}}>
                <div style={{fontSize:'13px',fontWeight:'600'}}>{n.title || n.category}</div>
                <div style={{fontSize:'12px',color:'#94a3b8'}}>{n.message || ''}</div>
                <div style={{fontSize:'11px',color:'#64748b',marginTop:'2px'}}>{n.created_at || ''}</div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ============================================================
// RINGKASAN HARI INI — 4 stat cards
// ============================================================
export function RingkasanHari({ stats, onStatClick }) {
  if (!stats || stats.length === 0) return null;
  return (
    <div style={S.ringkasanCard}>
      <div style={S.ringkasanHeader}>
        <div>
          <div style={{fontSize:'16px',fontWeight:'700'}}>Ringkasan Hari Ini</div>
          <div style={{fontSize:'12px',color:'#94a3b8'}}>{new Date().toLocaleDateString('id-ID',{weekday:'long',day:'numeric',month:'long',year:'numeric'})}</div>
        </div>
        <button style={S.detailBtn}>Detail</button>
      </div>
      <div style={S.statGrid4}>
        {stats.map((s, i) => (
          <div key={i} style={S.statItem} onClick={() => onStatClick?.(s)}>
            <div style={{fontSize:'22px',fontWeight:'700',color: s.color || '#fff'}}>{s.value}</div>
            <div style={{fontSize:'10px',color:'rgba(255,255,255,0.7)',marginTop:'2px'}}>{s.label}</div>
            {s.trend && <div style={{fontSize:'9px',color: s.trendUp ? '#34d399' : '#f87171',marginTop:'2px'}}>{s.trend}</div>}
          </div>
        ))}
      </div>
    </div>
  );
}

// ============================================================
// QUICK ACCESS — Grid of icon shortcuts
// ============================================================
export function QuickAccess({ items }) {
  if (!items || items.length === 0) return null;
  return (
    <div>
      <div style={{display:'flex',justifyContent:'space-between',marginBottom:'10px'}}>
        <div style={{fontSize:'14px',fontWeight:'700'}}>Quick Access</div>
      </div>
      <div style={S.quickGrid}>
        {items.map((item, i) => (
          <button key={i} onClick={item.onClick} style={S.quickItem}>
            <div style={{...S.quickIcon, background: item.color || '#1e293b'}}>{item.icon}</div>
            <span style={{fontSize:'11px',color:'#e2e8f0',marginTop:'4px'}}>{item.label}</span>
            {item.badge && <span style={S.quickBadge}>{item.badge}</span>}
          </button>
        ))}
      </div>
    </div>
  );
}

// ============================================================
// STYLES — Module level (shared by all components above)
// ============================================================
const S = {
  wrap: { minHeight:'100vh', background:'#0f172a', fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif', color:'#e2e8f0', display:'flex', flexDirection:'column' },
  header: { background:'linear-gradient(135deg,#1e3a5f,#0f172a)', padding:'16px', display:'flex', justifyContent:'space-between', alignItems:'center', position:'sticky', top:0, zIndex:10 },
  headerLeft: { display:'flex', alignItems:'center', gap:'10px' },
  headerRight: { display:'flex', gap:'8px' },
  avatar: { width:'40px', height:'40px', borderRadius:'50%', background:'linear-gradient(135deg,#38bdf8,#818cf8)', display:'flex', alignItems:'center', justifyContent:'center', border:'2px solid #38bdf8' },
  avatarText: { fontSize:'16px', fontWeight:'700', color:'#fff' },
  notifBtn: { width:'36px', height:'36px', borderRadius:'50%', background:'#1e293b', border:'1px solid #334155', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer', position:'relative', fontSize:'16px' },
  notifBadge: { position:'absolute', top:'-4px', right:'-4px', background:'#ef4444', color:'#fff', fontSize:'9px', fontWeight:'700', borderRadius:'50%', width:'18px', height:'18px', display:'flex', alignItems:'center', justifyContent:'center' },
  content: { flex:1, padding:'16px', paddingBottom:'80px', maxWidth:'480px', margin:'0 auto', width:'100%' },
  bottomNav: { position:'fixed', bottom:0, left:0, right:0, background:'#1e293b', borderTop:'1px solid #334155', display:'flex', justifyContent:'space-around', padding:'8px 0', paddingBottom:'max(8px, env(safe-area-inset-bottom))', zIndex:100 },
  navItem: (active) => ({ flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:'0', border:'none', background:'none', color: active ? '#38bdf8' : '#64748b', cursor:'pointer', transition:'color 0.2s', padding:'4px', position:'relative' }),
  navBadge: { position:'absolute', top:'-6px', right:'50%', transform:'translateX(14px)', background:'#ef4444', color:'#fff', fontSize:'9px', fontWeight:'700', borderRadius:'50%', width:'16px', height:'16px', display:'flex', alignItems:'center', justifyContent:'center' },
logoutBtn: { width:'36px', height:'36px', borderRadius:'50%', background:'#1e293b', border:'1px solid #7f1d1d', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer', fontSize:'16px', color:'#f87171' },
  ringkasanCard: { background:'linear-gradient(135deg,#1e40af,#3b82f6)', borderRadius:'16px', padding:'16px', marginBottom:'16px' },
  ringkasanHeader: { display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:'12px' },
  detailBtn: { background:'rgba(255,255,255,0.2)', border:'none', borderRadius:'8px', padding:'6px 12px', color:'#fff', fontSize:'12px', fontWeight:'600', cursor:'pointer' },
  statGrid4: { display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:'8px' },
  statItem: { textAlign:'center', padding:'8px 4px', background:'rgba(255,255,255,0.1)', borderRadius:'10px', cursor:'pointer' },
  searchWrap: { display:'flex', alignItems:'center', gap:'8px', background:'#1e293b', borderRadius:'10px', padding:'10px 12px', marginBottom:'16px', border:'1px solid #334155' },
  searchInput: { flex:1, background:'none', border:'none', color:'#e2e8f0', fontSize:'13px', outline:'none' },
  menuSection: { marginBottom:'16px' },
  menuSectionTitle: { fontSize:'12px', fontWeight:'700', color:'#94a3b8', marginBottom:'8px', textTransform:'uppercase' },
  menuGrid: { display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:'8px' },
  menuItem: { display:'flex', flexDirection:'column', alignItems:'center', gap:'4px', padding:'12px 4px', background:'#1e293b', borderRadius:'12px', border:'1px solid #334155', cursor:'pointer', transition:'all 0.2s', position:'relative' },
  menuIcon: { width:'40px', height:'40px', borderRadius:'10px', display:'flex', alignItems:'center', justifyContent:'center', fontSize:'18px' },
  menuLabel: { fontSize:'10px', color:'#e2e8f0', textAlign:'center', lineHeight:'1.2' },
  menuBadge: { position:'absolute', top:'4px', right:'4px', background:'#ef4444', color:'#fff', fontSize:'9px', fontWeight:'700', borderRadius:'50%', width:'16px', height:'16px', display:'flex', alignItems:'center', justifyContent:'center' },
  notifSection: { marginBottom:'16px' },
  notifSectionTitle: { fontSize:'14px', fontWeight:'700', marginBottom:'8px' },
  notifCard: { background:'#1e293b', borderRadius:'10px', padding:'12px', marginBottom:'6px', border:'1px solid #334155', cursor:'pointer' },
  quickGrid: { display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:'8px', marginBottom:'16px' },
  quickItem: { display:'flex', flexDirection:'column', alignItems:'center', padding:'12px 4px', background:'#1e293b', borderRadius:'12px', border:'1px solid #334155', cursor:'pointer', position:'relative' },
  quickIcon: { width:'44px', height:'44px', borderRadius:'12px', display:'flex', alignItems:'center', justifyContent:'center', fontSize:'20px' },
  quickBadge: { position:'absolute', top:'4px', right:'4px', background:'#ef4444', color:'#fff', fontSize:'9px', fontWeight:'700', borderRadius:'50%', minWidth:'16px', height:'16px', display:'flex', alignItems:'center', justifyContent:'center' },
};
