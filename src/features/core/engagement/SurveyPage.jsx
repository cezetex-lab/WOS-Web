// ============================================================
// SurveyPage.jsx — #61 eNPS Survey & Pulse Survey
// RPC: get_active_surveys, submit_survey, get_survey_results, admin_get_surveys
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../../lib/supabase-browser';
import useAdminAuth from '@/hooks/useAdminAuth';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, StatItem, Divider
} from '../../../lib/design-system';

// Inline Modal
function Modal({ onClose, title, children }) {
  useAdminAuth(["admin_pusat", "admin_hrd"]);
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

const ENPS_LABELS = [
  { min: 0, max: 6, label: 'Detractor', color: 'red', icon: '😟' },
  { min: 7, max: 8, label: 'Passive', color: 'yellow', icon: '😐' },
  { min: 9, max: 10, label: 'Promoter', color: 'green', icon: '😊' },
];

function getEnpsLabel(score) {
  return ENPS_LABELS.find(l => score >= l.min && score <= l.max) || ENPS_LABELS[0];
}

function getEnpsColor(enps) {
  if (enps >= 50) return 'green';
  if (enps >= 0) return 'yellow';
  return 'red';
}

export default function SurveyPage() {
  const nrp = getSession()?.nrp;
  const role = getSession()?.role;
  const [loading, setLoading] = useState(true);
  const [surveys, setSurveys] = useState([]);
  const [activeSurvey, setActiveSurvey] = useState(null);
  const [answers, setAnswers] = useState({});
  const [score, setScore] = useState(7);
  const [submitting, setSubmitting] = useState(false);
  const [results, setResults] = useState(null);
  const [tab, setTab] = useState(role === 'admin' ? 'results' : 'list');

  const fetchSurveys = useCallback(async () => {
    setLoading(true);
    try {
      const fn = role === 'admin' ? 'admin_get_surveys' : 'get_active_surveys';
      const { data } = await supabase.rpc(fn);
      if (data?.ok) setSurveys(data.data || []);
    } catch (e) { }
    setLoading(false);
  }, [role]);

  useEffect(() => { fetchSurveys(); }, [fetchSurveys]);

  const fetchResults = async (surveyId) => {
    try {
      const { data } = await supabase.rpc('get_survey_results', { p_survey_id: surveyId });
      if (data?.ok) setResults(data);
    } catch (e) { }
  };

  const submitSurvey = async () => {
    if (!activeSurvey) return;
    setSubmitting(true);
    try {
      const { data } = await supabase.rpc('submit_survey', {
        p_survey_id: activeSurvey.id, p_nrp: nrp, p_answers: answers, p_score: score
      });
      if (data?.ok) {
        setActiveSurvey(null);
        setAnswers({});
        setScore(7);
        alert('✅ Terima kasih sudah mengisi survei!');
      }
    } catch (e) { }
    setSubmitting(false);
  };

  const tabs = role === 'admin'
    ? [{ key: 'list', label: '📋 Survei' }, { key: 'results', label: '📊 Hasil & eNPS' }]
    : [{ key: 'list', label: '📋 Survei Tersedia' }];

  return (
    <PageLayout title="📊 eNPS & Survei Kepuasan">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {tab === 'list' && (
          <>
            {loading ? <LoadingSpinner /> : surveys.length === 0 ? (
              <EmptyState icon="📋" title="Belum ada survei aktif" subtitle="Survei akan muncul di sini saat HR mengirimkan" />
            ) : (
              <div className="space-y-3">
                {surveys.map((s) => (
                  <GlassCard key={s.id} className="p-4">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <p className="text-white font-semibold text-sm">{s.title || `Survei #${s.id}`}</p>
                        {s.questions && (
                          <p className="text-slate-400 text-xs mt-1">
                            {Array.isArray(s.questions) ? s.questions.length : '?'} pertanyaan
                          </p>
                        )}
                      </div>
                      {role !== 'admin' ? (
                        <Button onClick={() => setActiveSurvey(s)} size="sm">📝 Isi</Button>
                      ) : (
                        <Button onClick={() => { fetchResults(s.id); }} variant="secondary" size="sm">📊 Hasil</Button>
                      )}
                    </div>
                  </GlassCard>
                ))}
              </div>
            )}
          </>
        )}

        {tab === 'results' && (
          <>
            {results ? (
              <div className="space-y-4">
                <GlassCard className="p-4">
                  <p className="text-white font-semibold text-sm mb-3">📊 Ringkasan eNPS</p>
                  <div className="grid grid-cols-2 gap-3">
                    <StatItem label="Total Responden" value={results.total || 0} />
                    <StatItem label="eNPS Score" value={results.enps || 0} color={getEnpsColor(results.enps)} />
                    <StatItem label="Promoters (9-10)" value={results.promoter || 0} color="green" />
                    <StatItem label="Detractors (0-6)" value={results.detractor || 0} color="red" />
                  </div>
                  <div className="mt-3 bg-slate-800/50 rounded-lg p-3 text-center">
                    <p className="text-3xl font-bold text-white">{results.enps || 0}</p>
                    <p className="text-xs text-slate-400">Net Promoter Score</p>
                    <Badge color={getEnpsColor(results.enps)} className="mt-2">
                      {(results.enps || 0) >= 50 ? '🏆 Excellent' : (results.enps || 0) >= 0 ? '👍 Good' : '⚠️ Needs Improvement'}
                    </Badge>
                  </div>
                </GlassCard>
              </div>
            ) : (
              <EmptyState icon="📊" title="Pilih survei untuk melihat hasil" subtitle="Klik 'Hasil' pada salah satu survei" />
            )}
          </>
        )}
      </div>

      {/* Fill Survey Modal */}
      {activeSurvey && (
        <Modal onClose={() => setActiveSurvey(null)} title={`📝 ${activeSurvey.title || 'Isi Survei'}`}>
          <div className="space-y-4">
            <p className="text-slate-300 text-xs">Skala 0-10: Seberapa besar kemungkinan Anda merekomendasikan perusahaan ini sebagai tempat kerja?</p>
            
            {/* NPS Score Selector */}
            <div className="flex gap-1 flex-wrap justify-center">
              {Array.from({ length: 11 }, (_, i) => (
                <button
                  key={i}
                  onClick={() => setScore(i)}
                  className={`w-9 h-9 rounded-lg text-sm font-bold transition-all ${
                    score === i
                      ? getEnpsLabel(i).color === 'green' ? 'bg-green-500 text-white'
                        : getEnpsLabel(i).color === 'yellow' ? 'bg-yellow-500 text-white'
                        : 'bg-red-500 text-white'
                      : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
                  }`}
                >
                  {i}
                </button>
              ))}
            </div>
            <div className="flex justify-between text-xs text-slate-400 px-1">
              <span>😟 Tidak</span>
              <span>😐 Netral</span>
              <span>😊 Sangat</span>
            </div>

            {/* Optional Comments */}
            {activeSurvey.questions && Array.isArray(activeSurvey.questions) && activeSurvey.questions.map((q, idx) => (
              <div key={idx}>
                <p className="text-white text-xs mb-1">{q}</p>
                <textarea
                  className="w-full bg-slate-800 border border-slate-600 rounded-lg p-2 text-white text-sm resize-none"
                  rows={2}
                  value={answers[idx] || ''}
                  onChange={(e) => setAnswers({ ...answers, [idx]: e.target.value })}
                  placeholder="Jawaban Anda..."
                />
              </div>
            ))}

            <Button onClick={submitSurvey} className="w-full" disabled={submitting}>
              {submitting ? '⏳ Mengirim...' : '✅ Kirim Survei'}
            </Button>
          </div>
        </Modal>
      )}
    </PageLayout>
  );
}
