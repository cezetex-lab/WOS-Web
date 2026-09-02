// ============================================================
// WorkerAttendance.jsx — Custom Worker Attendance Page
// RPC: get_worker_attendance(p_nrp)
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, MetricCard, GlassCard, Badge, LoadingSpinner, EmptyState, Button
} from '../../../lib/design-system';

const STATUS_CONFIG = {
  Hadir:     { icon: '✅', color: 'green', label: 'Hadir' },
  Terlambat: { icon: '⏰', color: 'warning', label: 'Terlambat' },
  Sakit:     { icon: '🏥', color: 'red', label: 'Sakit' },
  Izin:      { icon: '📌', color: 'info', label: 'Izin' },
  Alpha:     { icon: '❌', color: 'danger', label: 'Alpha' },
  Cuti:      { icon: '🌴', color: 'teal', label: 'Cuti' },
};

const DAYS = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

export default function WorkerAttendance() {
  const session = getSession();
  const nrp = session?.nrp;
  const [loading, setLoading] = useState(true);
  const [records, setRecords] = useState([]);
  const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth());
  const [selectedYear] = useState(new Date().getFullYear());

  const fetchAttendance = useCallback(async () => {
    if (!nrp) { setLoading(false); return; }
    setLoading(true);
    try {
      const result = await rpc('get_worker_attendance', { p_nrp: nrp });
      const data = Array.isArray(result) ? result
        : result?.data && Array.isArray(result.data) ? result.data : [];
      setRecords(data);
    } catch (err) { }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchAttendance(); }, [fetchAttendance]);

  // ── FILTER BY MONTH ──
  const monthRecords = records.filter(r => {
    if (!r.date) return false;
    const d = new Date(r.date);
    return d.getMonth() === selectedMonth && d.getFullYear() === selectedYear;
  });

  // ── STATS ──
  const hadir = monthRecords.filter(r => r.status_hadir === 'Hadir').length;
  const terlambat = monthRecords.filter(r => r.status_hadir === 'Terlambat').length;
  const alpha = monthRecords.filter(r => r.status_hadir === 'Alpha').length;
  const totalJam = monthRecords.reduce((s, r) => {
    if (r.jam_masuk && r.jam_keluar) {
      const masuk = new Date(`2000-01-01T${r.jam_masuk}`);
      const keluar = new Date(`2000-01-01T${r.jam_keluar}`);
      return s + Math.max(0, (keluar - masuk) / (1000 * 60 * 60));
    }
    return s;
  }, 0);

  const statCards = [
    { icon: '✅', value: hadir, label: 'Hadir', trend: `${monthRecords.length} hari`, color: 'green' },
    { icon: '⏰', value: terlambat, label: 'Terlambat', trend: 'Perlu diperhatikan', color: 'orange' },
    { icon: '❌', value: alpha, label: 'Alpha', trend: alpha > 0 ? '⚠️' : 'Bersih', color: alpha > 0 ? 'red' : 'green' },
    { icon: '⏱️', value: `${totalJam.toFixed(1)}j`, label: 'Total Jam', trend: `Bulan ini`, color: 'blue' },
  ];

  const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  // ── BUILD CALENDAR GRID ──
  const calendarDays = [];
  const firstDay = new Date(selectedYear, selectedMonth, 1).getDay();
  const daysInMonth = new Date(selectedYear, selectedMonth + 1, 0).getDate();

  for (let i = 0; i < firstDay; i++) calendarDays.push(null);
  for (let d = 1; d <= daysInMonth; d++) calendarDays.push(d);

  const getRecordForDay = (day) => {
    if (!day) return null;
    const dateStr = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    return monthRecords.find(r => r.date === dateStr);
  };

  if (loading) {
    return (
      <PageLayout backTo="/worker" title="Kehadiran">
        <LoadingSpinner text="Memuat data kehadiran..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/worker" title="Kehadiran" subtitle={months[selectedMonth] + ' ' + selectedYear}>
      {/* ── MONTH SELECTOR ── */}
      <div className="flex gap-1.5 overflow-x-auto pb-3 mb-4 -mx-4 px-4 scrollbar-hide">
        {months.map((m, i) => (
          <button
            key={m}
            onClick={() => setSelectedMonth(i)}
            className={`flex-shrink-0 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              selectedMonth === i
                ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30'
                : 'bg-slate-800/50 text-slate-400 border border-white/5'
            }`}
          >
            {m.slice(0, 3)}
          </button>
        ))}
      </div>

      {/* ── STATS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>

      {/* ── CALENDAR GRID ── */}
      <GlassCard accent="blue" className="mb-4">
        <h3 className="text-sm font-bold text-white mb-3">📅 Kalender {months[selectedMonth]}</h3>
        <div className="grid grid-cols-7 gap-1 mb-2">
          {DAYS.map(d => (
            <div key={d} className="text-center text-[11px] font-semibold text-slate-500 py-1">{d}</div>
          ))}
        </div>
        <div className="grid grid-cols-7 gap-1">
          {calendarDays.map((day, i) => {
            const rec = getRecordForDay(day);
            const status = rec?.status_hadir || '';
            const config = STATUS_CONFIG[status];
            return (
              <div
                key={i}
                className={`aspect-square flex flex-col items-center justify-center rounded-lg text-[11px] ${
                  !day ? 'bg-transparent' :
                  config ? `bg-${config.color === 'green' ? 'emerald' : config.color === 'warning' ? 'amber' : config.color === 'red' ? 'red' : config.color === 'teal' ? 'teal' : 'slate'}-500/15` :
                  'bg-slate-800/30'
                }`}
              >
                {day && (
                  <>
                    <span className="font-semibold text-white">{day}</span>
                    {config && <span className="text-[8px] mt-0.5">{config.icon}</span>}
                  </>
                )}
              </div>
            );
          })}
        </div>
      </GlassCard>

      {/* ── RECENT RECORDS ── */}
      <GlassCard accent="green">
        <h3 className="text-sm font-bold text-white mb-3">📋 Riwayat Kehadiran</h3>
        {monthRecords.length === 0 ? (
          <EmptyState title="Belum ada data" description={`Tidak ada catatan kehadiran untuk ${months[selectedMonth]}`} />
        ) : (
          <div className="space-y-2">
            {monthRecords.slice(0, 15).map((rec, i) => {
              const config = STATUS_CONFIG[rec.status_hadir] || STATUS_CONFIG['Hadir'];
              return (
                <div key={i} className="flex items-center gap-3 p-3 bg-white/5 rounded-xl border border-white/5">
                  <span className="text-xl">{config.icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="text-xs font-semibold text-white">{rec.status_hadir || '-'}</p>
                      <Badge status={rec.shift || '-'} type="info" />
                    </div>
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      {rec.date ? new Date(rec.date).toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'short' }) : '-'}
                    </p>
                  </div>
                  <div className="text-right">
                    {rec.jam_masuk && (
                      <p className="text-xs text-white font-mono">{rec.jam_masuk?.slice(0, 5)}</p>
                    )}
                    {rec.jam_keluar && (
                      <p className="text-[11px] text-slate-500">→ {rec.jam_keluar?.slice(0, 5)}</p>
                    )}
                    {rec.menit_terlambat > 0 && (
                      <p className="text-[11px] text-amber-400">+{rec.menit_terlambat}m</p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </GlassCard>
    </PageLayout>
  );
}
