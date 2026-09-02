// WorkerCareer.jsx — Jalur karir & peluang karyawan
import { getSession } from '@/lib/supabase-browser';
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState } from '../../../lib/design-system';

export default function WorkerCareer() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);

    const nrp = getSession()?.nrp || 'NRP001';

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_career_path', { p_nrp: nrp });
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  if (loading) return <PageLayout backTo="/worker" title="Karir"><LoadingSpinner text="Memuat career path..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="🚀 Karir Saya" subtitle="Jalur karir & peluang promosi">
      {/* Career Progress */}
      <GlassCard accent="blue" className="mb-4">
        <div className="text-center py-4">
          <p className="text-xs text-slate-400 mb-2">Jalur Karir</p>
          <div className="flex items-center justify-center gap-2 mb-4">
            {['L1', 'L2', 'L3', 'L4', 'L5'].map((level, i) => {
              const currentLevel = data.length > 0 ? (data[0].level || data[0].current_level || 1) : 1;
              const isActive = i + 1 <= parseInt(currentLevel);
              const isCurrent = i + 1 === parseInt(currentLevel);
              return (
                <div key={level} className="flex flex-col items-center">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center text-xs font-bold transition-all ${isCurrent ? 'bg-blue-500 text-white scale-110 ring-2 ring-blue-400' : isActive ? 'bg-teal-500 text-white' : 'bg-slate-700 text-slate-400'}`}>
                    {level}
                  </div>
                  <span className="text-[10px] text-slate-400 mt-1">{['Staff', 'Sr Staff', 'Lead', 'Manager', 'Director'][i]}</span>
                </div>
              );
            })}
          </div>
          <Badge status={`Level ${data.length > 0 ? (data[0].level || data[0].current_level || 1) : 1}`} type="blue" />
        </div>
      </GlassCard>

      {/* Target Position */}
      {data.length > 0 && data[0].target_position && (
        <GlassCard accent="teal" className="mb-4">
          <h3 className="text-sm font-bold text-white mb-2">🎯 Target</h3>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-400">Posisi Target</p>
              <p className="text-sm font-bold text-teal-400">{data[0].target_position}</p>
            </div>
            <div>
              <p className="text-xs text-slate-400">Progress</p>
              <div className="flex items-center gap-2">
                <div className="w-20 bg-slate-700 rounded-full h-2">
                  <div className="bg-teal-500 h-2 rounded-full" style={{ width: `${data[0].progress || 0}%` }} />
                </div>
                <span className="text-xs font-bold text-white">{data[0].progress || 0}%</span>
              </div>
            </div>
          </div>
        </GlassCard>
      )}

      {/* Skills */}
      <GlassCard accent="blue">
        <h3 className="text-sm font-bold text-white mb-3">🎯 Skills & Kompetensi</h3>
        {data.length > 0 ? (
          <div className="space-y-2">
            {data.map((row, i) => (
              <div key={i} className="flex items-center justify-between py-2 border-b border-white/5">
                <div>
                  <p className="text-xs font-semibold text-white">{row.skill || row.position || `Level ${i + 1}`}</p>
                  <p className="text-[10px] text-slate-400">{row.description || '-'}</p>
                </div>
                <Badge status={row.status || 'Active'} type={row.status === 'Completed' ? 'success' : 'info'} />
              </div>
            ))}
          </div>
        ) : (
          <EmptyState title="Belum ada data karir" subtitle="Career path akan muncul setelah penilaian" icon="🚀" />
        )}
      </GlassCard>
    </PageLayout>
  );
}
