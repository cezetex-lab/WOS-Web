import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';

export default function OwnerDashboard() {
  const [tab, setTab] = useState('modules');
  const [modules, setModules] = useState([]);
  const [businessUnits, setBusinessUnits] = useState([]);
  const [roles, setRoles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');

  useEffect(() => { loadAll(); }, []);

  async function loadAll() {
    setLoading(true);
    try {
      const [mod, bu, rl] = await Promise.all([
        rpc('get_modules_for_owner', {}),
        rpc('get_business_units_for_owner', {}),
        rpc('get_role_overview', {}),
      ]);
      setModules(mod || []);
      setBusinessUnits(bu || []);
      setRoles(rl || []);
    } catch {}
    setLoading(false);
  }

  async function toggleModule(code, enabled, buId) {
    setMsg('');
    try {
      const d = await rpc('owner_toggle_lock', { p_module_code: code, p_enable: !enabled, p_bu_id: buId });
      if (d?.ok) {
        setMsg('✅ ' + (d.msg || 'Updated'));
        loadAll();
      } else {
        setMsg('❌ ' + (d?.msg || 'Gagal'));
      }
    } catch (e) { setMsg('❌ ' + e.message); }
  }

  async function setTier(buId, tier) {
    setMsg('');
    try {
      const d = await rpc('owner_set_tier', { p_bu_id: buId, p_tier: tier });
      if (d?.ok) { setMsg('✅ Tier updated'); loadAll(); }
      else setMsg('❌ ' + (d?.msg || 'Gagal'));
    } catch (e) { setMsg('❌ ' + e.message); }
  }

  const tabs = [
    { key: 'modules', icon: '🧩', label: 'Module Lock' },
    { key: 'tier', icon: '⭐', label: 'Tier & Pricing' },
    { key: 'roles', icon: '👥', label: 'Role Overview' },
  ];

  // Group modules by BU
  const modulesByBU = {};
  modules.forEach(m => {
    const bu = m.business_unit_code || m.business_unit_id || 'HQ';
    if (!modulesByBU[bu]) modulesByBU[bu] = [];
    modulesByBU[bu].push(m);
  });

  return (
    <div style={{ minHeight: '100vh', background: '#0f172a', color: '#f8fafc', padding: 20 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700 }}>🔐 Owner Control Center</h1>
          <p style={{ fontSize: 12, color: '#94a3b8' }}>System Installer — Kelola modul, tier, dan roles</p>
        </div>
        <div style={{ fontSize: 12, color: '#64748b' }}>
          {new Date().toLocaleDateString('id-ID')}
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {tabs.map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            style={{ padding: '8px 16px', borderRadius: 8, border: tab === t.key ? '2px solid #3b82f6' : '1px solid #334155',
              background: tab === t.key ? '#1e3a5f' : '#1e293b', color: '#f8fafc', cursor: 'pointer', fontSize: 13 }}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {msg && <div style={{ padding: 10, borderRadius: 8, background: msg.startsWith('✅') ? '#064e3b' : '#7f1d1d', marginBottom: 16, fontSize: 12 }}>{msg}</div>}

      {loading ? <p style={{ color: '#94a3b8' }}>Loading...</p> : (
        <>
          {/* MODULE LOCK TAB */}
          {tab === 'modules' && (
            <div style={{ display: 'grid', gap: 16 }}>
              {Object.entries(modulesByBU).map(([bu, mods]) => (
                <div key={bu} style={{ padding: 16, borderRadius: 12, background: '#1e293b', border: '1px solid #334155' }}>
                  <h3 style={{ fontSize: 14, fontWeight: 600, marginBottom: 12, color: '#60a5fa' }}>
                    {bu === 'MINING' ? '⛏️' : bu === 'ESTATE' ? '🌴' : bu === 'MILL' ? '🏭' : '🏢'} {bu}
                  </h3>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 8 }}>
                    {mods.map(m => (
                      <div key={m.module_code} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', borderRadius: 8, background: '#0f172a' }}>
                        <span style={{ fontSize: 12 }}>{m.module_name || m.module_code}</span>
                        <button onClick={() => toggleModule(m.module_code, m.is_enabled, m.business_unit_id)}
                          style={{ padding: '4px 12px', borderRadius: 12, border: 'none', cursor: 'pointer', fontSize: 11, fontWeight: 600,
                            background: m.is_enabled ? '#10b981' : '#ef4444', color: '#fff' }}>
                          {m.is_enabled ? 'ON' : 'OFF'}
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* TIER TAB */}
          {tab === 'tier' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: 12 }}>
              {businessUnits.map(bu => (
                <div key={bu.id} style={{ padding: 16, borderRadius: 12, background: '#1e293b', border: '1px solid #334155' }}>
                  <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 8 }}>{bu.unit_name || bu.unit_code || bu.id}</div>
                  <div style={{ fontSize: 11, color: '#94a3b8', marginBottom: 12 }}>Tier saat ini: <strong>{bu.tier || 0}</strong></div>
                  <div style={{ display: 'flex', gap: 4 }}>
                    {[0, 1, 2, 3, 4].map(t => (
                      <button key={t} onClick={() => setTier(bu.id, t)}
                        style={{ width: 36, height: 36, borderRadius: 8, border: bu.tier === t ? '2px solid #3b82f6' : '1px solid #475569',
                          background: bu.tier === t ? '#1e40af' : '#0f172a', color: '#f8fafc', cursor: 'pointer', fontWeight: 700, fontSize: 14 }}>
                        {t}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* ROLES TAB */}
          {tab === 'roles' && (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
                <thead>
                  <tr style={{ background: '#1e293b' }}>
                    <th style={th}>NRP</th>
                    <th style={th}>Nama</th>
                    <th style={th}>Role</th>
                    <th style={th}>Level</th>
                    <th style={th}>Business Unit</th>
                  </tr>
                </thead>
                <tbody>
                  {roles.map((r, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid #1e293b' }}>
                      <td style={td}>{r.nrp}</td>
                      <td style={td}>{r.nama}</td>
                      <td style={td}>
                        <span style={{ padding: '2px 8px', borderRadius: 10, fontSize: 11, background: r.role === 'owner' ? '#7c3aed' : '#3b82f6', color: '#fff' }}>
                          {r.role}
                        </span>
                      </td>
                      <td style={td}>L{r.role_level}</td>
                      <td style={td}>{r.business_unit || r.unit_code || '-'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </div>
  );
}

const th = { textAlign: 'left', padding: '10px 8px', fontSize: 11, fontWeight: 600, color: '#94a3b8', borderBottom: '2px solid #334155' };
const td = { padding: '8px', fontSize: 12, color: '#e2e8f0' };
