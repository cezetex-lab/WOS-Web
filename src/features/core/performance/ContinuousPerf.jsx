// ============================================================
// ContinuousPerf.jsx — #37 Continuous Performance Check-in
// Worker & Manager: check-in berkala, catatan kinerja
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input, Badge, LoadingSpinner,
  EmptyState, StatItem, SectionHeader, useToast
} from '../../../lib/design-system';

export default function ContinuousPerf() {
  const toast = useToast();
  const user = getSession();
  const nrp = user?.nrp || 'NRP001';
  const role = user?.role || 'worker';
  const [loading, setLoading] = useState(true);
  const [checkins, setCheckins] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  // Form
  const [weekNote, setWeekNote] = useState('');
  const [mood, setMood] = useState('good');
  const [blockers, setBlockers] = useState('');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_activities', { p_nrp: nrp });
      const items = result?.data || result || [];
      // Filter for performance check-in activities
      setCheckins(Array.isArray(items) ? items.filter(i => (i.type || '').toLowerCase().includes('checkin') || (i.type || '').toLowerCase().includes('performance')) : []);
    } catch (err) { }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const handleCheckin = async () => {
    if (!weekNote) {
      toast.warning('Isi catatan mingguan');
      return;
    }
    setSubmitting(true);
    try {
      await rpc('create_worker_request', {
        p_nrp: nrp,
        p_type: 'Check-in',
        p_detail: `Mood: ${mood} | Blockers: ${blockers || 'None'}`,
        p_note: weekNote,
      });
      toast.success('Check-in berhasil!');
      setShowForm(false);
      setWeekNote('');
      setBlockers('');
      fetchData();
    } catch (err) {
      toast.error('Gagal check-in');
    }
    setSubmitting(false);
  };

  const moods = [
    { id: 'great', emoji: '😄', label: 'Sangat Baik' },
    { id: 'good', emoji: '🙂', label: 'Baik' },
    { id: 'neutral', emoji: '😐', label: 'Biasa' },
    { id: 'tired', emoji: '😴', label: 'Lelah' },
    { id: 'stressed', emoji: '😰', label: 'Stres' },
  ];

  if (loading) return <PageLayout backTo="/worker" title="Continuous Performance"><LoadingSpinner text="Memuat..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="Continuous Performance" subtitle="Check-in berkala mingguan">
      {/* ── ACTION ── */}
      <Button color="teal" onClick={() => setShowForm(!showForm)} className="mb-4 w-full">
        {showForm ? '✕ Tutup' : '📝 Check-in Mingguan'}
      </Button>

      {/* ── CHECK-IN FORM ── */}
      {showForm && (
        <GlassCard title="Check-in Mingguan" icon="✏️" accent="teal" className="mb-4">
          <div className="space-y-4">
            {/* Mood Selector */}
            <div>
              <label className="text-xs font-semibold text-slate-300 mb-2 block">Mood Minggu Ini</label>
              <div className="flex gap-2">
                {moods.map(m => (
                  <button
                    key={m.id}
                    onClick={() => setMood(m.id)}
                    className={`flex flex-col items-center p-2 rounded-xl border transition-all ${
                      mood === m.id ? 'bg-teal-500/20 border-teal-500/50' : 'bg-slate-800/50 border-white/5 hover:border-white/10'
                    }`}
                  >
                    <span className="text-xl">{m.emoji}</span>
                    <span className="text-[11px] text-slate-400 mt-1">{m.label}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Weekly Note */}
            <Input
              label="Apa yang sudah dicapai minggu ini?"
              placeholder="Tuliskan pencapaian, target, atau update..."
              value={weekNote}
              onChange={(e) => setWeekNote(e.target.value)}
              icon="📋"
            />

            {/* Blockers */}
            <Input
              label="Ada kendala? (opsional)"
              placeholder="Apa yang menghambat pekerjaanmu?"
              value={blockers}
              onChange={(e) => setBlockers(e.target.value)}
              icon="🚧"
            />

            <Button color="teal" onClick={handleCheckin} disabled={submitting} className="w-full">
              {submitting ? 'Mengirim...' : '📤 Kirim Check-in'}
            </Button>
          </div>
        </GlassCard>
      )}

      {/* ── HISTORY ── */}
      <GlassCard title="Riwayat Check-in" icon="📋" accent="blue">
        {checkins.length === 0 ? (
          <EmptyState icon="📝" title="Belum ada check-in" subtitle="Lakukan check-in mingguan untuk tracking performa" />
        ) : (
          <div className="space-y-2">
            {checkins.slice(0, 10).map((item, i) => (
              <div key={i} className="p-3 bg-slate-900/40 rounded-xl border border-white/5">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-bold text-white">Check-in</span>
                  <span className="text-[11px] text-slate-500">
                    {item.created_at ? new Date(item.created_at).toLocaleDateString('id-ID') : '-'}
                  </span>
                </div>
                <p className="text-xs text-slate-300">{item.note || item.detail || '-'}</p>
              </div>
            ))}
          </div>
        )}
      </GlassCard>
    </PageLayout>
  );
}
