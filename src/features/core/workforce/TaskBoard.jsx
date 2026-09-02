// ============================================================
// TaskBoard.jsx — #71 Task Management Kanban
// TODO / DOING / DONE columns
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, Button, LoadingSpinner, Badge } from '../../../lib/design-system';

const COLUMNS = [
  { id: 'TODO', label: '📋 To Do', color: 'slate', bgColor: 'bg-slate-800/30' },
  { id: 'DOING', label: '🔄 Doing', color: 'blue', bgColor: 'bg-blue-500/10' },
  { id: 'DONE', label: '✅ Done', color: 'green', bgColor: 'bg-green-500/10' },
];

export default function TaskBoard() {
  const nrp = getSession()?.nrp;
  const [loading, setLoading] = useState(true);
  const [tasks, setTasks] = useState({ todo: [], doing: [], done: [] });
  const [newTitle, setNewTitle] = useState('');
  const [adding, setAdding] = useState(false);

  const fetchTasks = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await supabase.rpc('get_task_board', { p_nrp: nrp });
      if (data) {
        setTasks({
          todo: data.todo || [],
          doing: data.doing || [],
          done: data.done || [],
        });
      }
    } catch (err) { }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchTasks(); }, [fetchTasks]);

  const handleAddTask = async () => {
    if (!newTitle.trim()) return;
    setAdding(true);
    try {
      await supabase.rpc('create_task', {
        p_assignee: nrp,
        p_title: newTitle.trim(),
      });
      setNewTitle('');
      fetchTasks();
    } catch (err) { }
    setAdding(false);
  };

  const handleMoveTask = async (taskId, newStatus) => {
    try {
      await supabase.rpc('update_task_status', { p_task_id: taskId, p_status: newStatus });
      fetchTasks();
    } catch (err) { }
  };

  const moveToNext = (currentStatus) => {
    if (currentStatus === 'TODO') return 'DOING';
    if (currentStatus === 'DOING') return 'DONE';
    return null;
  };

  if (loading) return <PageLayout backTo="/worker" title="Tasks"><LoadingSpinner /></PageLayout>;

  const totalTasks = tasks.todo.length + tasks.doing.length + tasks.done.length;

  return (
    <PageLayout backTo="/worker" title="Task Board" subtitle={`${totalTasks} tugas`}>
      {/* ── ADD TASK ── */}
      <div className="flex gap-2 mb-4">
        <input
          type="text"
          value={newTitle}
          onChange={e => setNewTitle(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleAddTask()}
          placeholder="Tambah task baru..."
          className="flex-1 bg-slate-800/50 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:border-sky-500/50 focus:outline-none"
        />
        <Button color="blue" size="sm" onClick={handleAddTask} disabled={adding || !newTitle.trim()}>
          + Tambah
        </Button>
      </div>

      {/* ── COLUMNS ── */}
      <div className="space-y-4">
        {COLUMNS.map(col => {
          const colTasks = tasks[col.id.toLowerCase()] || [];
          return (
            <GlassCard key={col.id} accent={col.color}>
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-bold text-white">{col.label}</h3>
                <Badge status={`${colTasks.length} tugas`} type={col.color} />
              </div>

              {colTasks.length === 0 ? (
                <p className="text-xs text-slate-500 text-center py-4">Tidak ada tugas</p>
              ) : (
                <div className="space-y-2">
                  {colTasks.map(task => {
                    const next = moveToNext(col.id);
                    return (
                      <div key={task.id} className="flex items-center justify-between p-3 bg-white/5 rounded-xl border border-white/5">
                        <div className="flex-1 min-w-0">
                          <p className="text-sm text-white truncate">{task.title}</p>
                          {task.due && (
                            <p className="text-[11px] text-slate-500 mt-0.5">
                              Due: {new Date(task.due).toLocaleDateString('id-ID')}
                            </p>
                          )}
                        </div>
                        <div className="flex gap-1 ml-2">
                          {next && (
                            <button
                              onClick={() => handleMoveTask(task.id, next)}
                              className="px-2 py-1 rounded-lg bg-sky-500/20 text-sky-400 text-[11px] font-semibold hover:bg-sky-500/30 transition-all"
                            >
                              → {next}
                            </button>
                          )}
                          {col.id === 'DOING' && (
                            <button
                              onClick={() => handleMoveTask(task.id, 'TODO')}
                              className="px-2 py-1 rounded-lg bg-slate-600/30 text-slate-400 text-[11px] hover:bg-slate-600/50 transition-all"
                            >
                              ← Back
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </GlassCard>
          );
        })}
      </div>
    </PageLayout>
  );
}
