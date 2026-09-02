// ============================================================
// ShiftSchedule.jsx — #74 Shift Management
// View shifts, assign workers, swap requests
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, LoadingSpinner, Badge, Button } from '../../../lib/design-system';

const SHIFT_COLORS = {
  'Pagi': { bg: 'bg-amber-500/10', border: 'border-amber-500/20', text: 'text-amber-400', icon: '🌅' },
  'Siang': { bg: 'bg-sky-500/10', border: 'border-sky-500/20', text: 'text-sky-400', icon: '☀️' },
  'Malam': { bg: 'bg-indigo-500/10', border: 'border-indigo-500/20', text: 'text-indigo-400', icon: '🌙' },
};

const DAYS = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

export default function ShiftSchedule() {
  const [loading, setLoading] = useState(true);
  const [shifts, setShifts] = useState([]);
  const [selectedDay, setSelectedDay] = useState(new Date().getDay() === 0 ? 6 : new Date().getDay() - 1);

  const fetchShifts = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await supabase.rpc('get_shift_schedule');
      setShifts(data || []);
    } catch (err) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchShifts(); }, [fetchShifts]);

  if (loading) return <PageLayout backTo="/admin" title="Jadwal Shift"><LoadingSpinner /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="Jadwal Shift" subtitle="Kelola jadwal shift karyawan">
      {/* ── DAY SELECTOR ── */}
      <div className="flex gap-1.5 overflow-x-auto pb-3 mb-4 -mx-4 px-4 scrollbar-hide">
        {DAYS.map((day, i) => (
          <button
            key={day}
            onClick={() => setSelectedDay(i)}
            className={`flex-shrink-0 px-3 py-2 rounded-xl text-xs font-semibold transition-all ${
              selectedDay === i
                ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30'
                : 'bg-slate-800/50 text-slate-400 border border-white/5'
            }`}
          >
            {day.slice(0, 3)}
          </button>
        ))}
      </div>

      {/* ── SHIFTS ── */}
      <div className="space-y-3">
        {shifts.length === 0 ? (
          <GlassCard>
            <p className="text-sm text-slate-400 text-center py-4">Belum ada jadwal shift</p>
          </GlassCard>
        ) : (
          shifts.map(shift => {
            const style = SHIFT_COLORS[shift.shift_name] || SHIFT_COLORS['Pagi'];
            return (
              <GlassCard key={shift.shift_code} accent="blue">
                <div className="flex items-center gap-3">
                  <span className="text-2xl">{style.icon}</span>
                  <div className="flex-1">
                    <h3 className="text-sm font-bold text-white">{shift.shift_name}</h3>
                    <p className="text-xs text-slate-400">
                      {shift.start_time?.slice(0, 5)} — {shift.end_time?.slice(0, 5)}
                    </p>
                  </div>
                  <div className="text-right">
                    <Badge status={shift.shift_code} type="info" />
                    <p className="text-[10px] text-slate-500 mt-1">Grace: {shift.grace_minutes}m</p>
                  </div>
                </div>

                {/* ── WEEKLY PATTERN ── */}
                <div className="mt-3 pt-3 border-t border-white/5">
                  <p className="text-[10px] text-slate-500 mb-2 uppercase tracking-wider">Jadwal Mingguan</p>
                  <div className="grid grid-cols-7 gap-1">
                    {DAYS.map((day, i) => {
                      const isWorkDay = i < 5; // Mon-Fri
                      return (
                        <div
                          key={day}
                          className={`text-center py-1.5 rounded-lg text-[10px] ${
                            isWorkDay
                              ? `${style.bg} ${style.text} border ${style.border}`
                              : 'bg-slate-800/30 text-slate-600'
                          }`}
                        >
                          {day.slice(0, 2)}
                        </div>
                      );
                    })}
                  </div>
                </div>
              </GlassCard>
            );
          })
        )}

        {/* ── QUICK INFO ── */}
        <GlassCard accent="teal">
          <h3 className="text-sm font-bold text-white mb-2">ℹ️ Info Shift</h3>
          <div className="space-y-1.5 text-xs text-slate-400">
            <p>• <b className="text-white">Pagi:</b> 07:00 — 15:00 (Grace: 10 menit)</p>
            <p>• <b className="text-white">Siang:</b> 15:00 — 23:00 (Grace: 10 menit)</p>
            <p>• <b className="text-white">Malam:</b> 23:00 — 07:00 (Grace: 10 menit)</p>
            <p className="pt-1 text-slate-500">* Shift 3 berlaku untuk operasi pabrik (MILL) dan tambang (MINING)</p>
          </div>
        </GlassCard>
      </div>
    </PageLayout>
  );
}
