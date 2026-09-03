import { useState, useEffect, useCallback } from 'react';
import { rpc, clearSession, signOutAuth } from '@/lib/supabase-browser';
import { useNavigate } from 'react-router-dom';

export default function OwnerDashboard() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('overview');
  const [loading, setLoading] = useState(true);

  // Data states
  const [stats, setStats] = useState({});
  const [employeesByBU, setEmployeesByBU] = useState([]);
  const [modules, setModules] = useState([]);
  const [businessUnits, setBusinessUnits] = useState([]);
  const [roles, setRoles] = useState([]);
  const [auditLog, setAuditLog] = useState({ data: [], total: 0 });
  const [auditActions, setAuditActions] = useState([]);
  const [auditFilter, setAuditFilter] = useState({ action: '', page: 0 });
  const [sessions, setSessions] = useState([]);
  const [loginStats, setLoginStats] = useState({});
  const [securitySettings, setSecuritySettings] = useState([]);

  // Wave 2 states
  const [employees, setEmployees] = useState({ data: [], total: 0 });
  const [empFilter, setEmpFilter] = useState({ bu: '', search: '', page: 0 });
  const [showEmpCreator, setShowEmpCreator] = useState(false);
  const [newEmp, setNewEmp] = useState({ nrp: '', nama: '', email: '', divisi: '', posisi: '', bu_id: '', role: 'worker', role_level: 1 });
  const [editEmp, setEditEmp] = useState(null);
  const [announcements, setAnnouncements] = useState([]);
  const [showAnnCreator, setShowAnnCreator] = useState(false);
  const [newAnn, setNewAnn] = useState({ title: '', message: '', priority: 'NORMAL', target_audience: 'ALL' });
  const [notifConfig, setNotifConfig] = useState([]);
  const [sysAnnouncements, setSysAnnouncements] = useState([]);
  const [showSysAnnCreator, setShowSysAnnCreator] = useState(false);
  const [newSysAnn, setNewSysAnn] = useState({ title: '', message: '', type: 'info', dismissible: true });
  // Wave 3 states
  const [activityStats, setActivityStats] = useState({});
  const [integrations, setIntegrations] = useState([]);
  const [showIntCreator, setShowIntCreator] = useState(false);
  const [newInt, setNewInt] = useState({ name: '', type: 'webhook' });
  const [retentionRules, setRetentionRules] = useState([]);
  const [changelog, setChangelog] = useState([]);
  const [tickets, setTickets] = useState([]);
  const [usageAnalytics, setUsageAnalytics] = useState({});
  // Edit states
  const [editRole, setEditRole] = useState(null);
  const [editForm, setEditForm] = useState({ role: '', role_level: 1 });
  const [showBUCreator, setShowBUCreator] = useState(false);
  const [newBU, setNewBU] = useState({ unit_code: '', unit_name: '', description: '' });
  const [editBU, setEditBU] = useState(null);
  const [editBUForm, setEditBUForm] = useState({ unit_name: '', description: '' });
  // Wave 4 — Access Control states
  const [adminRoles, setAdminRoles] = useState([]);
  const [adminAccounts, setAdminAccounts] = useState([]);
  const [showRoleCreator, setShowRoleCreator] = useState(false);
  const [newRole, setNewRole] = useState({ role_code: '', role_name: '', scope_type: 'global', scope_id: '', permissions: '[]' });
  const [editRoleAdmin, setEditRoleAdmin] = useState(null);
  const [editRoleForm, setEditRoleForm] = useState({ role_name: '', permissions: '' });
  const [assignUser, setAssignUser] = useState({ nrp: '', role_code: '' });

  // Loaders
  const loadOverview = useCallback(async () => {
    try {
      const [s, b] = await Promise.all([rpc('get_owner_overview_stats'), rpc('get_owner_employees_by_bu')]);
      setStats(s || {});
      setEmployeesByBU(Array.isArray(b) ? b : []);
    } catch (e) { /* silent */ }
  }, []);

  const loadModules = useCallback(async () => {
    try {
      const [m, bu, r] = await Promise.all([rpc('get_modules_for_owner'), rpc('get_business_units_for_owner'), rpc('get_role_overview')]);
      setModules(Array.isArray(m) ? m : []);
      setBusinessUnits(Array.isArray(bu) ? bu : []);
      setRoles(Array.isArray(r) ? r : []);
    } catch (e) { /* silent */ }
  }, []);

  const loadAuditLog = useCallback(async () => {
    try {
      const [log, actions] = await Promise.all([
        rpc('get_audit_log_v2', { p_action_type: auditFilter.action || null, p_limit: 50, p_offset: auditFilter.page * 50 }),
        rpc('get_audit_log_actions'),
      ]);
      setAuditLog(log || { data: [], total: 0 });
      setAuditActions(Array.isArray(actions) ? actions : []);
    } catch (e) { /* silent */ }
  }, [auditFilter.action, auditFilter.page]);

  const loadSecurity = useCallback(async () => {
    try {
      const [s, ls, ss] = await Promise.all([rpc('get_active_sessions'), rpc('get_login_attempt_stats'), rpc('owner_get_security_settings')]);
      setSessions(Array.isArray(s) ? s : []);
      setLoginStats(ls || {});
      setSecuritySettings(Array.isArray(ss) ? ss : []);
    } catch (e) { /* silent */ }
  }, []);

  const loadEmployees = useCallback(async () => {
    try {
      const r = await rpc('owner_get_employees', { p_bu_id: empFilter.bu || null, p_search: empFilter.search || null, p_limit: 50, p_offset: empFilter.page * 50 });
      setEmployees(r || { data: [], total: 0 });
    } catch (e) { /* silent */ }
  }, [empFilter.bu, empFilter.search, empFilter.page]);

  const loadAnnouncements = useCallback(async () => {
    try {
      const r = await rpc('owner_get_announcements');
      setAnnouncements(Array.isArray(r) ? r : []);
    } catch (e) { /* silent */ }
  }, []);

  const loadNotifConfig = useCallback(async () => {
    try {
      const r = await rpc('get_notification_config');
      setNotifConfig(Array.isArray(r) ? r : []);
    } catch (e) { /* silent */ }
  }, []);

  const loadSysAnnouncements = useCallback(async () => {
    try {
      const r = await rpc('owner_get_system_announcements');
      setSysAnnouncements(Array.isArray(r) ? r : []);
    } catch (e) { /* silent */ }
  }, []);

  const loadActivity = useCallback(async () => {
    try { const r = await rpc('owner_get_activity_stats'); setActivityStats(r || {}); } catch (e) {}
  }, []);

  const loadIntegrations = useCallback(async () => {
    try { const r = await rpc('owner_get_integrations'); setIntegrations(Array.isArray(r) ? r : []); } catch (e) {}
  }, []);

  const loadRetention = useCallback(async () => {
    try { const r = await rpc('owner_get_retention_rules'); setRetentionRules(Array.isArray(r) ? r : []); } catch (e) {}
  }, []);

  const loadChangelog = useCallback(async () => {
    try { const r = await rpc('owner_get_changelog'); setChangelog(Array.isArray(r) ? r : []); } catch (e) {}
  }, []);

  const loadTickets = useCallback(async () => {
    try { const r = await rpc('owner_get_tickets'); setTickets(Array.isArray(r) ? r : []); } catch (e) {}
  }, []);

  const loadAnalytics = useCallback(async () => {
    try { const r = await rpc('owner_get_usage_analytics'); setUsageAnalytics(r || {}); } catch (e) {}
  }, []);

  const loadAccessControl = useCallback(async () => {
    try {
      const [r, a] = await Promise.all([rpc('owner_get_admin_roles'), rpc('owner_get_admin_accounts')]);
      setAdminRoles(Array.isArray(r) ? r : []);
      setAdminAccounts(Array.isArray(a) ? a : []);
    } catch (e) { /* silent */ }
  }, []);

  useEffect(() => {
    setLoading(true);
    const loaders = { overview: loadOverview, modules: loadModules, tiers: loadModules, roles: loadModules, audit: loadAuditLog, security: loadSecurity, bu: loadModules, employees: loadEmployees, announcements: loadAnnouncements, notifications: loadNotifConfig, sysann: loadSysAnnouncements, activity: loadActivity, integrations: loadIntegrations, retention: loadRetention, changelog: loadChangelog, support: loadTickets, analytics: loadAnalytics, access: loadAccessControl };
    (loaders[activeTab] || loadModules)().finally(() => setLoading(false));
  }, [activeTab, loadOverview, loadModules, loadAuditLog, loadSecurity, loadEmployees, loadAnnouncements, loadNotifConfig, loadSysAnnouncements, loadActivity, loadIntegrations, loadRetention, loadChangelog, loadTickets, loadAnalytics, loadAccessControl]);

  // Actions
  async function toggleLock(code, current, buId) {
    await rpc('owner_toggle_lock', { p_module_code: code, p_enable: !current, p_bu_id: buId });
    loadModules();
  }
  async function updateRole() {
    if (!editRole) return;
    await rpc('owner_update_role', { p_nrp: editRole.nrp, p_role: editForm.role, p_role_level: parseInt(editForm.role_level) });
    setEditRole(null);
    loadModules();
  }
  async function setTier(buId, tier) {
    await rpc('owner_set_tier', { p_bu_id: buId, p_tier: tier });
    loadModules();
  }
  async function createBU() {
    if (!newBU.unit_code || !newBU.unit_name) return;
    await rpc('owner_create_bu', { p_unit_code: newBU.unit_code, p_unit_name: newBU.unit_name, p_description: newBU.description || null });
    setNewBU({ unit_code: '', unit_name: '', description: '' });
    setShowBUCreator(false);
    loadModules();
  }
  async function updateBU() {
    if (!editBU) return;
    await rpc('owner_update_bu', { p_bu_id: editBU.id, p_unit_name: editBUForm.unit_name, p_description: editBUForm.description });
    setEditBU(null);
    loadModules();
  }
  async function deleteBU(id) {
    if (!confirm('Hapus Business Unit ini?')) return;
    await rpc('owner_delete_bu', { p_bu_id: id });
    loadModules();
  }
  async function forceLogout(nrp) {
    if (!confirm('Force logout ' + nrp + '?')) return;
    await rpc('owner_force_logout', { p_nrp: nrp });
    loadSecurity();
  }
  async function createAdminRole() {
    if (!newRole.role_code || !newRole.role_name) return;
    await rpc('owner_create_admin_role', { p_role_code: newRole.role_code, p_role_name: newRole.role_name, p_scope_type: newRole.scope_type, p_scope_id: newRole.scope_id || null, p_permissions: JSON.parse(newRole.permissions || '[]') });
    setNewRole({ role_code: '', role_name: '', scope_type: 'global', scope_id: '', permissions: '[]' });
    setShowRoleCreator(false); loadAccessControl();
  }
  async function updateAdminRole() {
    if (!editRoleAdmin) return;
    await rpc('owner_update_admin_role', { p_role_id: editRoleAdmin.id, p_role_name: editRoleForm.role_name, p_permissions: JSON.parse(editRoleForm.permissions || '[]'), p_is_active: true });
    setEditRoleAdmin(null); loadAccessControl();
  }
  async function deleteAdminRole(id) {
    if (!confirm('Deactivate?')) return;
    await rpc('owner_update_admin_role', { p_role_id: id, p_role_name: null, p_permissions: null, p_is_active: false });
    loadAccessControl();
  }
  async function assignAdminUser() {
    if (!assignUser.nrp || !assignUser.role_code) return;
    await rpc('owner_assign_admin_user', { p_nrp: assignUser.nrp, p_role_code: assignUser.role_code });
    setAssignUser({ nrp: '', role_code: '' }); loadAccessControl();
  }

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'modules', label: 'Module Lock' },
    { id: 'tiers', label: 'Tier & Pricing' },
    { id: 'roles', label: 'Roles' },
    { id: 'audit', label: 'Audit Log' },
    { id: 'security', label: 'Security' },
    { id: 'bu', label: 'Business Units' },
    { id: 'employees', label: 'Employees' },
    { id: 'announcements', label: 'Announcements' },
    { id: 'notifications', label: 'Notifications' },
    { id: 'sysann', label: 'System Banner' },
    { id: 'activity', label: 'Activity' },
    { id: 'integrations', label: 'Integrations' },
    { id: 'retention', label: 'Data Retention' },
    { id: 'changelog', label: 'System Log' },
    { id: 'support', label: 'Support' },
    { id: 'analytics', label: 'Analytics' },
    { id: 'access', label: 'Access Control' },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <header className="bg-gray-800/80 border-b border-gray-700/50 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-amber-500 to-orange-600 rounded-xl flex items-center justify-center"><span className="text-xl">*</span></div>
            <div><h1 className="text-white font-bold text-lg">Owner Dashboard</h1><p className="text-gray-400 text-xs">Platform Management</p></div>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={() => navigate('/owner/dashboard/config')} className="px-4 py-2 bg-cyan-600 text-white rounded-lg hover:bg-cyan-500 text-sm font-medium">Config</button>
            <button onClick={() => { clearSession(); signOutAuth(); navigate('/owner'); }} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg hover:bg-gray-600 text-sm">Logout</button>
          </div>
        </div>
      </header>
      <div className="max-w-7xl mx-auto p-6">
        <div className="flex gap-1 mb-6 bg-gray-800/50 p-1 rounded-xl overflow-x-auto">
          {tabs.map(tab => (
            <button key={tab.id} onClick={() => setActiveTab(tab.id)} className={activeTab === tab.id ? "px-4 py-2 rounded-lg text-sm font-medium bg-amber-500/20 text-amber-400 border border-amber-500/30 whitespace-nowrap" : "px-4 py-2 rounded-lg text-sm font-medium text-gray-400 hover:text-gray-300 whitespace-nowrap"}>{tab.label}</button>
          ))}
        </div>
        {loading ? <div className="text-center py-20 text-gray-400">Loading...</div> : (
          <>
            {/* OVERVIEW TAB */}
            {activeTab === 'overview' && (
              <div className="space-y-6">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  {[
                    { label: 'Total Karyawan', value: stats.total_employees || 0, color: 'blue' },
                    { label: 'Karyawan Aktif', value: stats.active_employees || 0, color: 'green' },
                    { label: 'Modul Aktif', value: (stats.enabled_modules || 0) + '/' + (stats.total_modules || 0), color: 'amber' },
                    { label: 'Business Units', value: stats.total_business_units || 0, color: 'purple' },
                    { label: 'Request Pending', value: stats.pending_requests || 0, color: 'red' },
                    { label: 'Login 24h', value: stats.recent_logins_24h || 0, color: 'cyan' },
                    { label: 'Departemen', value: stats.total_departments || 0, color: 'teal' },
                    { label: 'DB Size', value: stats.db_size || '0', color: 'gray' },
                  ].map((s, i) => (
                    <div key={i} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                      <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                      <div className={`text-2xl font-bold text-${s.color}-400`}>{s.value}</div>
                    </div>
                  ))}
                </div>
                {employeesByBU.length > 0 && (
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h3 className="text-white font-bold text-sm mb-4">Karyawan per Business Unit</h3>
                    <div className="space-y-3">
                      {employeesByBU.map((b, i) => (
                        <div key={i} className="flex items-center gap-4">
                          <div className="w-32 text-gray-300 text-sm">{b.unit_name}</div>
                          <div className="flex-1 bg-gray-700/50 rounded-full h-6 overflow-hidden">
                            <div className="bg-amber-500/60 h-full rounded-full flex items-center px-3" style={{ width: Math.max(10, (b.total_employees / Math.max(...employeesByBU.map(x => x.total_employees), 1)) * 100) + '%' }}>
                              <span className="text-white text-xs font-bold">{b.total_employees}</span>
                            </div>
                          </div>
                          <div className="text-gray-500 text-xs w-16 text-right">{b.active_employees} active</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
            {/* MODULE LOCK TAB */}
            {activeTab === 'modules' && (
              <div className="space-y-6">
                {modules.length === 0 ? <div className="text-gray-400 py-10 text-center">Tidak ada modul</div> : (() => {
                  const industryIcons = { mining: 'Mine', estate: 'Palm', mill: 'Factory' };
                  const industryLabels = { mining: 'Tambang', estate: 'Perkebunan', mill: 'Pabrik' };
                  const groups = {};
                  modules.forEach(m => {
                    const prefix = m.module_code.split('_')[0];
                    const isIndustry = ['mining','estate','mill'].includes(prefix);
                    const groupKey = isIndustry ? 'industry_' + prefix : m.module_group;
                    if (!groups[groupKey]) groups[groupKey] = [];
                    groups[groupKey].push(m);
                  });
                  const order = ['CORE','PLATFORM','GOVERNANCE','industry_mining','industry_estate','industry_mill'];
                  const groupMeta = { CORE: { label: 'Core HR', color: 'blue' }, PLATFORM: { label: 'Platform', color: 'purple' }, GOVERNANCE: { label: 'Governance', color: 'yellow' } };
                  return order.filter(k => groups[k]).map(groupKey => {
                    const isIndustry = groupKey.startsWith('industry_');
                    const prefix = groupKey.replace('industry_','');
                    const meta = isIndustry ? { label: industryLabels[prefix] || prefix, color: 'emerald' } : groupMeta[groupKey] || { label: groupKey, color: 'gray' };
                    return (
                      <div key={groupKey} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                        <div className="flex items-center gap-2 mb-4">
                          <h3 className="text-white font-bold text-sm uppercase tracking-wide">{meta.label}</h3>
                          <span className="text-gray-500 text-xs ml-auto">{groups[groupKey].length} modul</span>
                        </div>
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                          {groups[groupKey].map(m => (
                            <div key={m.module_code} className="flex items-center justify-between bg-gray-900/60 rounded-lg px-4 py-3">
                              <span className="text-gray-200 text-sm">{m.module_name || m.module_code}</span>
                              <button onClick={() => toggleLock(m.module_code, m.is_enabled, m.business_unit_id)} className={m.is_enabled ? "px-3 py-1 rounded-lg text-xs font-bold bg-green-500/20 text-green-400 border border-green-500/30" : "px-3 py-1 rounded-lg text-xs font-bold bg-gray-600/20 text-gray-500 border border-gray-600/30"}>{m.is_enabled ? 'ON' : 'OFF'}</button>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  });
                })()}
              </div>
            )}
            {/* TIER & PRICING TAB */}
            {activeTab === 'tiers' && (
              <div className="space-y-6">
                <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                  <h3 className="text-white font-bold text-sm mb-4">Tier Pricing System</h3>
                  <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
                    {[
                      { t: 0, label: 'Free', color: 'gray', mods: ['Profil','Absensi'] },
                      { t: 1, label: 'Basic', color: 'green', mods: ['+ Cuti','+ Lembur','+ Gaji','+ Self-Service'] },
                      { t: 2, label: 'Pro', color: 'blue', mods: ['+ KPI','+ Kinerja','+ Learning','+ Review 360'] },
                      { t: 3, label: 'Enterprise', color: 'purple', mods: ['+ Talent','+ Recruitment','+ Engagement'] },
                      { t: 4, label: 'Unlimited', color: 'amber', mods: ['+ CEO Dashboard','+ Analytics','+ AI'] },
                    ].map(({ t, label, color, mods }) => (
                      <div key={t} className={'rounded-lg p-3 border border-' + color + '-500/30 bg-' + color + '-500/10'}>
                        <div className="text-white font-bold text-sm">T{t} - {label}</div>
                        <div className="text-gray-400 text-xs mt-2 space-y-1">{mods.map((m, i) => <div key={i}>{m}</div>)}</div>
                      </div>
                    ))}
                  </div>
                </div>
                {businessUnits.length === 0 ? <div className="text-gray-400 py-10 text-center">Tidak ada business unit</div> : businessUnits.map(bu => (
                  <div key={bu.id || bu.bu_id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-center justify-between mb-4">
                      <div><h3 className="text-white font-semibold">{bu.unit_name || bu.id}</h3><p className="text-gray-400 text-xs">Unit code: {bu.unit_code}</p></div>
                      <div className="text-amber-400 font-bold text-lg">Tier {(bu.tier ?? 0)}</div>
                    </div>
                    <div className="flex gap-2 mb-4">
                      {[0,1,2,3,4].map(t => (
                        <button key={t} onClick={() => setTier(bu.id || bu.bu_id, t)} className={(bu.tier ?? 0) === t ? "w-12 h-12 rounded-lg text-sm font-bold bg-amber-500 text-white shadow-lg" : "w-12 h-12 rounded-lg text-sm font-bold bg-gray-700/50 text-gray-400 hover:bg-gray-600/50"}>T{t}</button>
                      ))}
                    </div>
                    <div className="text-xs text-gray-500">
                      {(bu.tier ?? 0) === 0 && <span className="text-red-400">Tier 0 - Profil & Absensi only</span>}
                      {(bu.tier ?? 0) === 1 && <span className="text-green-400">Tier 1 - + Cuti, Lembur, Gaji</span>}
                      {(bu.tier ?? 0) === 2 && <span className="text-blue-400">Tier 2 - + KPI, Learning, Review 360</span>}
                      {(bu.tier ?? 0) === 3 && <span className="text-purple-400">Tier 3 - + Talent, Recruitment</span>}
                      {(bu.tier ?? 0) === 4 && <span className="text-amber-400">Tier 4 - All modules</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
            {/* ROLES TAB */}
            {activeTab === 'roles' && (
              <div className="space-y-4">
                {roles.length === 0 ? <div className="text-gray-400 py-10 text-center">Tidak ada data role</div> : (() => {
                  const byBU = {};
                  roles.forEach(r => { const bu = r.business_unit || 'HQ'; if (!byBU[bu]) byBU[bu] = []; byBU[bu].push(r); });
                  const lc = { 5: 'bg-red-500/20 text-red-400', 4: 'bg-purple-500/20 text-purple-400', 3: 'bg-blue-500/20 text-blue-400', 2: 'bg-green-500/20 text-green-400', 1: 'bg-gray-500/20 text-gray-400' };
                  const ll = { 5: 'C-Suite', 4: 'Director', 3: 'Manager', 2: 'Admin', 1: 'Worker' };
                  const ro = ['admin_pusat','admin_hrd','admin_produksi','admin_finance','manager','supervisor','worker'];
                  return Object.entries(byBU).map(([bu, list]) => (
                    <div key={bu} className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                      <div className="px-5 py-3 border-b border-gray-700/50 flex items-center justify-between">
                        <h3 className="text-white font-bold text-sm">{bu}</h3>
                        <span className="text-gray-500 text-xs">{list.length} karyawan</span>
                      </div>
                      <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                        <th className="px-4 py-2 text-left text-gray-400 text-xs">NRP</th>
                        <th className="px-4 py-2 text-left text-gray-400 text-xs">Nama</th>
                        <th className="px-4 py-2 text-left text-gray-400 text-xs">Role</th>
                        <th className="px-4 py-2 text-left text-gray-400 text-xs">Level</th>
                        <th className="px-4 py-2 text-right"></th>
                      </tr></thead><tbody>
                        {list.sort((a,b) => (b.role_level||1) - (a.role_level||1)).map((r, i) => (
                          <tr key={i} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                            <td className="px-4 py-2 text-white text-sm font-mono">{r.nrp}</td>
                            <td className="px-4 py-2 text-gray-300 text-sm">{r.nama || r.name}</td>
                            <td className="px-4 py-2"><span className="px-2 py-1 bg-amber-500/10 text-amber-400 rounded text-xs">{r.role}</span></td>
                            <td className="px-4 py-2"><span className={'px-2 py-1 rounded text-xs font-bold ' + (lc[r.role_level] || lc[1])}>L{r.role_level} - {ll[r.role_level]}</span></td>
                            <td className="px-4 py-2 text-right"><button onClick={() => { setEditRole(r); setEditForm({ role: r.role, role_level: r.role_level }); }} className="px-3 py-1 rounded text-xs bg-gray-700 text-gray-300 hover:bg-gray-600">Edit</button></td>
                          </tr>
                        ))}
                      </tbody></table>
                    </div>
                  ));
                })()}
                {editRole && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setEditRole(null)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-96" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Edit Role - {editRole.nrp}</h3>
                      <p className="text-gray-400 text-sm mb-4">{editRole.nama}</p>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Role</label>
                          <select value={editForm.role} onChange={e => setEditForm({...editForm, role: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm">
                            {ro.map(r => <option key={r} value={r}>{r}</option>)}
                          </select></div>
                        <div><label className="text-gray-400 text-xs">Level</label>
                          <div className="flex gap-2 mt-1">{[1,2,3,4,5].map(l => (
                            <button key={l} onClick={() => setEditForm({...editForm, role_level: l})} className={'w-10 h-10 rounded-lg text-sm font-bold ' + (parseInt(editForm.role_level) === l ? 'bg-amber-500 text-white' : 'bg-gray-700 text-gray-400 hover:bg-gray-600')}>{l}</button>
                          ))}</div></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setEditRole(null)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={updateRole} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Simpan</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* AUDIT LOG TAB */}
            {activeTab === 'audit' && (
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <select value={auditFilter.action} onChange={e => setAuditFilter({ ...auditFilter, action: e.target.value, page: 0 })} className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm">
                    <option value="">Semua Aksi</option>
                    {auditActions.map(a => <option key={a.action} value={a.action}>{a.action} ({a.count})</option>)}
                  </select>
                  <span className="text-gray-500 text-xs">{auditLog.total} total</span>
                </div>
                <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                  <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Waktu</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Aksi</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Target</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Detail</th>
                  </tr></thead><tbody>
                    {(auditLog.data || []).map((log, i) => (
                      <tr key={i} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                        <td className="px-4 py-2 text-gray-400 text-xs">{new Date(log.created_at).toLocaleString('id-ID')}</td>
                        <td className="px-4 py-2"><span className="px-2 py-1 bg-amber-500/10 text-amber-400 rounded text-xs">{log.action}</span></td>
                        <td className="px-4 py-2 text-gray-300 text-sm">{log.target_type}: {log.target_id}</td>
                        <td className="px-4 py-2 text-gray-500 text-xs max-w-xs truncate">{log.new_value ? JSON.stringify(log.new_value) : '-'}</td>
                      </tr>
                    ))}
                    {(!auditLog.data || auditLog.data.length === 0) && <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-500">Tidak ada log</td></tr>}
                  </tbody></table>
                </div>
                {auditLog.total > 50 && (
                  <div className="flex justify-center gap-2">
                    <button disabled={auditFilter.page === 0} onClick={() => setAuditFilter({ ...auditFilter, page: auditFilter.page - 1 })} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm disabled:opacity-30">Prev</button>
                    <span className="px-4 py-2 text-gray-400 text-sm">Page {auditFilter.page + 1} / {Math.ceil(auditLog.total / 50)}</span>
                    <button disabled={(auditFilter.page + 1) * 50 >= auditLog.total} onClick={() => setAuditFilter({ ...auditFilter, page: auditFilter.page + 1 })} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm disabled:opacity-30">Next</button>
                  </div>
                )}
              </div>
            )}

            {/* SECURITY TAB */}
            {activeTab === 'security' && (
              <div className="space-y-6">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">Login Berhasil (24h)</div>
                    <div className="text-2xl font-bold text-green-400">{loginStats.success_24h || 0}</div>
                  </div>
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">Login Gagal (24h)</div>
                    <div className="text-2xl font-bold text-red-400">{loginStats.failed_24h || 0}</div>
                  </div>
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">Akun Terkunci</div>
                    <div className="text-2xl font-bold text-amber-400">{loginStats.locked_accounts || 0}</div>
                  </div>
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">User Aktif (24h)</div>
                    <div className="text-2xl font-bold text-cyan-400">{loginStats.unique_users_24h || 0}</div>
                  </div>
                </div>
                <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                  <h3 className="text-white font-bold text-sm mb-4">Active Sessions</h3>
                  {sessions.length === 0 ? <div className="text-gray-500 text-sm">Tidak ada session aktif</div> : (
                    <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">NRP</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Nama</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Divisi</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Type</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Login</th>
                      <th className="px-4 py-2 text-right text-gray-400 text-xs">Aksi</th>
                    </tr></thead><tbody>
                      {sessions.map((s, i) => (
                        <tr key={i} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                          <td className="px-4 py-2 text-white text-sm font-mono">{s.nrp}</td>
                          <td className="px-4 py-2 text-gray-300 text-sm">{s.nama || '-'}</td>
                          <td className="px-4 py-2 text-gray-400 text-sm">{s.divisi || '-'}</td>
                          <td className="px-4 py-2"><span className="px-2 py-1 bg-blue-500/10 text-blue-400 rounded text-xs">{s.type}</span></td>
                          <td className="px-4 py-2 text-gray-500 text-xs">{new Date(s.created_at).toLocaleString('id-ID')}</td>
                          <td className="px-4 py-2 text-right">
                            <button onClick={() => forceLogout(s.nrp)} className="px-3 py-1 rounded text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30">Force Logout</button>
                          </td>
                        </tr>
                      ))}
                    </tbody></table>
                  )}
                </div>
                {securitySettings.length > 0 && (
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h3 className="text-white font-bold text-sm mb-4">Security Policy</h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      {securitySettings.map((s, i) => (
                        <div key={i} className="flex items-center justify-between bg-gray-900/60 rounded-lg px-4 py-3">
                          <div><div className="text-gray-200 text-sm">{s.label}</div><div className="text-gray-500 text-xs">{s.description}</div></div>
                          <div className="text-amber-400 font-bold text-sm">{typeof s.config_value === 'object' && s.config_value !== null ? (s.config_value.value !== undefined ? s.config_value.value : JSON.stringify(s.config_value)) : s.config_value}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* BU MANAGEMENT TAB */}
            {activeTab === 'bu' && (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <h3 className="text-white font-bold text-sm">Business Units ({businessUnits.length})</h3>
                  <button onClick={() => setShowBUCreator(true)} className="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">+ Tambah BU</button>
                </div>
                {businessUnits.map(bu => (
                  <div key={bu.id || bu.bu_id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-white font-semibold">{bu.unit_name || bu.id}</h3>
                        <p className="text-gray-400 text-xs">Code: {bu.unit_code} | Tier: {bu.tier ?? 0} | Status: {bu.is_active !== false ? 'Active' : 'Inactive'}</p>
                        {bu.description && <p className="text-gray-500 text-xs mt-1">{bu.description}</p>}
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => { setEditBU(bu); setEditBUForm({ unit_name: bu.unit_name, description: bu.description || '' }); }} className="px-3 py-1 rounded text-xs bg-gray-700 text-gray-300 hover:bg-gray-600">Edit</button>
                        <button onClick={() => deleteBU(bu.id || bu.bu_id)} className="px-3 py-1 rounded text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30">Hapus</button>
                      </div>
                    </div>
                  </div>
                ))}
                {showBUCreator && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowBUCreator(false)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-96" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Tambah Business Unit</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Unit Code</label><input value={newBU.unit_code} onChange={e => setNewBU({...newBU, unit_code: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" placeholder="e.g. MINING" /></div>
                        <div><label className="text-gray-400 text-xs">Unit Name</label><input value={newBU.unit_name} onChange={e => setNewBU({...newBU, unit_name: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" placeholder="e.g. Unit Tambang" /></div>
                        <div><label className="text-gray-400 text-xs">Description</label><input value={newBU.description} onChange={e => setNewBU({...newBU, description: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" placeholder="Optional" /></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setShowBUCreator(false)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={createBU} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Buat</button>
                      </div>
                    </div>
                  </div>
                )}
                {editBU && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setEditBU(null)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-96" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Edit BU - {editBU.id}</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Unit Name</label><input value={editBUForm.unit_name} onChange={e => setEditBUForm({...editBUForm, unit_name: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Description</label><input value={editBUForm.description} onChange={e => setEditBUForm({...editBUForm, description: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setEditBU(null)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={updateBU} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Simpan</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
            {/* EMPLOYEES TAB */}
            {activeTab === 'employees' && (
              <div className="space-y-4">
                <div className="flex items-center gap-3 flex-wrap">
                  <input value={empFilter.search} onChange={e => setEmpFilter({ ...empFilter, search: e.target.value, page: 0 })} placeholder="Search NRP/Nama/Email..." className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm flex-1 min-w-[200px]" />
                  <select value={empFilter.bu} onChange={e => setEmpFilter({ ...empFilter, bu: e.target.value, page: 0 })} className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm">
                    <option value="">Semua BU</option>
                    {businessUnits.map(bu => <option key={bu.id} value={bu.id}>{bu.unit_name}</option>)}
                  </select>
                  <span className="text-gray-500 text-xs">{employees.total} karyawan</span>
                  <button onClick={() => setShowEmpCreator(true)} className="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold ml-auto">+ Tambah</button>
                </div>
                <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                  <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">NRP</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Nama</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Divisi</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Posisi</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">BU</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Status</th>
                    <th className="px-4 py-2 text-right text-gray-400 text-xs">Aksi</th>
                  </tr></thead><tbody>
                    {(employees.data || []).map((emp, i) => (
                      <tr key={i} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                        <td className="px-4 py-2 text-white text-sm font-mono">{emp.nrp}</td>
                        <td className="px-4 py-2 text-gray-300 text-sm">{emp.nama}</td>
                        <td className="px-4 py-2 text-gray-400 text-sm">{emp.divisi || '-'}</td>
                        <td className="px-4 py-2 text-gray-400 text-sm">{emp.posisi || '-'}</td>
                        <td className="px-4 py-2 text-gray-400 text-sm">{emp.unit_name || '-'}</td>
                        <td className="px-4 py-2"><span className={'px-2 py-1 rounded text-xs ' + (emp.status_kerja === 'PKWTT' ? 'bg-green-500/20 text-green-400' : 'bg-gray-500/20 text-gray-400')}>{emp.status_kerja}</span></td>
                        <td className="px-4 py-2 text-right">
                          <button onClick={() => setEditEmp(emp)} className="px-3 py-1 rounded text-xs bg-gray-700 text-gray-300 hover:bg-gray-600 mr-1">Edit</button>
                          <button onClick={async () => { if (confirm('Deactivate ' + emp.nrp + '?')) { await rpc('owner_deactivate_employee', { p_nrp: emp.nrp }); loadEmployees(); } }} className="px-3 py-1 rounded text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30">Off</button>
                        </td>
                      </tr>
                    ))}
                    {(!employees.data || employees.data.length === 0) && <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-500">Tidak ada data</td></tr>}
                  </tbody></table>
                </div>
                {employees.total > 50 && (
                  <div className="flex justify-center gap-2">
                    <button disabled={empFilter.page === 0} onClick={() => setEmpFilter({ ...empFilter, page: empFilter.page - 1 })} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm disabled:opacity-30">Prev</button>
                    <span className="px-4 py-2 text-gray-400 text-sm">Page {empFilter.page + 1} / {Math.ceil(employees.total / 50)}</span>
                    <button disabled={(empFilter.page + 1) * 50 >= employees.total} onClick={() => setEmpFilter({ ...empFilter, page: empFilter.page + 1 })} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm disabled:opacity-30">Next</button>
                  </div>
                )}
                {showEmpCreator && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowEmpCreator(false)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-[500px]" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Tambah Karyawan</h3>
                      <div className="grid grid-cols-2 gap-3">
                        <div><label className="text-gray-400 text-xs">NRP *</label><input value={newEmp.nrp} onChange={e => setNewEmp({...newEmp, nrp: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Nama *</label><input value={newEmp.nama} onChange={e => setNewEmp({...newEmp, nama: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Email</label><input value={newEmp.email} onChange={e => setNewEmp({...newEmp, email: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Divisi</label><input value={newEmp.divisi} onChange={e => setNewEmp({...newEmp, divisi: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Posisi</label><input value={newEmp.posisi} onChange={e => setNewEmp({...newEmp, posisi: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">BU</label><select value={newEmp.bu_id} onChange={e => setNewEmp({...newEmp, bu_id: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="">Pilih BU</option>{businessUnits.map(bu => <option key={bu.id} value={bu.id}>{bu.unit_name}</option>)}</select></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setShowEmpCreator(false)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={async () => { if (!newEmp.nrp || !newEmp.nama) return; await rpc('owner_create_employee', { p_nrp: newEmp.nrp, p_nama: newEmp.nama, p_email: newEmp.email || null, p_divisi: newEmp.divisi || null, p_posisi: newEmp.posisi || null, p_bu_id: newEmp.bu_id || null }); setShowEmpCreator(false); setNewEmp({ nrp: '', nama: '', email: '', divisi: '', posisi: '', bu_id: '', role: 'worker', role_level: 1 }); loadEmployees(); loadOverview(); }} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Buat</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}


            {/* ANNOUNCEMENTS TAB */}
            {activeTab === 'announcements' && (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <h3 className="text-white font-bold text-sm">Pengumuman ({announcements.length})</h3>
                  <button onClick={() => setShowAnnCreator(true)} className="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">+ Tambah</button>
                </div>
                {announcements.length === 0 ? <div className="text-gray-500 text-sm text-center py-10">Belum ada pengumuman</div> : announcements.map(a => (
                  <div key={a.id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          <h3 className="text-white font-semibold">{a.title}</h3>
                          <span className={'px-2 py-0.5 rounded text-xs font-bold ' + (a.priority === 'CRITICAL' ? 'bg-red-500/20 text-red-400' : a.priority === 'HIGH' ? 'bg-amber-500/20 text-amber-400' : 'bg-blue-500/20 text-blue-400')}>{a.priority}</span>
                          <span className="px-2 py-0.5 rounded text-xs bg-gray-700 text-gray-400">{a.target_audience}</span>
                        </div>
                        <p className="text-gray-400 text-sm">{a.message || '-'}</p>
                        <div className="text-gray-500 text-xs mt-2">
                          {new Date(a.created_at).toLocaleString('id-ID')}
                          {a.expiry_date && ' | Expired: ' + new Date(a.expiry_date).toLocaleDateString('id-ID')}
                        </div>
                      </div>
                      <button onClick={async () => { if (confirm('Hapus pengumuman?')) { await rpc('owner_delete_announcement', { p_id: a.id }); loadAnnouncements(); } }} className="px-3 py-1 rounded text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30 ml-2">Hapus</button>
                    </div>
                  </div>
                ))}
                {showAnnCreator && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowAnnCreator(false)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-[500px]" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Buat Pengumuman</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Title *</label><input value={newAnn.title} onChange={e => setNewAnn({...newAnn, title: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Message</label><textarea value={newAnn.message} onChange={e => setNewAnn({...newAnn, message: e.target.value})} rows={3} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div className="grid grid-cols-2 gap-3">
                          <div><label className="text-gray-400 text-xs">Priority</label><select value={newAnn.priority} onChange={e => setNewAnn({...newAnn, priority: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="NORMAL">Normal</option><option value="HIGH">High</option><option value="CRITICAL">Critical</option></select></div>
                          <div><label className="text-gray-400 text-xs">Target</label><select value={newAnn.target_audience} onChange={e => setNewAnn({...newAnn, target_audience: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="ALL">Semua</option><option value="ADMIN">Admin Only</option><option value="WORKER">Worker Only</option></select></div>
                        </div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setShowAnnCreator(false)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={async () => { if (!newAnn.title) return; await rpc('owner_create_announcement', { p_title: newAnn.title, p_message: newAnn.message || null, p_priority: newAnn.priority, p_target_audience: newAnn.target_audience }); setShowAnnCreator(false); setNewAnn({ title: '', message: '', priority: 'NORMAL', target_audience: 'ALL' }); loadAnnouncements(); }} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Buat</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}


            {/* NOTIFICATIONS TAB */}
            {activeTab === 'notifications' && (
              <div className="space-y-4">
                <h3 className="text-white font-bold text-sm">Notification Config ({notifConfig.length})</h3>
                <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                  <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Event</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Label</th>
                    <th className="px-4 py-2 text-center text-gray-400 text-xs">Email</th>
                    <th className="px-4 py-2 text-center text-gray-400 text-xs">Push</th>
                    <th className="px-4 py-2 text-right text-gray-400 text-xs">Aksi</th>
                  </tr></thead><tbody>
                    {notifConfig.map(nc => (
                      <tr key={nc.id} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                        <td className="px-4 py-2 text-white text-sm font-mono">{nc.event_type}</td>
                        <td className="px-4 py-2 text-gray-300 text-sm">{nc.label}</td>
                        <td className="px-4 py-2 text-center">
                          <button onClick={async () => { await rpc('update_notification_config', { p_id: nc.id, p_email_enabled: !nc.email_enabled }); loadNotifConfig(); }} className={'w-10 h-6 rounded-full transition-colors ' + (nc.email_enabled ? 'bg-green-500' : 'bg-gray-600')}>
                            <div className={'w-4 h-4 bg-white rounded-full transition-transform mx-1 ' + (nc.email_enabled ? 'translate-x-4' : 'translate-x-0')} />
                          </button>
                        </td>
                        <td className="px-4 py-2 text-center">
                          <button onClick={async () => { await rpc('update_notification_config', { p_id: nc.id, p_push_enabled: !nc.push_enabled }); loadNotifConfig(); }} className={'w-10 h-6 rounded-full transition-colors ' + (nc.push_enabled ? 'bg-green-500' : 'bg-gray-600')}>
                            <div className={'w-4 h-4 bg-white rounded-full transition-transform mx-1 ' + (nc.push_enabled ? 'translate-x-4' : 'translate-x-0')} />
                          </button>
                        </td>
                        <td className="px-4 py-2 text-right text-gray-500 text-xs">{new Date(nc.updated_at).toLocaleDateString('id-ID')}</td>
                      </tr>
                    ))}
                    {notifConfig.length === 0 && <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">Tidak ada config</td></tr>}
                  </tbody></table>
                </div>
              </div>
            )}

            {/* SYSTEM ANNOUNCEMENTS TAB */}
            {activeTab === 'sysann' && (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <h3 className="text-white font-bold text-sm">System Banner ({sysAnnouncements.length})</h3>
                  <button onClick={() => setShowSysAnnCreator(true)} className="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">+ Tambah Banner</button>
                </div>
                {sysAnnouncements.length === 0 ? <div className="text-gray-500 text-sm text-center py-10">Belum ada system banner</div> : sysAnnouncements.map(sa => (
                  <div key={sa.id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          <h3 className="text-white font-semibold">{sa.title}</h3>
                          <span className={'px-2 py-0.5 rounded text-xs font-bold ' + (sa.type === 'critical' ? 'bg-red-500/20 text-red-400' : sa.type === 'warning' ? 'bg-amber-500/20 text-amber-400' : 'bg-blue-500/20 text-blue-400')}>{sa.type}</span>
                          {sa.dismissible && <span className="px-2 py-0.5 rounded text-xs bg-gray-700 text-gray-400">Dismissible</span>}
                        </div>
                        <p className="text-gray-400 text-sm">{sa.message || '-'}</p>
                        <div className="text-gray-500 text-xs mt-2">
                          {new Date(sa.created_at).toLocaleString('id-ID')}
                          {sa.end_at && ' | End: ' + new Date(sa.end_at).toLocaleString('id-ID')}
                        </div>
                      </div>
                      <button onClick={async () => { if (confirm('Hapus banner?')) { await rpc('owner_delete_system_announcement', { p_id: sa.id }); loadSysAnnouncements(); } }} className="px-3 py-1 rounded text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30 ml-2">Hapus</button>
                    </div>
                  </div>
                ))}
                {showSysAnnCreator && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowSysAnnCreator(false)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-[500px]" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Buat System Banner</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Title *</label><input value={newSysAnn.title} onChange={e => setNewSysAnn({...newSysAnn, title: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Message</label><textarea value={newSysAnn.message} onChange={e => setNewSysAnn({...newSysAnn, message: e.target.value})} rows={3} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div className="grid grid-cols-2 gap-3">
                          <div><label className="text-gray-400 text-xs">Type</label><select value={newSysAnn.type} onChange={e => setNewSysAnn({...newSysAnn, type: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="info">Info</option><option value="warning">Warning</option><option value="critical">Critical</option></select></div>
                          <div><label className="text-gray-400 text-xs">Dismissible</label><button onClick={() => setNewSysAnn({...newSysAnn, dismissible: !newSysAnn.dismissible})} className={'w-full mt-1 px-3 py-2 rounded-lg text-sm border ' + (newSysAnn.dismissible ? 'bg-green-500/20 border-green-500/30 text-green-400' : 'bg-gray-700 border-gray-600 text-gray-400')}>{newSysAnn.dismissible ? 'Ya' : 'Tidak'}</button></div>
                        </div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setShowSysAnnCreator(false)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={async () => { if (!newSysAnn.title) return; await rpc('owner_create_system_announcement', { p_title: newSysAnn.title, p_message: newSysAnn.message || null, p_type: newSysAnn.type, p_dismissible: newSysAnn.dismissible }); setShowSysAnnCreator(false); setNewSysAnn({ title: '', message: '', type: 'info', dismissible: true }); loadSysAnnouncements(); }} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Buat</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}


            {/* ACTIVITY TAB */}
            {activeTab === 'activity' && (
              <div className="space-y-6">
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">Actions Hari Ini</div>
                    <div className="text-2xl font-bold text-blue-400">{activityStats.actions_today || 0}</div>
                  </div>
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">Actions Minggu Ini</div>
                    <div className="text-2xl font-bold text-green-400">{activityStats.actions_week || 0}</div>
                  </div>
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4">
                    <div className="text-gray-400 text-xs mb-1">Tab Aktif</div>
                    <div className="text-2xl font-bold text-amber-400">11</div>
                  </div>
                </div>
                {activityStats.top_actions && activityStats.top_actions.length > 0 && (
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h3 className="text-white font-bold text-sm mb-4">Top Actions (7 hari)</h3>
                    <div className="space-y-2">
                      {activityStats.top_actions.map((a, i) => (
                        <div key={i} className="flex items-center gap-3">
                          <span className="text-gray-400 text-xs w-4">{i + 1}</span>
                          <span className="text-gray-200 text-sm font-mono flex-1">{a.action}</span>
                          <div className="w-32 bg-gray-700/50 rounded-full h-4 overflow-hidden">
                            <div className="bg-amber-500/60 h-full rounded-full" style={{ width: Math.max(10, (a.count / Math.max(...activityStats.top_actions.map(x => x.count), 1)) * 100) + '%' }} />
                          </div>
                          <span className="text-gray-400 text-xs w-8 text-right">{a.count}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* INTEGRATIONS TAB */}
            {activeTab === 'integrations' && (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <h3 className="text-white font-bold text-sm">Integrations ({integrations.length})</h3>
                  <button onClick={() => setShowIntCreator(true)} className="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">+ Tambah</button>
                </div>
                {integrations.length === 0 ? <div className="text-gray-500 text-sm text-center py-10">Belum ada integrasi</div> : integrations.map(intg => (
                  <div key={intg.id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-center justify-between">
                      <div>
                        <div className="flex items-center gap-2">
                          <h3 className="text-white font-semibold">{intg.name}</h3>
                          <span className={'px-2 py-0.5 rounded text-xs ' + (intg.status === 'connected' ? 'bg-green-500/20 text-green-400' : intg.status === 'error' ? 'bg-red-500/20 text-red-400' : 'bg-gray-500/20 text-gray-400')}>{intg.status}</span>
                          <span className="px-2 py-0.5 rounded text-xs bg-gray-700 text-gray-400">{intg.type}</span>
                        </div>
                        <div className="text-gray-500 text-xs mt-1">{new Date(intg.created_at).toLocaleDateString('id-ID')}</div>
                      </div>
                      <button onClick={async () => { if (confirm('Hapus integrasi?')) { await rpc('owner_delete_integration', { p_id: intg.id }); loadIntegrations(); } }} className="px-3 py-1 rounded text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30">Hapus</button>
                    </div>
                  </div>
                ))}
                {showIntCreator && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowIntCreator(false)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-96" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Tambah Integrasi</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Name *</label><input value={newInt.name} onChange={e => setNewInt({...newInt, name: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Type</label><select value={newInt.type} onChange={e => setNewInt({...newInt, type: e.target.value})} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="webhook">Webhook</option><option value="api_key">API Key</option><option value="email">Email</option><option value="sms">SMS</option></select></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setShowIntCreator(false)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={async () => { if (!newInt.name) return; await rpc('owner_create_integration', { p_name: newInt.name, p_type: newInt.type }); setShowIntCreator(false); setNewInt({ name: '', type: 'webhook' }); loadIntegrations(); }} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Buat</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* DATA RETENTION TAB */}
            {activeTab === 'retention' && (
              <div className="space-y-4">
                <h3 className="text-white font-bold text-sm">Data Retention Rules ({retentionRules.length})</h3>
                <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                  <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Table</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Retention (hari)</th>
                    <th className="px-4 py-2 text-center text-gray-400 text-xs">Archive</th>
                    <th className="px-4 py-2 text-left text-gray-400 text-xs">Last Cleanup</th>
                    <th className="px-4 py-2 text-right text-gray-400 text-xs">Aksi</th>
                  </tr></thead><tbody>
                    {retentionRules.map(r => (
                      <tr key={r.id} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                        <td className="px-4 py-2 text-white text-sm font-mono">{r.table_name}</td>
                        <td className="px-4 py-2 text-gray-300 text-sm">{r.retention_days}</td>
                        <td className="px-4 py-2 text-center"><span className={'px-2 py-0.5 rounded text-xs ' + (r.archive_enabled ? 'bg-green-500/20 text-green-400' : 'bg-gray-500/20 text-gray-400')}>{r.archive_enabled ? 'ON' : 'OFF'}</span></td>
                        <td className="px-4 py-2 text-gray-500 text-xs">{r.last_cleanup ? new Date(r.last_cleanup).toLocaleDateString('id-ID') : 'Never'}</td>
                        <td className="px-4 py-2 text-right">
                          <button onClick={async () => { const days = prompt('Retention days:', r.retention_days); if (days) { await rpc('owner_update_retention_rule', { p_id: r.id, p_retention_days: parseInt(days) }); loadRetention(); } }} className="px-3 py-1 rounded text-xs bg-gray-700 text-gray-300 hover:bg-gray-600">Edit</button>
                        </td>
                      </tr>
                    ))}
                  </tbody></table>
                </div>
              </div>
            )}


            {/* SYSTEM LOG TAB */}
            {activeTab === 'changelog' && (
              <div className="space-y-4">
                <h3 className="text-white font-bold text-sm">System Changelog ({changelog.length})</h3>
                {changelog.length === 0 ? <div className="text-gray-500 text-sm text-center py-10">Belum ada changelog</div> : changelog.map(cl => (
                  <div key={cl.id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-center gap-3 mb-2">
                      <span className="px-2 py-0.5 rounded text-xs font-bold bg-amber-500/20 text-amber-400">v{cl.version}</span>
                      <h3 className="text-white font-semibold">{cl.title}</h3>
                    </div>
                    <p className="text-gray-400 text-sm">{cl.description || '-'}</p>
                    <div className="text-gray-500 text-xs mt-2">{new Date(cl.created_at).toLocaleString('id-ID')} by {cl.created_by}</div>
                  </div>
                ))}
              </div>
            )}

            {/* SUPPORT TAB */}
            {activeTab === 'support' && (
              <div className="space-y-4">
                <h3 className="text-white font-bold text-sm">Support Tickets ({tickets.length})</h3>
                {tickets.length === 0 ? <div className="text-gray-500 text-sm text-center py-10">Belum ada ticket</div> : (
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                    <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">ID</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Subject</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Creator</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Priority</th>
                      <th className="px-4 py-2 text-left text-gray-400 text-xs">Status</th>
                      <th className="px-4 py-2 text-right text-gray-400 text-xs">Aksi</th>
                    </tr></thead><tbody>
                      {tickets.map(t => (
                        <tr key={t.id} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                          <td className="px-4 py-2 text-white text-sm font-mono">{t.id.substring(0, 8)}</td>
                          <td className="px-4 py-2 text-gray-300 text-sm">{t.subject}</td>
                          <td className="px-4 py-2 text-gray-400 text-sm">{t.creator_nama || t.creator_nrp}</td>
                          <td className="px-4 py-2"><span className={'px-2 py-0.5 rounded text-xs font-bold ' + (t.priority === 'CRITICAL' ? 'bg-red-500/20 text-red-400' : t.priority === 'HIGH' ? 'bg-amber-500/20 text-amber-400' : 'bg-gray-500/20 text-gray-400')}>{t.priority}</span></td>
                          <td className="px-4 py-2"><span className={'px-2 py-0.5 rounded text-xs ' + (t.status === 'RESOLVED' || t.status === 'CLOSED' ? 'bg-green-500/20 text-green-400' : t.status === 'IN_PROGRESS' ? 'bg-blue-500/20 text-blue-400' : 'bg-gray-500/20 text-gray-400')}>{t.status}</span></td>
                          <td className="px-4 py-2 text-right">
                            <select value={t.status} onChange={async (e) => { await rpc('owner_update_ticket_status', { p_ticket_id: t.id, p_status: e.target.value }); loadTickets(); }} className="px-2 py-1 bg-gray-700 border border-gray-600 rounded text-xs text-white">
                              <option value="OPEN">Open</option><option value="IN_PROGRESS">In Progress</option><option value="RESOLVED">Resolved</option><option value="CLOSED">Closed</option>
                            </select>
                          </td>
                        </tr>
                      ))}
                    </tbody></table>
                  </div>
                )}
              </div>
            )}

            {/* ANALYTICS TAB */}
            {activeTab === 'analytics' && (
              <div className="space-y-6">
                <h3 className="text-white font-bold text-sm">Usage Analytics (30 hari)</h3>
                {usageAnalytics.daily_actions && usageAnalytics.daily_actions.length > 0 && (
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h4 className="text-white font-bold text-xs mb-4">Daily Actions</h4>
                    <div className="flex items-end gap-1 h-32">
                      {usageAnalytics.daily_actions.map((d, i) => {
                        const max = Math.max(...usageAnalytics.daily_actions.map(x => x.count), 1);
                        return <div key={i} className="flex-1 bg-amber-500/60 rounded-t" style={{ height: Math.max(4, (d.count / max) * 100) + '%' }} title={d.date + ': ' + d.count} />;
                      })}
                    </div>
                    <div className="flex justify-between mt-2">
                      <span className="text-gray-500 text-xs">{usageAnalytics.daily_actions[0]?.date}</span>
                      <span className="text-gray-500 text-xs">{usageAnalytics.daily_actions[usageAnalytics.daily_actions.length - 1]?.date}</span>
                    </div>
                  </div>
                )}
                {usageAnalytics.action_distribution && usageAnalytics.action_distribution.length > 0 && (
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h4 className="text-white font-bold text-xs mb-4">Action Distribution</h4>
                    <div className="space-y-2">
                      {usageAnalytics.action_distribution.map((a, i) => {
                        const max = Math.max(...usageAnalytics.action_distribution.map(x => x.count), 1);
                        return (
                          <div key={i} className="flex items-center gap-3">
                            <span className="text-gray-200 text-sm font-mono flex-1 truncate">{a.action}</span>
                            <div className="w-32 bg-gray-700/50 rounded-full h-4 overflow-hidden">
                              <div className="bg-cyan-500/60 h-full rounded-full" style={{ width: Math.max(10, (a.count / max) * 100) + '%' }} />
                            </div>
                            <span className="text-gray-400 text-xs w-8 text-right">{a.count}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
                {(!usageAnalytics.daily_actions || usageAnalytics.daily_actions.length === 0) && (
                  <div className="text-gray-500 text-sm text-center py-10">Belum ada data analytics</div>
                )}
              </div>
            )}

            {/* ACCESS CONTROL TAB */}
            {activeTab === 'access' && (
              <div className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-white font-bold text-sm">Admin Roles ({adminRoles.length})</h3>
                      <button onClick={() => setShowRoleCreator(true)} className="px-3 py-1 bg-amber-500 text-white rounded text-xs font-bold">+ Create Role</button>
                    </div>
                    <div className="space-y-2">
                      {adminRoles.map(r => (
                        <div key={r.id} className="flex items-center justify-between bg-gray-900/60 rounded-lg px-3 py-2">
                          <div>
                            <div className="text-white text-sm font-medium">{r.role_name}</div>
                            <div className="text-gray-500 text-xs">{r.role_code} | {r.scope_type} {r.scope_id}</div>
                          </div>
                          <div className="flex gap-1">
                            <button onClick={() => { setEditRoleAdmin(r); setEditRoleForm({ role_name: r.role_name, permissions: JSON.stringify(r.permissions || []) }); }} className="px-2 py-1 bg-gray-700 text-gray-300 rounded text-xs">Edit</button>
                            <button onClick={() => deleteAdminRole(r.id)} className="px-2 py-1 bg-red-500/20 text-red-400 rounded text-xs">Off</button>
                          </div>
                        </div>
                      ))}
                      {adminRoles.length === 0 && <div className="text-gray-500 text-sm text-center py-4">Tidak ada admin role</div>}
                    </div>
                  </div>
                  <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h3 className="text-white font-bold text-sm mb-4">Assign User to Role</h3>
                    <div className="space-y-3">
                      <div><label className="text-gray-400 text-xs">NRP</label><input value={assignUser.nrp} onChange={e => setAssignUser({ ...assignUser, nrp: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                      <div><label className="text-gray-400 text-xs">Role</label><select value={assignUser.role_code} onChange={e => setAssignUser({ ...assignUser, role_code: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="">Pilih Role</option>{adminRoles.filter(r => r.is_active).map(r => <option key={r.role_code} value={r.role_code}>{r.role_name}</option>)}</select></div>
                      <button onClick={assignAdminUser} className="w-full px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Assign</button>
                    </div>
                    <div className="mt-4">
                      <h4 className="text-white font-bold text-xs mb-2">Admin Accounts ({adminAccounts.length})</h4>
                      <div className="space-y-1">
                        {adminAccounts.map(a => (
                          <div key={a.nrp} className="flex items-center justify-between text-xs">
                            <span className="text-gray-300">{a.nrp} - {a.nama}</span>
                            <span className="text-amber-400">{a.role_code}</span>
                          </div>
                        ))}
                        {adminAccounts.length === 0 && <div className="text-gray-500 text-xs text-center py-2">Tidak ada admin account</div>}
                      </div>
                    </div>
                  </div>
                </div>
                {showRoleCreator && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowRoleCreator(false)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-96" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Create Admin Role</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Role Code *</label><input value={newRole.role_code} onChange={e => setNewRole({ ...newRole, role_code: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Role Name *</label><input value={newRole.role_name} onChange={e => setNewRole({ ...newRole, role_name: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Scope Type</label><select value={newRole.scope_type} onChange={e => setNewRole({ ...newRole, scope_type: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"><option value="global">Global</option><option value="function">Function</option><option value="industry">Industry</option></select></div>
                        <div><label className="text-gray-400 text-xs">Scope ID</label><input value={newRole.scope_id} onChange={e => setNewRole({ ...newRole, scope_id: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" placeholder="e.g. hrd, mining" /></div>
                        <div><label className="text-gray-400 text-xs">Permissions (JSON)</label><textarea value={newRole.permissions} onChange={e => setNewRole({ ...newRole, permissions: e.target.value })} rows={2} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" placeholder='["*"] or ["employees.*"]' /></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setShowRoleCreator(false)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={createAdminRole} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Create</button>
                      </div>
                    </div>
                  </div>
                )}
                {editRoleAdmin && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setEditRoleAdmin(null)}>
                    <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-96" onClick={e => e.stopPropagation()}>
                      <h3 className="text-white font-bold mb-4">Edit Role - {editRoleAdmin.role_code}</h3>
                      <div className="space-y-3">
                        <div><label className="text-gray-400 text-xs">Role Name</label><input value={editRoleForm.role_name} onChange={e => setEditRoleForm({ ...editRoleForm, role_name: e.target.value })} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                        <div><label className="text-gray-400 text-xs">Permissions (JSON)</label><textarea value={editRoleForm.permissions} onChange={e => setEditRoleForm({ ...editRoleForm, permissions: e.target.value })} rows={2} className="w-full mt-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm" /></div>
                      </div>
                      <div className="flex gap-2 mt-6">
                        <button onClick={() => setEditRoleAdmin(null)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
                        <button onClick={updateAdminRole} className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-bold">Update</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

          </>
        )}
      </div>
    </div>
  );
}
