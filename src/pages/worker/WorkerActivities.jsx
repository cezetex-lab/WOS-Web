// WorkerActivities.jsx — Riwayat aktivitas terkini karyawan
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState, Tabs } from '../../lib/design-system';

export default function WorkerActivities() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [tab, setTab] = useState('all');

  const nrp = localStorage.getItem('wos_nrp') || JSON.parse(sessionStorage.getItem('wos_user') || '{}')?.nrp || 'NRP001';

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_activities', { p_nrp: nrp });
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const types = [...new Set(data.map(r => r.type || r.action_type || 'Other'))];
  const filtered = tab === 'all' ? data : data.filter(r => (r.type || r.action_type || 'Other') === tab);

  const getActionIcon = (type) => {
    const icons = { login: '🔑', logout: '🚪', leave: '🌴', overtime: '⏰', training: '📚', request: '📝', attendance: '📍', task: '✅', profile: '👤' };
    return icons[(type || '').toLowerCase()] || '📋';
  };

  if (loading) return <PageLayout backTo="/worker" title="Aktivitas"><LoadingSpinner text="Memuat aktivitas..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="📋 Aktivitas Saya" subtitle={`${data.length} aktivitas tercatat`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📋" value={data.length} label="Total Aktivitas" color="blue" />
        <MetricCard icon="📅" value={new Set(data.map(r => r.created_at ? new Date(r.created_at).toLocaleDateString('id-ID') : '')).size} label="Hari Aktif" color="green" />
        <MetricCard icon="🏷️" value={types.length} label="Tipe Aktivitas" color="teal" />
      </div>

      {types.length > 1 && (
        <div className="mb-4">
          <Tabs tabs={[{ id: 'all', label: 'Semua', count: data.length }, ...types.map(t => ({ id: t, label: t, count: data.filter(r => (r.type || r.action_type || 'Other') === t).length }))]} active={tab} onChange={setTab} />
        </div>
      )}

      <GlassCard accent="blue">
        <div className="space-y-1">
          {filtered.slice(0, 50).map((row, i) => (
            <div key={i} className="flex items-start gap-3 py-3 border-b border-white/5 last:border-0">
              <span className="text-xl mt-0.5">{getActionIcon(row.type || row.action_type)}</span>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <p className="text-sm font-semibold text-white truncate">{row.action || row.description || row.type || 'Aktivitas'}</p>
                  {row.type && <Badge status={row.type} type="info" />}
                </div>
                {row.details && <p className="text-xs text-slate-400 mt-1 truncate">{row.details}</p>}
                <p className="text-[10px] text-slate-500 mt-1">{row.created_at ? new Date(row.created_at).toLocaleString('id-ID') : '-'}</p>
              </div>
            </div>
          ))}
          {filtered.length === 0 && <EmptyState title="Belum ada aktivitas" subtitle="Aktivitas akan tercatat saat Anda menggunakan sistem" icon="📋" />}
        </div>
      </GlassCard>
    </PageLayout>
  );
}
