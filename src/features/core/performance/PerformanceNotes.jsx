// ============================================================
// PerformanceNotes.jsx — #38 Performance Notes (Continuous Feedback)
// RPC: add_performance_note, get_performance_notes
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Input, Divider
} from '../../../lib/design-system';

// Inline Modal
function Modal({ onClose, title, children }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4" onClick={onClose}>
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md max-h-[80vh] overflow-y-auto p-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-white font-semibold text-sm">{title}</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-white text-lg">✕</button>
        </div>
        {children}
      </div>
    </div>
  );
}

const NOTE_TYPES = [
  { key: 'achievement', label: '🏆 Pencapaian', color: 'green' },
  { key: 'improvement', label: '📈 Perbaikan', color: 'blue' },
  { key: 'concern', label: '⚠️ Perhatian', color: 'yellow' },
  { key: 'feedback', label: '💬 Feedback', color: 'purple' },
  { key: 'goal', label: '🎯 Goal', color: 'teal' },
];

const TYPE_COLORS = { achievement: 'green', improvement: 'blue', concern: 'yellow', feedback: 'purple', goal: 'teal' };

export default function PerformanceNotes() {
  const nrp = getSession()?.nrp;
  const role = getSession()?.role;
  const [loading, setLoading] = useState(true);
  const [notes, setNotes] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [targetNrp, setTargetNrp] = useState('');
  const [noteType, setNoteType] = useState('feedback');
  const [content, setContent] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [filter, setFilter] = useState('all');

  const fetchNotes = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await supabase.rpc('get_performance_notes', { p_nrp: nrp });
      if (data?.ok) setNotes(data.data || []);
    } catch (e) { console.warn('Notes fetch error:', e); }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchNotes(); }, [fetchNotes]);

  const addNote = async () => {
    if (!content.trim()) return;
    setSubmitting(true);
    try {
      const { data } = await supabase.rpc('add_performance_note', {
        p_nrp: targetNrp || nrp,
        p_author: nrp,
        p_type: noteType,
        p_content: content
      });
      if (data?.ok) {
        setShowAdd(false);
        setContent('');
        setTargetNrp('');
        fetchNotes();
      }
    } catch (e) { console.warn('Add note error:', e); }
    setSubmitting(false);
  };

  const filtered = filter === 'all' ? notes : notes.filter(n => n.type === filter);

  return (
    <PageLayout title="📝 Catatan Kinerja">
      <div className="space-y-4">
        <Button onClick={() => setShowAdd(true)} className="w-full">
          ➕ Tambah Catatan
        </Button>

        {/* Type Filter */}
        <div className="flex gap-2 overflow-x-auto pb-2">
          <button
            onClick={() => setFilter('all')}
            className={`px-3 py-1.5 rounded-lg text-xs whitespace-nowrap ${
              filter === 'all' ? 'bg-blue-500 text-white' : 'bg-slate-800 text-slate-300'
            }`}
          >
            📋 Semua
          </button>
          {NOTE_TYPES.map(t => (
            <button
              key={t.key}
              onClick={() => setFilter(t.key)}
              className={`px-3 py-1.5 rounded-lg text-xs whitespace-nowrap ${
                filter === t.key ? 'bg-blue-500 text-white' : 'bg-slate-800 text-slate-300'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {loading ? <LoadingSpinner /> : filtered.length === 0 ? (
          <EmptyState icon="📝" title="Belum ada catatan" subtitle="Catatan kinerja akan muncul di sini" />
        ) : (
          <div className="space-y-2">
            {filtered.map((note, idx) => (
              <GlassCard key={idx} className="p-3">
                <div className="flex items-start justify-between mb-1">
                  <Badge color={TYPE_COLORS[note.type] || 'slate'}>
                    {NOTE_TYPES.find(t => t.key === note.type)?.label || note.type}
                  </Badge>
                  <span className="text-slate-500 text-xs">{note.created_at ? new Date(note.created_at).toLocaleDateString('id-ID') : '-'}</span>
                </div>
                <p className="text-white text-sm mt-2">{note.content || note.note || '-'}</p>
                <p className="text-slate-500 text-xs mt-1">
                  Oleh: {note.author || note.author_nrp || '-'} → {note.target_nrp || nrp}
                </p>
              </GlassCard>
            ))}
          </div>
        )}
      </div>

      {/* Add Note Modal */}
      {showAdd && (
        <Modal onClose={() => setShowAdd(false)} title="➕ Tambah Catatan Kinerja">
          <div className="space-y-3">
            {role === 'admin' || role === 'manager' ? (
              <Input label="Target NRP" value={targetNrp} onChange={setTargetNrp} placeholder="NRP karyawan (kosongkan untuk diri sendiri)" />
            ) : null}
            
            <div>
              <label className="text-xs text-slate-400 mb-1 block">Tipe Catatan</label>
              <div className="grid grid-cols-3 gap-2">
                {NOTE_TYPES.map(t => (
                  <button
                    key={t.key}
                    onClick={() => setNoteType(t.key)}
                    className={`py-2 rounded-lg text-xs ${
                      noteType === t.key ? 'bg-blue-500 text-white' : 'bg-slate-800 text-slate-300'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="text-xs text-slate-400 mb-1 block">Catatan</label>
              <textarea
                className="w-full bg-slate-800 border border-slate-600 rounded-lg p-2 text-white text-sm resize-none"
                rows={4}
                value={content}
                onChange={(e) => setContent(e.target.value)}
                placeholder="Tulis catatan kinerja..."
              />
            </div>

            <Button onClick={addNote} className="w-full" disabled={submitting}>
              {submitting ? '⏳ Menyimpan...' : '💾 Simpan Catatan'}
            </Button>
          </div>
        </Modal>
      )}
    </PageLayout>
  );
}
