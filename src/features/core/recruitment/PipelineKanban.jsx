// PipelineKanban.jsx — Kanban board untuk pipeline pelamar
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, Badge, Button, LoadingSpinner, EmptyState } from '../../../lib/design-system';

const STAGES = [
  { id: 'Applied', label: 'Applied', color: 'blue', icon: '📥' },
  { id: 'Screening', label: 'Screening', color: 'teal', icon: '🔍' },
  { id: 'Interview', label: 'Interview', color: 'orange', icon: '🎤' },
  { id: 'Offer', label: 'Offer', color: 'green', icon: '📄' },
  { id: 'Hired', label: 'Hired', color: 'green', icon: '✅' },
];

export default function PipelineKanban() {
  const [loading, setLoading] = useState(true);
  const [candidates, setCandidates] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_candidate_pipeline');
      setCandidates(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const moveCandidate = async (id, newStage) => {
    try {
      await rpc('move_candidate', { p_id: id, p_stage: newStage });
      setCandidates(candidates.map(c => c.id === id ? { ...c, stage: newStage } : c));
    } catch (e) { }
  };

  if (loading) return <PageLayout backTo="/admin" title="Pipeline"><LoadingSpinner text="Memuat pipeline..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🔄 Pipeline Kanban" subtitle={`${candidates.length} pelamar`}>
      <div className="flex gap-3 overflow-x-auto pb-4">
        {STAGES.map(stage => {
          const stageCandidates = candidates.filter(c => c.stage === stage.id);
          return (
            <div key={stage.id} className="flex-shrink-0 w-64">
              <div className={`rounded-xl p-3 mb-3 bg-slate-800/50 border border-${stage.color}-500/20`}>
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-white">{stage.icon} {stage.label}</span>
                  <Badge status={stageCandidates.length} type={stage.color} />
                </div>
              </div>
              <div className="space-y-2 min-h-[200px]">
                {stageCandidates.map(c => (
                  <GlassCard key={c.id} accent={stage.color} className="p-3">
                    <h4 className="text-sm font-semibold text-white mb-1">{c.candidate_name}</h4>
                    <p className="text-[10px] text-slate-400 mb-2">{c.candidate_email || '-'}</p>
                    <div className="flex items-center gap-1 mb-2">
                      {'⭐'.repeat(Math.min(c.rating || 0, 5))}
                      <span className="text-[10px] text-slate-400 ml-1">{c.rating || 0}/5</span>
                    </div>
                    {c.notes && <p className="text-[10px] text-slate-300 truncate">{c.notes}</p>}
                    <div className="flex gap-1 mt-2">
                      {STAGES.filter(s => s.id !== stage.id && s.id !== 'Rejected').slice(0, 2).map(s => (
                        <button key={s.id} onClick={() => moveCandidate(c.id, s.id)} className="text-[10px] px-2 py-0.5 rounded bg-slate-700/50 text-slate-300 hover:bg-slate-600/50 transition-all">
                          → {s.label}
                        </button>
                      ))}
                    </div>
                  </GlassCard>
                ))}
                {stageCandidates.length === 0 && (
                  <div className="text-center py-8 text-xs text-slate-500">Kosong</div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </PageLayout>
  );
}
