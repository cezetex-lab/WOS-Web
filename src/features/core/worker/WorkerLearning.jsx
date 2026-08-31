// ============================================================
// WorkerLearning.jsx — Custom Worker Learning Page
// RPC: get_worker_learning(p_nrp)
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, MetricCard, GlassCard, Badge, LoadingSpinner, EmptyState, Button, Tabs
} from '../../../lib/design-system';

const TYPE_CONFIG = {
  Training:     { icon: '🎓', color: 'blue', label: 'Training' },
  Certification:{ icon: '📜', color: 'teal', label: 'Sertifikasi' },
  Workshop:     { icon: '🛠️', color: 'orange', label: 'Workshop' },
  Course:       { icon: '📚', color: 'purple', label: 'Kursus' },
  default:      { icon: '📖', color: 'slate', label: 'Lainnya' },
};

const STATUS_CONFIG = {
  completed:    { icon: '✅', color: 'success', label: 'Selesai' },
  in_progress:  { icon: '🔄', color: 'warning', label: 'Berlangsung' },
  enrolled:     { icon: '📝', color: 'info', label: 'Terdaftar' },
  cancelled:    { icon: '❌', color: 'danger', label: 'Dibatalkan' },
};

export default function WorkerLearning() {
  const nrp = JSON.parse(sessionStorage.getItem('wos_user') || '{}')?.nrp;
  const [loading, setLoading] = useState(true);
  const [learning, setLearning] = useState([]);
  const [activeTab, setActiveTab] = useState('all');

  const fetchLearning = useCallback(async () => {
    if (!nrp) { setLoading(false); return; }
    setLoading(true);
    try {
      const result = await rpc('get_worker_learning', { p_nrp: nrp });
      const data = Array.isArray(result) ? result
        : result?.data && Array.isArray(result.data) ? result.data : [];
      setLearning(data);
    } catch (err) { console.error('Failed to load learning:', err); }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchLearning(); }, [fetchLearning]);

  // ── STATS ──
  const totalPrograms = learning.length;
  const completed = learning.filter(l => (l.status || '').toLowerCase() === 'completed').length;
  const inProgress = learning.filter(l => (l.status || '').toLowerCase() === 'in_progress').length;
  const enrolled = learning.filter(l => (l.status || '').toLowerCase() === 'enrolled').length;

  const statCards = [
    { icon: '📚', value: totalPrograms, label: 'Total', trend: 'Semua program', color: 'blue' },
    { icon: '✅', value: completed, label: 'Selesai', trend: `${totalPrograms > 0 ? ((completed / totalPrograms) * 100).toFixed(0) : 0}%`, color: 'green' },
    { icon: '🔄', value: inProgress, label: 'Berlangsung', trend: 'Aktif', color: 'orange' },
    { icon: '📝', value: enrolled, label: 'Terdaftar', trend: 'Belum mulai', color: 'teal' },
  ];

  // ── FILTER ──
  const filtered = learning.filter(l => {
    if (activeTab === 'all') return true;
    return (l.status || '').toLowerCase() === activeTab;
  });

  const getProgress = (item) => {
    if ((item.status || '').toLowerCase() === 'completed') return 100;
    if ((item.status || '').toLowerCase() === 'in_progress') return 60;
    if ((item.status || '').toLowerCase() === 'enrolled') return 20;
    return 0;
  };

  if (loading) {
    return (
      <PageLayout backTo="/worker" title="Learning">
        <LoadingSpinner text="Memuat data learning..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/worker" title="Learning & Training" subtitle={`${totalPrograms} program terdaftar`}>
      {/* ── STATS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>

      {/* ── TABS ── */}
      <div className="mb-4">
        <Tabs
          tabs={[
            { id: 'all', label: 'Semua', count: totalPrograms },
            { id: 'completed', label: 'Selesai', count: completed },
            { id: 'in_progress', label: 'Berlangsung', count: inProgress },
            { id: 'enrolled', label: 'Terdaftar', count: enrolled },
          ]}
          active={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* ── LEARNING CARDS ── */}
      {filtered.length === 0 ? (
        <EmptyState
          title="Belum ada program"
          description="Anda belum terdaftar di program learning apapun"
        />
      ) : (
        <div className="space-y-3">
          {filtered.map((item, i) => {
            const typeConfig = TYPE_CONFIG[item.type] || TYPE_CONFIG.default;
            const statusConfig = STATUS_CONFIG[(item.status || '').toLowerCase()] || STATUS_CONFIG.enrolled;
            const progress = getProgress(item);

            return (
              <GlassCard key={item.id || i} accent={typeConfig.color}>
                <div className="flex items-start gap-3">
                  <span className="text-2xl">{typeConfig.icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-sm font-bold text-white truncate">{item.title || 'Tanpa judul'}</h3>
                      <Badge status={statusConfig.label} type={statusConfig.color} />
                    </div>
                    <div className="flex items-center gap-3 text-[10px] text-slate-500">
                      <span>{typeConfig.label}</span>
                      {item.start_date && <span>Mulai: {new Date(item.start_date).toLocaleDateString('id-ID')}</span>}
                      {item.end_date && <span>Selesai: {new Date(item.end_date).toLocaleDateString('id-ID')}</span>}
                    </div>

                    {/* Progress Bar */}
                    <div className="mt-2">
                      <div className="flex justify-between text-[10px] mb-1">
                        <span className="text-slate-400">Progress</span>
                        <span className="text-white font-semibold">{progress}%</span>
                      </div>
                      <div className="w-full h-1.5 bg-slate-700/50 rounded-full overflow-hidden">
                        <div
                          className="h-full rounded-full transition-all bg-gradient-to-r from-sky-500 to-teal-500"
                          style={{ width: `${progress}%` }}
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </GlassCard>
            );
          })}
        </div>
      )}

      {/* ── QUICK ACTIONS ── */}
      <GlassCard accent="teal" className="mt-4">
        <h3 className="text-sm font-bold text-white mb-3">🎯 Rekomendasi</h3>
        <div className="space-y-2 text-xs text-slate-400">
          <p>• Ikuti <span className="text-sky-400 font-semibold">Training K3</span> untuk keselamatan kerja</p>
          <p>• Perpanjang <span className="text-teal-400 font-semibold">Sertifikasi</span> yang akan habis</p>
          <p>• Ikuti <span className="text-purple-400 font-semibold">Workshop</span> soft skill terbaru</p>
        </div>
      </GlassCard>
    </PageLayout>
  );
}
