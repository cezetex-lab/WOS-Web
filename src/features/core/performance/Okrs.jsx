// ============================================================
// Okrs.jsx — #44 OKRs (Objectives & Key Results)
// RPC: get_my_okrs, create_okr, add_okr_result, admin_get_okr
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, Input, StatItem, Divider
} from '../../../lib/design-system';

// Inline Modal
function Modal({ onClose, title, children }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4" onClick={onClose}>
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md max-h-[80vh] overflow-y-auto p-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-white font-semibold text-sm">{title}</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-white text-lg">✕</button>
        </div>
        {children}
      </div>
    </div>
  );
}

const STATUS_COLORS = {
  on_track: 'green', at_risk: 'yellow', behind: 'red', draft: 'slate', completed: 'blue'
};
const STATUS_LABELS = {
  on_track: '✅ On Track', at_risk: '⚠️ At Risk', behind: '🔴 Behind', draft: '📝 Draft', completed: '🎯 Completed'
};

export default function Okrs() {
  const nrp = getSession()?.nrp;
  const role = getSession()?.role;
  const [loading, setLoading] = useState(true);
  const [okrs, setOkrs] = useState([]);
  const [adminOkrs, setAdminOkrs] = useState([]);
  const [tab, setTab] = useState('my');
  const [showCreate, setShowCreate] = useState(false);
  const [newObjective, setNewObjective] = useState('');
  const [newPeriod, setNewPeriod] = useState(getCurrentPeriod());
  const [newKr, setNewKr] = useState('');
  const [newTarget, setNewTarget] = useState('');
  const [newUnit, setNewUnit] = useState('pts');
  const [selectedOkr, setSelectedOkr] = useState(null);
  const [krList, setKrList] = useState([]);

  function getCurrentPeriod() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  }

  const fetchMyOkrs = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await supabase.rpc('get_my_okrs', { p_nrp: nrp });
      if (data?.ok) setOkrs(data.data || []);
    } catch (e) { }
    setLoading(false);
  }, [nrp]);

  const fetchAdminOkrs = useCallback(async () => {
    try {
      const { data } = await supabase.rpc('admin_get_okr');
      if (data?.ok) setAdminOkrs(data.data || []);
    } catch (e) { }
  }, []);

  useEffect(() => { fetchMyOkrs(); if (role === 'admin') fetchAdminOkrs(); }, [fetchMyOkrs, fetchAdminOkrs, role]);

  const createOkr = async () => {
    if (!newObjective.trim()) return;
    try {
      const { data } = await supabase.rpc('create_okr', {
        p_nrp: nrp, p_periode: newPeriod, p_objective: newObjective
      });
      if (data?.ok && data.id) {
        // Add key results
        for (const kr of krList) {
          await supabase.rpc('add_okr_result', {
            p_okr_id: data.id, p_kr: kr.kr, p_target: parseFloat(kr.target), p_unit: kr.unit
          });
        }
        setShowCreate(false);
        setNewObjective('');
        setKrList([]);
        fetchMyOkrs();
      }
    } catch (e) { }
  };

  const addKrToList = () => {
    if (!newKr.trim() || !newTarget) return;
    setKrList([...krList, { kr: newKr, target: newTarget, unit: newUnit }]);
    setNewKr('');
    setNewTarget('');
  };

  const removeKr = (idx) => setKrList(krList.filter((_, i) => i !== idx));

  const tabs = role === 'admin'
    ? [{ key: 'my', label: '🎯 OKR Saya' }, { key: 'all', label: '📊 Semua OKR' }]
    : [{ key: 'my', label: '🎯 OKR Saya' }];

  return (
    <PageLayout title="🎯 OKRs — Objectives & Key Results">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {tab === 'my' && (
          <>
            <Button onClick={() => setShowCreate(true)} className="w-full">
              ➕ Buat OKR Baru
            </Button>

            {loading ? <LoadingSpinner /> : okrs.length === 0 ? (
              <EmptyState icon="🎯" title="Belum ada OKR" subtitle="Buat OKR pertama untuk mulai tracking goal" />
            ) : (
              <div className="space-y-3">
                {okrs.map((okr) => (
                  <GlassCard key={okr.id} className="p-4">
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <p className="text-white font-semibold text-sm">{okr.objective}</p>
                        <p className="text-slate-400 text-xs mt-1">📅 {okr.periode} · <Badge color={STATUS_COLORS[okr.status]}>{STATUS_LABELS[okr.status] || okr.status}</Badge></p>
                      </div>
                    </div>
                    {okr.key_results && okr.key_results.length > 0 && (
                      <div className="mt-3 space-y-2">
                        {okr.key_results.map((kr, idx) => (
                          <div key={idx} className="bg-slate-800/50 rounded-lg p-3">
                            <div className="flex items-center justify-between mb-1">
                              <span className="text-slate-300 text-xs">{kr.kr}</span>
                              <span className="text-xs font-mono text-white">{kr.pct || 0}%</span>
                            </div>
                            <div className="w-full bg-slate-700 rounded-full h-2">
                              <div
                                className={`h-2 rounded-full ${(kr.pct || 0) >= 80 ? 'bg-green-500' : (kr.pct || 0) >= 50 ? 'bg-yellow-500' : 'bg-red-500'}`}
                                style={{ width: `${Math.min(100, kr.pct || 0)}%` }}
                              />
                            </div>
                            <p className="text-slate-500 text-xs mt-1">Actual: {kr.actual || 0} / Target: {kr.target} {kr.unit}</p>
                          </div>
                        ))}
                      </div>
                    )}
                  </GlassCard>
                ))}
              </div>
            )}
          </>
        )}

        {tab === 'all' && (
          <div className="space-y-3">
            {adminOkrs.length === 0 ? (
              <EmptyState icon="📊" title="Belum ada data OKR" subtitle="OKR akan muncul setelah karyawan membuat" />
            ) : (
              adminOkrs.map((okr) => (
                <GlassCard key={okr.id} className="p-3">
                  <p className="text-white text-sm font-medium">{okr.indicator || okr.objective || '-'}</p>
                  <p className="text-slate-400 text-xs">Target: {okr.target_value} {okr.uom} · Weight: {okr.weight}%</p>
                </GlassCard>
              ))
            )}
          </div>
        )}
      </div>

      {/* Create OKR Modal */}
      {showCreate && (
        <Modal onClose={() => setShowCreate(false)} title="➕ Buat OKR Baru">
          <div className="space-y-3">
            <Input label="Objective" value={newObjective} onChange={setNewObjective} placeholder="Contoh: Meningkatkan produktivitas tim" />
            <Input label="Periode" value={newPeriod} onChange={setNewPeriod} placeholder="YYYY-MM" />
            
            <Divider />
            <p className="text-slate-300 text-xs font-semibold">Key Results:</p>
            {krList.map((kr, idx) => (
              <div key={idx} className="flex items-center gap-2 bg-slate-800/50 rounded p-2">
                <span className="text-white text-xs flex-1">{kr.kr}</span>
                <span className="text-slate-400 text-xs">{kr.target} {kr.unit}</span>
                <button onClick={() => removeKr(idx)} className="text-red-400 text-xs">✕</button>
              </div>
            ))}
            <div className="flex gap-2">
              <Input label="" value={newKr} onChange={setNewKr} placeholder="Key Result" className="flex-1" />
              <Input label="" value={newTarget} onChange={setNewTarget} placeholder="Target" className="w-20" />
              <Input label="" value={newUnit} onChange={setNewUnit} placeholder="Unit" className="w-16" />
              <Button onClick={addKrToList} variant="secondary" className="mt-1">+</Button>
            </div>
            
            <Button onClick={createOkr} className="w-full">💾 Simpan OKR</Button>
          </div>
        </Modal>
      )}
    </PageLayout>
  );
}
