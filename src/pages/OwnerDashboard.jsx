import { useState, useEffect } from 'react';
import { rpc, clearSession } from '@/lib/supabase-browser';
import { useNavigate } from 'react-router-dom';

export default function OwnerDashboard() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('modules');
  const [modules, setModules] = useState([]);
  const [businessUnits, setBusinessUnits] = useState([]);
  const [roles, setRoles] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const [modRes, buRes, roleRes] = await Promise.all([
        rpc('get_modules_for_owner'),
        rpc('get_business_units_for_owner'),
        rpc('get_role_overview'),
      ]);
      setModules(Array.isArray(modRes) ? modRes : []);
      setBusinessUnits(Array.isArray(buRes) ? buRes : []);
      setRoles(Array.isArray(roleRes) ? roleRes : []);
    } catch (e) { /* silent */ }
    setLoading(false);
  }

  async function toggleLock(code, current) {
    await rpc('owner_toggle_lock', { p_module_code: code, p_enable: !current });
    loadData();
  }

  async function setTier(buId, tier) {
    await rpc('owner_set_tier', { p_bu_id: buId, p_tier: tier });
    loadData();
  }

  const tabs = [
    { id: 'modules', label: 'Module Lock' },
    { id: 'tiers', label: 'Tier & Pricing' },
    { id: 'roles', label: 'Role Overview' },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <header className="bg-gray-800/80 border-b border-gray-700/50 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-amber-500 to-orange-600 rounded-xl flex items-center justify-center"><span className="text-xl">⚙️</span></div>
            <div><h1 className="text-white font-bold text-lg">Owner Dashboard</h1><p className="text-gray-400 text-xs">Platform Management</p></div>
          </div>
          <button onClick={() => { clearSession(); navigate('/owner'); }} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg hover:bg-gray-600 text-sm">Logout</button>
        </div>
      </header>
      <div className="max-w-7xl mx-auto p-6">
        <div className="flex gap-1 mb-6 bg-gray-800/50 p-1 rounded-xl w-fit">
          {tabs.map(tab => (
            <button key={tab.id} onClick={() => setActiveTab(tab.id)} className={activeTab === tab.id ? "px-4 py-2 rounded-lg text-sm font-medium bg-amber-500/20 text-amber-400 border border-amber-500/30" : "px-4 py-2 rounded-lg text-sm font-medium text-gray-400 hover:text-gray-300"}>{tab.label}</button>
          ))}
        </div>
        {loading ? <div className="text-center py-20 text-gray-400">Loading...</div> : (
          <>
            {activeTab === 'modules' && (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {modules.length === 0 ? <div className="text-gray-400 py-10 col-span-full text-center">Tidak ada modul</div> : modules.map(m => (
                  <div key={m.module_code} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <div className="flex items-center justify-between">
                      <div><h3 className="text-white font-semibold">{m.module_name || m.module_code}</h3><p className="text-gray-400 text-xs mt-1">{m.description || 'Industry module'}</p></div>
                      <button onClick={() => toggleLock(m.module_code, m.is_enabled)} className={m.is_enabled ? "px-4 py-2 rounded-lg text-sm font-bold bg-green-500/20 text-green-400 border border-green-500/30" : "px-4 py-2 rounded-lg text-sm font-bold bg-gray-600/20 text-gray-500 border border-gray-600/30"}>{m.is_enabled ? 'ON' : 'OFF'}</button>
                    </div>
                  </div>
                ))}
              </div>
            )}
            {activeTab === 'tiers' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {businessUnits.length === 0 ? <div className="text-gray-400 py-10 col-span-full text-center">Tidak ada business unit</div> : businessUnits.map(bu => (
                  <div key={bu.id || bu.bu_id} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5">
                    <h3 className="text-white font-semibold mb-3">{bu.name || bu.unit_name || bu.id}</h3>
                    <div className="flex gap-2">
                      {[0,1,2,3,4].map(t => (
                        <button key={t} onClick={() => setTier(bu.id || bu.bu_id, t)} className={(bu.tier || 0) === t ? "w-12 h-12 rounded-lg text-sm font-bold bg-amber-500 text-white shadow-lg" : "w-12 h-12 rounded-lg text-sm font-bold bg-gray-700/50 text-gray-400 hover:bg-gray-600/50"}>T{t}</button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
            {activeTab === 'roles' && (
              <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                {roles.length === 0 ? <div className="text-gray-400 py-10 text-center">Tidak ada data role</div> : (
                  <table className="w-full"><thead><tr className="border-b border-gray-700/50">
                    <th className="px-4 py-3 text-left text-gray-400 text-sm">NRP</th>
                    <th className="px-4 py-3 text-left text-gray-400 text-sm">Nama</th>
                    <th className="px-4 py-3 text-left text-gray-400 text-sm">Role</th>
                    <th className="px-4 py-3 text-left text-gray-400 text-sm">Level</th>
                  </tr></thead><tbody>
                    {roles.map((r, i) => (<tr key={i} className="border-b border-gray-700/30 hover:bg-gray-700/20">
                      <td className="px-4 py-3 text-white text-sm">{r.nrp}</td>
                      <td className="px-4 py-3 text-gray-300 text-sm">{r.nama || r.name}</td>
                      <td className="px-4 py-3"><span className="px-2 py-1 bg-amber-500/10 text-amber-400 rounded text-xs">{r.role}</span></td>
                      <td className="px-4 py-3 text-gray-300 text-sm">L{r.role_level || 1}</td>
                    </tr>))}
                  </tbody></table>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
