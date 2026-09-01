/**
 * ModuleManagement — Owner-only page
 * Toggle Lock Industry modules + lihat audit log
 */
import React, { useState, useEffect } from 'react';
import { supabase, getSession } from '@/lib/supabase-browser';
import { useCurrentUserContext } from '@/hooks/useModuleAccess';
import { ArrowLeft, Package, Lock, Unlock, History, ToggleLeft, ToggleRight } from 'lucide-react';

export default function ModuleManagement() {
  const { data: ctx, isLoading: ctxLoading } = useCurrentUserContext();
  const [modules, setModules] = useState([]);
  const [auditLog, setAuditLog] = useState([]);
  const [loading, setLoading] = useState(true);
  const [toggling, setToggling] = useState(null);

  useEffect(() => {
    if (!ctx || !ctx.is_owner) return;
    loadData();
  }, [ctx]);

  async function loadData() {
    setLoading(true);
    const { data: mods } = await supabase
      .from('business_unit_modules')
      .select('*, module_definitions(module_name, module_group, is_industry_module), business_units(unit_name, unit_code)')
      .order('module_code');

    const { data: logs } = await supabase
      .from('audit_log_owner')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50);

    setModules(mods || []);
    setAuditLog(logs || []);
    setLoading(false);
  }

  async function toggleLock(moduleCode, currentEnabled) {
    setToggling(moduleCode);
    const { data, error } = await supabase.rpc('owner_toggle_lock', {
      p_module_code: moduleCode,
      p_enable: !currentEnabled,
    });
    if (error) {
      console.error('Toggle error:', error);
    }
    await loadData();
    setToggling(null);
  }

  if (ctxLoading || loading) {
    return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
  }

  if (!ctx?.is_owner) {
    return (
      <div className="p-6 text-center">
        <Lock className="mx-auto mb-4 text-red-500" size={48} />
        <h2 className="text-xl font-bold text-red-600">Akses Ditolak</h2>
        <p className="text-gray-500 mt-2">Hanya Owner yang bisa mengakses halaman ini.</p>
      </div>
    );
  }

  const industryModules = modules.filter(m => m.module_definitions?.is_industry_module);
  const grouped = {};
  industryModules.forEach(m => {
    const bu = m.business_units?.unit_code || 'Unknown';
    if (!grouped[bu]) grouped[bu] = [];
    grouped[bu].push(m);
  });

  return (
    <div className="max-w-6xl mx-auto p-4">
      <div className="flex items-center gap-3 mb-6">
        <a href="/admin" className="p-2 hover:bg-gray-100 rounded-lg"><ArrowLeft size={20} /></a>
        <Package className="text-blue-600" size={24} />
        <div>
          <h1 className="text-xl font-bold">Module Management</h1>
          <p className="text-sm text-gray-500">Toggle Lock Industry modules (Owner only)</p>
        </div>
      </div>

      {/* Industry Module Toggles */}
      {Object.entries(grouped).map(([bu, mods]) => (
        <div key={bu} className="mb-6">
          <h2 className="text-lg font-semibold mb-3 flex items-center gap-2">
            <span className="bg-blue-100 text-blue-800 px-2 py-1 rounded text-sm">{bu}</span>
            Business Unit
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {mods.map(m => {
              const isEnabled = m.is_enabled;
              const isToggling = toggling === m.module_code;
              return (
                <div key={m.id} className={`border rounded-lg p-4 flex items-center justify-between ${isEnabled ? 'bg-green-50 border-green-200' : 'bg-gray-50 border-gray-200'}`}>
                  <div>
                    <p className="font-medium text-sm">{m.module_definitions?.module_name}</p>
                    <p className="text-xs text-gray-500">{m.module_code}</p>
                  </div>
                  <button
                    onClick={() => toggleLock(m.module_code, isEnabled)}
                    disabled={isToggling}
                    className={`p-2 rounded-lg transition ${isEnabled ? 'text-green-600 hover:bg-green-100' : 'text-gray-400 hover:bg-gray-100'}`}
                    title={isEnabled ? 'Klik untuk OFF' : 'Klik untuk ON'}
                  >
                    {isEnabled ? <ToggleRight size={28} /> : <ToggleLeft size={28} />}
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      ))}

      {/* Audit Log */}
      <div className="mt-8">
        <h2 className="text-lg font-semibold mb-3 flex items-center gap-2">
          <History size={20} /> Audit Log Owner
        </h2>
        <div className="border rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left p-3">Waktu</th>
                <th className="text-left p-3">Aksi</th>
                <th className="text-left p-3">Target</th>
                <th className="text-left p-3">Oleh</th>
              </tr>
            </thead>
            <tbody>
              {auditLog.length === 0 ? (
                <tr><td colSpan={4} className="p-4 text-center text-gray-400">Belum ada aktivitas</td></tr>
              ) : auditLog.map(log => (
                <tr key={log.id} className="border-t hover:bg-gray-50">
                  <td className="p-3 text-xs">{new Date(log.created_at).toLocaleString('id-ID')}</td>
                  <td className="p-3"><span className={`px-2 py-1 rounded text-xs font-medium ${log.action === 'TOGGLE_LOCK' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'}`}>{log.action}</span></td>
                  <td className="p-3 text-xs">{log.target_type}: {log.target_id}</td>
                  <td className="p-3 text-xs">{log.owner_nrp}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
