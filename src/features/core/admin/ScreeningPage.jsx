// ScreeningPage.jsx — Pre-employment Screening
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState } from '../../../lib/design-system';

export default function ScreeningPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_screening_results');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const types = ['Background', 'Medical', 'Reference', 'Education'];
  const typeCount = types.reduce((acc, t) => {
    acc[t] = data.filter(d => d.check_type === t).length;
    return acc;
  }, {});

  const passed = data.filter(d => d.status === 'Passed').length;
  const failed = data.filter(d => d.status === 'Failed').length;

  if (loading) return <PageLayout backTo="/admin" title="Screening"><LoadingSpinner text="Memuat screening..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🔍 Pre-employment Screening" subtitle={`${data.length} hasil screening`}>
      <div className="grid grid-cols-4 gap-3 mb-6">
        <MetricCard icon="🔍" value={data.length} label="Total" color="blue" />
        <MetricCard icon="✅" value={passed} label="Passed" color="green" />
        <MetricCard icon="❌" value={failed} label="Failed" color="red" />
        <MetricCard icon="⏳" value={data.length - passed - failed} label="Pending" color="yellow" />
      </div>

      {/* Type Breakdown */}
      <div className="grid grid-cols-4 gap-2 mb-4">
        {types.map(t => (
          <div key={t} className="text-center p-3 rounded-lg bg-slate-800/50 border border-white/5">
            <p className="text-2xl mb-1">{t === 'Background' ? '🔐' : t === 'Medical' ? '🏥' : t === 'Reference' ? '📞' : '🎓'}</p>
            <p className="text-xs text-slate-400">{t}</p>
            <p className="text-sm font-bold text-white">{typeCount[t] || 0}</p>
          </div>
        ))}
      </div>

      <GlassCard accent="blue">
        <div className="space-y-2">
          {data.map(item => (
            <div key={item.id} className="flex items-center gap-3 py-3 border-b border-white/5 last:border-0">
              <div className="text-xl">{item.check_type === 'Background' ? '🔐' : item.check_type === 'Medical' ? '🏥' : item.check_type === 'Reference' ? '📞' : '🎓'}</div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-white">{item.candidate_name}</p>
                <p className="text-[10px] text-slate-400">{item.check_type} Check • {item.created_at ? new Date(item.created_at).toLocaleDateString('id-ID') : '-'}</p>
                {item.notes && <p className="text-[10px] text-slate-300 mt-1">{item.notes}</p>}
              </div>
              <Badge status={item.status || 'Pending'} type={item.status === 'Passed' ? 'success' : item.status === 'Failed' ? 'danger' : 'warning'} />
            </div>
          ))}
          {data.length === 0 && <EmptyState title="Belum ada screening" icon="🔍" />}
        </div>
      </GlassCard>
    </PageLayout>
  );
}
