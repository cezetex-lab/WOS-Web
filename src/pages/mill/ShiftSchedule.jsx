import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner } from '@/lib/design-system';

const SHIFT_COLORS = {
  PAGI: { bg: 'bg-orange-500/20', text: 'text-orange-400', border: 'border-orange-500/30', icon: '🌅' },
  SORE: { bg: 'bg-blue-500/20', text: 'text-blue-400', border: 'border-blue-500/30', icon: '🌇' },
  MALAM: { bg: 'bg-purple-500/20', text: 'text-purple-400', border: 'border-purple-500/30', icon: '🌙' },
};

export default function ShiftSchedule() {
  const [assignments, setAssignments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedShift, setSelectedShift] = useState(null);
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().slice(0, 10));

  useEffect(() => {
    const fetch = async () => {
      setLoading(true);
      const { data } = await supabase.rpc('get_shift_assignments', { p_date: selectedDate, p_shift: selectedShift });
      setAssignments(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, [selectedDate, selectedShift]);

  const pagi = assignments.filter(a => a.shift === 'PAGI');
  const sore = assignments.filter(a => a.shift === 'SORE');
  const malam = assignments.filter(a => a.shift === 'MALAM');

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">🔄 Jadwal Shift 3</h1>
      <p className="text-slate-400 text-sm mb-6">Pagi (06-14) · Sore (14-22) · Malam (22-06) — MINING & MILL</p>

      <div className="flex gap-3 mb-6">
        <input type="date" value={selectedDate} onChange={e => setSelectedDate(e.target.value)}
          className="bg-slate-800 border border-white/10 rounded-lg px-3 py-2 text-white text-sm" />
      </div>

      <div className="grid grid-cols-3 gap-3 mb-6">
        {['PAGI', 'SORE', 'MALAM'].map(shift => {
          const count = shift === 'PAGI' ? pagi.length : shift === 'SORE' ? sore.length : malam.length;
          const sc = SHIFT_COLORS[shift];
          return (
            <button key={shift} onClick={() => setSelectedShift(selectedShift === shift ? null : shift)}
              className={`p-4 rounded-xl border transition-all ${selectedShift === shift ? `${sc.bg} ${sc.border}` : 'bg-slate-800/50 border-white/5 hover:border-white/20'}`}>
              <span className="text-2xl">{sc.icon}</span>
              <p className={`text-lg font-bold mt-1 ${sc.text}`}>{count}</p>
              <p className="text-xs text-slate-400">{shift}</p>
              <p className="text-[10px] text-slate-500">
                {shift === 'PAGI' ? '06:00 - 14:00' : shift === 'SORE' ? '14:00 - 22:00' : '22:00 - 06:00'}
              </p>
            </button>
          );
        })}
      </div>

      {loading ? <LoadingSpinner text="Memuat jadwal shift..." /> : (
        <div className="space-y-4">
          {(selectedShift ? [selectedShift] : ['PAGI', 'SORE', 'MALAM']).map(shift => {
            const items = shift === 'PAGI' ? pagi : shift === 'SORE' ? sore : malam;
            const sc = SHIFT_COLORS[shift];
            return (
              <GlassCard key={shift} title={`${sc.icon} Shift ${shift}`} icon="🔄" accent={shift === 'PAGI' ? 'orange' : shift === 'SORE' ? 'blue' : 'purple'}>
                {items.length === 0 ? (
                  <p className="text-slate-400 text-sm">Tidak ada jadwal</p>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                    {items.map(a => (
                      <div key={a.id} className="p-2 bg-slate-800/50 rounded-lg border border-white/5">
                        <p className="text-xs font-bold text-white">{a.nrp}</p>
                        <p className="text-[10px] text-slate-400">{a.section} • {a.equipment}</p>
                        <span className={`inline-block mt-1 px-1.5 py-0.5 rounded text-[9px] font-bold ${
                          a.status === 'CHECKED_IN' ? 'bg-green-500/20 text-green-400' :
                          a.status === 'ABSENT' ? 'bg-red-500/20 text-red-400' :
                          'bg-slate-500/20 text-slate-400'
                        }`}>{a.status}</span>
                      </div>
                    ))}
                  </div>
                )}
              </GlassCard>
            );
          })}
        </div>
      )}
    </div>
  );
}
