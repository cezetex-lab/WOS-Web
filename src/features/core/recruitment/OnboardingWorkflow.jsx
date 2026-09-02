// OnboardingWorkflow.jsx — Alur onboarding karyawan baru
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, Button, LoadingSpinner, EmptyState } from '../../../lib/design-system';

export default function OnboardingWorkflow() {
  const [loading, setLoading] = useState(true);
  const [tasks, setTasks] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_onboarding_tasks');
      setTasks(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const categories = ['IT', 'HR', 'Facility', 'Training', 'General'];
  const catCount = categories.reduce((acc, c) => {
    acc[c] = tasks.filter(t => t.category === c).length;
    return acc;
  }, {});

  const completed = tasks.filter(t => t.status === 'Completed').length;
  const progress = tasks.length > 0 ? Math.round((completed / tasks.length) * 100) : 0;

  if (loading) return <PageLayout backTo="/admin" title="Onboarding"><LoadingSpinner text="Memuat onboarding..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🚀 Onboarding Workflow" subtitle={`${tasks.length} tugas onboarding`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard icon="📋" value={tasks.length} label="Total Tugas" color="blue" />
        <MetricCard icon="✅" value={completed} label="Selesai" color="green" />
        <MetricCard icon="📊" value={`${progress}%`} label="Progress" color="teal" />
      </div>

      {/* Progress Bar */}
      <GlassCard accent="teal" className="mb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs font-bold text-white">Overall Progress</span>
          <span className="text-xs text-slate-400">{completed}/{tasks.length}</span>
        </div>
        <div className="w-full bg-slate-700 rounded-full h-3">
          <div className="bg-gradient-to-r from-teal-500 to-green-500 h-3 rounded-full transition-all" style={{ width: `${progress}%` }} />
        </div>
      </GlassCard>

      {/* Categories */}
      <div className="grid grid-cols-5 gap-2 mb-4">
        {categories.map(cat => (
          <div key={cat} className="text-center p-2 rounded-lg bg-slate-800/50 border border-white/5">
            <p className="text-[11px] text-slate-400">{cat}</p>
            <p className="text-sm font-bold text-white">{catCount[cat] || 0}</p>
          </div>
        ))}
      </div>

      {/* Task List */}
      <GlassCard accent="blue">
        <div className="space-y-2">
          {tasks.map(task => (
            <div key={task.id} className="flex items-center gap-3 py-3 border-b border-white/5 last:border-0">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm ${task.status === 'Completed' ? 'bg-green-500/20 text-green-400' : task.status === 'InProgress' ? 'bg-orange-500/20 text-orange-400' : 'bg-slate-700 text-slate-400'}`}>
                {task.status === 'Completed' ? '✅' : task.status === 'InProgress' ? '🔄' : '⏳'}
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-white">{task.task_name}</p>
                <div className="flex items-center gap-2 mt-1">
                  <Badge status={task.category} type="info" />
                  {task.due_date && <span className="text-[11px] text-slate-400">Due: {new Date(task.due_date).toLocaleDateString('id-ID')}</span>}
                  {task.assigned_to && <span className="text-[11px] text-slate-400">→ {task.assigned_to}</span>}
                </div>
              </div>
              <Badge status={task.status} type={task.status === 'Completed' ? 'success' : task.status === 'InProgress' ? 'warning' : 'info'} />
            </div>
          ))}
          {tasks.length === 0 && <EmptyState title="Belum ada tugas onboarding" icon="🚀" />}
        </div>
      </GlassCard>
    </PageLayout>
  );
}
