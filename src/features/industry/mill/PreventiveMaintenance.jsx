import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner } from '@/lib/design-system';

export default function PreventiveMaintenance() {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('ALL');

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.rpc('get_maintenance_schedule');
      setTasks(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat jadwal maintenance..." />;

  const scheduled = tasks.filter(t => t.status === 'SCHEDULED').length;
  const inProgress = tasks.filter(t => t.status === 'IN_PROGRESS').length;
  const overdue = tasks.filter(t => t.status === 'OVERDUE').length;
  const completed = tasks.filter(t => t.status === 'COMPLETED').length;
  const filtered = filter === 'ALL' ? tasks : tasks.filter(t => t.status === filter);

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">🔧 Preventive Maintenance</h1>
      <p className="text-slate-400 text-sm mb-6">Jadwal perawatan equipment — Pabrik PKS</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="📅" value={scheduled} label="Scheduled" trend="Tugas" color="blue" />
        <MetricCard icon="🔨" value={inProgress} label="In Progress" trend="Sedang dikerjakan" color="orange" />
        <MetricCard icon="⚠️" value={overdue} label="Overdue" trend="Terlambat" color="red" />
        <MetricCard icon="✅" value={completed} label="Completed" trend="Selesai" color="green" />
      </div>

      <div className="flex gap-2 mb-4 overflow-x-auto pb-2">
        {['ALL', 'SCHEDULED', 'IN_PROGRESS', 'OVERDUE', 'COMPLETED'].map(s => (
          <button key={s} onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold whitespace-nowrap ${filter === s ? 'bg-teal-500 text-white' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'}`}>
            {s === 'ALL' ? 'Semua' : s}
          </button>
        ))}
      </div>

      <div className="space-y-3">
        {filtered.map((t) => (
          <GlassCard key={t.id} title={`${t.equipment} — ${t.equipment_name}`} icon="🔧"
            accent={t.status === 'OVERDUE' ? 'red' : t.status === 'IN_PROGRESS' ? 'orange' : 'blue'}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Tipe</p>
                <p className="text-sm text-white">{t.type}</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Prioritas</p>
                <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                  t.priority === 'CRITICAL' ? 'bg-red-500/20 text-red-400' :
                  t.priority === 'HIGH' ? 'bg-orange-500/20 text-orange-400' :
                  t.priority === 'MEDIUM' ? 'bg-yellow-500/20 text-yellow-400' :
                  'bg-slate-500/20 text-slate-400'
                }`}>{t.priority}</span>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Status</p>
                <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                  t.status === 'OVERDUE' ? 'bg-red-500/20 text-red-400' :
                  t.status === 'IN_PROGRESS' ? 'bg-yellow-500/20 text-yellow-400' :
                  t.status === 'COMPLETED' ? 'bg-green-500/20 text-green-400' :
                  'bg-blue-500/20 text-blue-400'
                }`}>{t.status}</span>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Downtime</p>
                <p className="text-sm text-white">{t.downtime} jam</p>
              </div>
              <div className="col-span-2">
                <p className="text-[10px] text-slate-500 uppercase">Deskripsi</p>
                <p className="text-sm text-slate-300">{t.description}</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Scheduled</p>
                <p className="text-sm text-white">{t.scheduled}</p>
              </div>
              <div>
                <p className="text-[10px] text-slate-500 uppercase">Assigned</p>
                <p className="text-sm text-white">{t.assigned_to || '-'}</p>
              </div>
            </div>
          </GlassCard>
        ))}
      </div>
    </div>
  );
}
