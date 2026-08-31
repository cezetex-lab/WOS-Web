// Review360.jsx — Penilaian 360 derajat
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState } from '../../../lib/design-system';

export default function Review360() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState({});
  const [reviews, setReviews] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_reviews_360');
      const d = result || {};
      setData(d.summary || {});
      setReviews(d.reviews || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const dimensions = [
    { key: 'leadership', label: 'Leadership', icon: '👑', color: 'bg-purple-500' },
    { key: 'communication', label: 'Communication', icon: '💬', color: 'bg-blue-500' },
    { key: 'teamwork', label: 'Teamwork', icon: '🤝', color: 'bg-teal-500' },
    { key: 'innovation', label: 'Innovation', icon: '💡', color: 'bg-yellow-500' },
  ];

  const getScoreColor = (s) => s >= 80 ? 'green' : s >= 60 ? 'teal' : s >= 40 ? 'orange' : 'red';

  if (loading) return <PageLayout backTo="/admin" title="360° Review"><LoadingSpinner text="Memuat 360° review..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🔄 360° Review" subtitle={`${reviews.length} review`}>
      {/* Score Radar */}
      <GlassCard accent="blue" className="mb-6">
        <h3 className="text-sm font-bold text-white mb-4 text-center">📊 Skor Rata-rata</h3>
        <div className="grid grid-cols-2 gap-4">
          {dimensions.map(d => {
            const score = data[`avg_${d.key}`] || 0;
            return (
              <div key={d.key} className="text-center">
                <div className="w-20 h-20 mx-auto rounded-full border-4 border-slate-700 flex items-center justify-center relative">
                  <div className={`absolute inset-0 rounded-full border-4 border-transparent`} style={{ borderTopColor: score >= 70 ? '#10b981' : score >= 50 ? '#f59e0b' : '#ef4444', transform: `rotate(${(score / 100) * 360}deg)` }} />
                  <span className="text-lg font-bold text-white">{score}</span>
                </div>
                <p className="text-xs text-slate-400 mt-2">{d.icon} {d.label}</p>
              </div>
            );
          })}
        </div>
        <div className="text-center mt-4">
          <Badge status={`${data.total_reviews || 0} reviews`} type="blue" />
        </div>
      </GlassCard>

      {/* Individual Reviews */}
      <GlassCard accent="teal">
        <h3 className="text-sm font-bold text-white mb-3">📝 Detail Review</h3>
        <div className="space-y-2">
          {reviews.map((r, i) => (
            <div key={i} className="p-3 rounded-lg bg-slate-800/30 border border-white/5">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="text-sm">👤</span>
                  <span className="text-xs font-semibold text-white">{r.reviewer_nrp}</span>
                </div>
                <Badge status={r.relationship} type="info" />
              </div>
              <div className="grid grid-cols-4 gap-2 mb-2">
                {['leadership', 'communication', 'teamwork', 'innovation'].map(key => (
                  <div key={key} className="text-center">
                    <p className="text-[10px] text-slate-400 capitalize">{key.slice(0, 4)}</p>
                    <p className={`text-xs font-bold text-${getScoreColor(r[`${key}_score`] || 0)}-400`}>{r[`${key}_score`] || 0}</p>
                  </div>
                ))}
              </div>
              {r.comments && <p className="text-[10px] text-slate-300 italic">"{r.comments}"</p>}
            </div>
          ))}
          {reviews.length === 0 && <EmptyState title="Belum ada review 360°" icon="🔄" />}
        </div>
      </GlassCard>
    </PageLayout>
  );
}
