/**
 * ModuleManagement - Owner-only page
 * Tab 1: Module Lock (Industry ON/OFF)
 * Tab 2: Tier Management per Business Unit
 * Tab 3: Role Overview per Business Unit
 */
import React, { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { useCurrentUserContext } from '@/hooks/useModuleAccess';
import { ArrowLeft, Package, Lock, ToggleLeft, ToggleRight, Star, Shield, ChevronDown, ChevronRight } from 'lucide-react';

export default function ModuleManagement() {
  const { data: ctx, isLoading: ctxLoading } = useCurrentUserContext();
  const [modules, setModules] = useState([]);
  const [auditLog, setAuditLog] = useState([]);
  const [businessUnits, setBusinessUnits] = useState([]);
  const [roleStats, setRoleStats] = useState([]);
  const [loading, setLoading] = useState(true);
  const [toggling, setToggling] = useState(null);
  const [tab, setTab] = useState('lock');
  const [collapsed, setCollapsed] = useState({});

  useEffect(() => { if (ctx?.is_owner) loadAllData(); }, [ctx]);

  async function loadAllData() {
    setLoading(true);
    const [mods, logs, bu, roles] = await Promise.all([
      rpc('get_modules_for_owner'),
      rpc('get_audit_log_owner', { p_limit: 50 }),
      rpc('get_business_units_for_owner'),
      rpc('get_role_overview'),
    ]);
    setModules(Array.isArray(mods) ? mods : []);
    setAuditLog(Array.isArray(logs) ? logs : []);
    setBusinessUnits(Array.isArray(bu) ? bu : []);
    setRoleStats(Array.isArray(roles) ? roles : []);
    setLoading(false);
  }

  async function toggleLock(code, enabled) {
    setToggling(code);
    await rpc('owner_toggle_lock', { p_module_code: code, p_enable: !enabled });
    await loadAllData();
    setToggling(null);
  }

  async function setTier(buId, tier) {
    await rpc('owner_set_tier', { p_bu_id: buId, p_tier: tier });
    await loadAllData();
  }

  if (ctxLoading || loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
  if (!ctx?.is_owner) return <div className="p-6 text-center"><Lock className="mx-auto mb-4 text-red-500" size={48} /><h2 className="text-xl font-bold text-red-600">Akses Ditolak</h2><p className="text-gray-500 mt-2">Hanya Owner.</p></div>;

  const industry = modules.filter(m => m.is_industry_module);
  const grouped = {};
  industry.forEach(m => { const b = m.unit_code || 'Unknown'; if (!grouped[b]) grouped[b] = { name: m.unit_name || b, modules: [] }; grouped[b].modules.push(m); });
  const tierL = ['Free','Basic','Standard','Premium','Enterprise'];
  const roleL = ['Staff','Supervisor','Manager','Director','CEO'];

  return (
    <div className="max-w-6xl mx-auto p-4 pb-24">
      <div className="flex items-center gap-3 mb-6">
        <a href="/admin" className="p-2 hover:bg-gray-100 rounded-lg"><ArrowLeft size={20} /></a>
        <Package className="text-blue-600" size={24} />
        <div><h1 className="text-xl font-bold">Owner Control Center</h1><p className="text-sm text-gray-500">Module Lock, Tier & Role Management</p></div>
      </div>
      <div className="flex gap-1 mb-6 bg-gray-100 rounded-lg p-1">
        {[{k:'lock',i:<Lock size={16}/>,l:'Module Lock'},{k:'tier',i:<Star size={16}/>,l:'Tier & Pricing'},{k:'role',i:<Shield size={16}/>,l:'Role Overview'}].map(t=>(
          <button key={t.k} onClick={()=>setTab(t.k)} className={"flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-md text-sm font-medium transition "+(tab===t.k?'bg-white shadow text-blue-700':'text-gray-500 hover:text-gray-700')}>{t.i} {t.l}</button>
        ))}
      </div>
      {tab==='lock' && Object.entries(grouped).map(([bu,{name,modules:mods}])=>(
        <div key={bu} className="mb-6">
          <div className="flex items-center gap-2 mb-3 text-lg font-semibold">
            <span className="bg-blue-100 text-blue-800 px-2 py-1 rounded text-sm">{bu}</span> {name} <span className="text-xs text-gray-400">({mods.length})</span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {mods.map(m=>(
              <div key={m.module_code} className={"border rounded-lg p-4 flex items-center justify-between "+(m.is_enabled?'bg-green-50 border-green-200':'bg-gray-50 border-gray-200')}>
                <div><p className="font-medium text-sm">{m.module_name}</p><p className="text-xs text-gray-500">{m.module_code}</p></div>
                <button onClick={()=>toggleLock(m.module_code,m.is_enabled)} disabled={toggling===m.module_code} className={"p-2 rounded-lg transition "+(m.is_enabled?'text-green-600 hover:bg-green-100':'text-gray-400 hover:bg-gray-100')}>
                  {m.is_enabled?<ToggleRight size={28}/>:<ToggleLeft size={28}/>}
                </button>
              </div>
            ))}
          </div>
        </div>
      ))}
      {tab==='tier' && <div><p className="text-sm text-gray-500 mb-4">Tier 0=Profile, 4=Enterprise.</p><div className="grid grid-cols-1 sm:grid-cols-2 gap-4">{businessUnits.map(bu=>(
        <div key={bu.id} className="border rounded-lg p-4 bg-white">
          <div className="flex items-center justify-between mb-3"><p className="font-semibold">{bu.unit_name||bu.id}</p><span className={"px-2 py-1 rounded text-xs font-medium "+((bu.tier||0)>=4?'bg-purple-100 text-purple-800':'bg-gray-100 text-gray-600')}>Tier {bu.tier||0}: {tierL[bu.tier||0]}</span></div>
          <div className="flex gap-1">{[0,1,2,3,4].map(t=><button key={t} onClick={()=>setTier(bu.id,t)} className={"flex-1 py-2 rounded text-xs font-medium transition "+((bu.tier||0)===t?'bg-blue-600 text-white':'bg-gray-100 text-gray-600 hover:bg-gray-200')}>T{t}</button>)}</div>
        </div>
      ))}</div></div>}
      {tab==='role' && <div><p className="text-sm text-gray-500 mb-4">1=Staff, 2=Supervisor, 3=Manager, 4=Director, 5=CEO</p><div className="grid grid-cols-1 sm:grid-cols-2 gap-4">{businessUnits.map(bu=>{const br=roleStats.filter(r=>r.business_unit_id===bu.id);return(
        <div key={bu.id} className="border rounded-lg p-4 bg-white"><p className="font-semibold mb-3">{bu.unit_name||bu.id}</p><div className="space-y-2">{roleL.map((l,i)=>{const c=br.find(r=>r.role_level===i+1)?.count||0;return(
          <div key={i} className="flex items-center justify-between"><div className="flex items-center gap-2"><div className={"w-3 h-3 rounded-full "+(i>=4?'bg-purple-500':i>=3?'bg-blue-500':i>=2?'bg-green-500':i>=1?'bg-yellow-500':'bg-gray-400')}/><span className="text-sm">L{i+1}: {l}</span></div><span className="text-sm font-medium">{c}</span></div>
        );})}</div></div>
      );})}</div></div>}
    </div>
  );
}