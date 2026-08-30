// ============================================================
// Offboarding.jsx — #135-138 Offboarding Workflow
// RPC: admin_get_exit_interviews, admin_get_settlements, get_offboarding_checklist
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, Input, StatItem, Divider
} from '../../lib/design-system';

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

const CHECKLIST_ITEMS = [
  { key: 'asset', label: '📦 Pengembalian Aset', icon: '📦' },
  { key: 'access', label: '🔑 Nonaktifkan Akses Sistem', icon: '🔑' },
  { key: 'finance', label: '💰 Final Settlement', icon: '💰' },
  { key: 'knowledge', label: '📚 Knowledge Transfer', icon: '📚' },
  { key: 'hr', label: '📋 Serah Terima HR', icon: '📋' },
  { key: 'it', label: '💻 Serah Terima IT', icon: '💻' },
  { key: 'exit_interview', label: '🎤 Exit Interview', icon: '🎤' },
];

const STATUS_COLORS = { pending: 'yellow', completed: 'green', in_progress: 'blue' };

export default function Offboarding() {
  const [loading, setLoading] = useState(true);
  const [exitInterviews, setExitInterviews] = useState([]);
  const [settlements, setSettlements] = useState([]);
  const [tab, setTab] = useState('overview');
  const [selectedEmp, setSelectedEmp] = useState(null);
  const [checklist, setChecklist] = useState({});
  const [showDetail, setShowDetail] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const { data: ei } = await supabase.rpc('admin_get_exit_interviews');
      if (ei?.ok) setExitInterviews(ei.data || []);
      const { data: st } = await supabase.rpc('admin_get_settlements');
      if (st?.ok) setSettlements(st.data || []);
    } catch (e) { console.warn('Offboarding fetch error:', e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const fetchChecklist = async (nrp) => {
    try {
      const { data } = await supabase.rpc('get_offboarding_checklist', { p_nrp: nrp });
      if (data?.ok) {
        const map = {};
        (data.data || []).forEach(item => { map[item.step] = item.status; });
        setChecklist(map);
      }
    } catch (e) { console.warn('Checklist fetch error:', e); }
  };

  const handleShowDetail = async (emp) => {
    setSelectedEmp(emp);
    await fetchChecklist(emp.nrp);
    setShowDetail(true);
  };

  const completedCount = Object.values(checklist).filter(s => s === 'completed').length;
  const totalCount = CHECKLIST_ITEMS.length;
  const progress = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  const tabs = [
    { key: 'overview', label: '📊 Overview' },
    { key: 'exit', label: '🎤 Exit Interview' },
    { key: 'settlement', label: '💰 Settlement' },
    { key: 'checklist', label: '✅ Checklist' },
  ];

  return (
    <PageLayout title="🚪 Offboarding">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {/* Stats */}
        <div className="grid grid-cols-2 gap-3">
          <StatItem label="Exit Interviews" value={exitInterviews.length} />
          <StatItem label="Settlements" value={settlements.length} />
        </div>

        {tab === 'overview' && (
          <>
            {loading ? <LoadingSpinner /> : (
              <div className="space-y-3">
                {exitInterviews.length === 0 && settlements.length === 0 ? (
                  <EmptyState icon="🚪" title="Belum ada proses offboarding" subtitle="Data akan muncul ketika ada karyawan yang resign" />
                ) : (
                  <>
                    {exitInterviews.map((e, idx) => (
                      <GlassCard key={idx} className="p-3 cursor-pointer" onClick={() => handleShowDetail(e)}>
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="text-white text-sm font-medium">{e.nama || e.nrp}</p>
                            <p className="text-slate-400 text-xs">Alasan: {e.reason || e.alasan || '-'}</p>
                          </div>
                          <Badge color="blue">🎤 Interview</Badge>
                        </div>
                      </GlassCard>
                    ))}
                    {settlements.map((s, idx) => (
                      <GlassCard key={`s${idx}`} className="p-3">
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="text-white text-sm font-medium">{s.nama || s.nrp}</p>
                            <p className="text-slate-400 text-xs">Total: Rp {(s.total_settlement || s.amount || 0).toLocaleString('id-ID')}</p>
                          </div>
                          <Badge color={s.status === 'completed' ? 'green' : 'yellow'}>{s.status || 'pending'}</Badge>
                        </div>
                      </GlassCard>
                    ))}
                  </>
                )}
              </div>
            )}
          </>
        )}

        {tab === 'exit' && (
          loading ? <LoadingSpinner /> : exitInterviews.length === 0 ? (
            <EmptyState icon="🎤" title="Belum ada exit interview" subtitle="Exit interview akan tercatat di sini" />
          ) : (
            <div className="space-y-2">
              {exitInterviews.map((e, idx) => (
                <GlassCard key={idx} className="p-3">
                  <p className="text-white text-sm font-medium">{e.nama || e.nrp}</p>
                  <p className="text-slate-400 text-xs mt-1">Alasan: {e.reason || e.alasan || '-'}</p>
                  <p className="text-slate-400 text-xs">Tanggal: {e.date || e.tanggal || '-'}</p>
                  {e.feedback && <p className="text-slate-300 text-xs mt-2 italic">"{e.feedback}"</p>}
                </GlassCard>
              ))}
            </div>
          )
        )}

        {tab === 'settlement' && (
          loading ? <LoadingSpinner /> : settlements.length === 0 ? (
            <EmptyState icon="💰" title="Belum ada settlement" subtitle="Final settlement akan tercatat di sini" />
          ) : (
            <div className="space-y-2">
              {settlements.map((s, idx) => (
                <GlassCard key={idx} className="p-3">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-white text-sm font-medium">{s.nama || s.nrp}</p>
                    <Badge color={s.status === 'completed' ? 'green' : 'yellow'}>{s.status || 'pending'}</Badge>
                  </div>
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <p className="text-slate-400">Gaji Pokok: <span className="text-white">Rp {(s.basic_salary || 0).toLocaleString('id-ID')}</span></p>
                    <p className="text-slate-400">Pesangon: <span className="text-white">Rp {(s.severance || 0).toLocaleString('id-ID')}</span></p>
                    <p className="text-slate-400">Cuti Belum: <span className="text-white">Rp {(s.leave_pay || 0).toLocaleString('id-ID')}</span></p>
                    <p className="text-slate-400 font-semibold">Total: <span className="text-green-400">Rp {(s.total_settlement || s.amount || 0).toLocaleString('id-ID')}</span></p>
                  </div>
                </GlassCard>
              ))}
            </div>
          )
        )}

        {tab === 'checklist' && (
          <EmptyState icon="✅" title="Pilih karyawan dari Overview" subtitle="Checklist offboarding akan muncul di sini" />
        )}
      </div>

      {/* Detail Modal */}
      {showDetail && selectedEmp && (
        <Modal onClose={() => setShowDetail(null)} title={`🚪 Offboarding: ${selectedEmp.nama || selectedEmp.nrp}`}>
          <div className="space-y-3">
            <div className="bg-slate-800/50 rounded-lg p-3 text-center">
              <p className="text-2xl font-bold text-white">{progress}%</p>
              <p className="text-xs text-slate-400">Progress Offboarding</p>
              <div className="w-full bg-slate-700 rounded-full h-2 mt-2">
                <div className="bg-green-500 h-2 rounded-full" style={{ width: `${progress}%` }} />
              </div>
              <p className="text-xs text-slate-400 mt-1">{completedCount}/{totalCount} selesai</p>
            </div>
            
            {CHECKLIST_ITEMS.map((item) => (
              <div key={item.key} className="flex items-center justify-between bg-slate-800/30 rounded-lg p-3">
                <span className="text-white text-sm">{item.icon} {item.label}</span>
                <Badge color={STATUS_COLORS[checklist[item.key]] || 'slate'}>
                  {checklist[item.key] === 'completed' ? '✅ Selesai' : checklist[item.key] === 'in_progress' ? '🔄 Proses' : '⏳ Pending'}
                </Badge>
              </div>
            ))}
          </div>
        </Modal>
      )}
    </PageLayout>
  );
}
