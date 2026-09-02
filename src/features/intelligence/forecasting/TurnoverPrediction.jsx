// ============================================================
// TurnoverPrediction.jsx — #89 Turnover Prediction + #85 Flight Risk
// RPC: get_turnover_prediction, get_flight_risk_list, get_early_warning
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, StatItem, Divider
} from '../../../lib/design-system';

function getRiskColor(score) {
  if (score >= 70) return 'red';
  if (score >= 40) return 'yellow';
  return 'green';
}

function getRiskLabel(score) {
  if (score >= 70) return '🔴 High Risk';
  if (score >= 40) return '🟡 Medium Risk';
  return '🟢 Low Risk';
}

function getRiskIcon(score) {
  if (score >= 70) return '🚨';
  if (score >= 40) return '⚠️';
  return '✅';
}

export default function TurnoverPrediction() {
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('prediction');
  const [predictions, setPredictions] = useState([]);
  const [flightRisks, setFlightRisks] = useState([]);
  const [earlyWarnings, setEarlyWarnings] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [pred, fr, ew] = await Promise.all([
        supabase.rpc('get_turnover_prediction'),
        supabase.rpc('get_flight_risk_list'),
        supabase.rpc('get_early_warning'),
      ]);
      if (pred?.data?.ok) setPredictions(pred.data.data || []);
      if (fr?.data?.ok) setFlightRisks(fr.data.data || []);
      if (ew?.data?.ok) setEarlyWarnings(ew.data.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Stats
  const highRisk = predictions.filter(p => (p.risk_score || 0) >= 70).length;
  const medRisk = predictions.filter(p => (p.risk_score || 0) >= 40 && (p.risk_score || 0) < 70).length;
  const lowRisk = predictions.filter(p => (p.risk_score || 0) < 40).length;

  const tabs = [
    { key: 'prediction', label: '🔮 Prediksi Turnover' },
    { key: 'flight', label: '✈️ Flight Risk' },
    { key: 'warnings', label: '⚠️ Early Warning' },
  ];

  return (
    <PageLayout title="🔮 Prediksi Turnover & Flight Risk">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {/* Stats */}
        <div className="grid grid-cols-3 gap-3">
          <StatItem label="🔴 High Risk" value={highRisk} color="red" />
          <StatItem label="🟡 Medium" value={medRisk} color="yellow" />
          <StatItem label="🟢 Low" value={lowRisk} color="green" />
        </div>

        {tab === 'prediction' && (
          loading ? <LoadingSpinner /> : predictions.length === 0 ? (
            <EmptyState icon="🔮" title="Belum ada data prediksi" subtitle="Prediksi akan muncul berdasarkan KPI & kehadiran" />
          ) : (
            <div className="space-y-2">
              {predictions.map((p, idx) => (
                <GlassCard key={idx} className="p-3">
                  <div className="flex items-start justify-between mb-2">
                    <div className="flex-1">
                      <div className="flex items-center gap-2">
                        <span className="text-sm">{getRiskIcon(p.risk_score)}</span>
                        <p className="text-white text-sm font-semibold">{p.nama || p.nrp}</p>
                      </div>
                      <p className="text-slate-400 text-xs">{p.divisi || '-'} · KPI: {p.kpi_score || '-'}</p>
                    </div>
                    <div className="text-right">
                      <Badge color={getRiskColor(p.risk_score)}>{p.risk_score || 0}%</Badge>
                      <p className="text-[11px] text-slate-500 mt-1">{getRiskLabel(p.risk_score)}</p>
                    </div>
                  </div>
                  {/* Risk factors */}
                  {p.factors && Array.isArray(p.factors) && p.factors.length > 0 && (
                    <div className="flex flex-wrap gap-1">
                      {p.factors.filter(f => f !== 'OK').map((f, i) => (
                        <Badge key={i} color="red">{f}</Badge>
                      ))}
                    </div>
                  )}
                  {/* Risk bar */}
                  <div className="w-full bg-slate-700 rounded-full h-1.5 mt-2">
                    <div
                      className={`h-1.5 rounded-full ${(p.risk_score || 0) >= 70 ? 'bg-red-500' : (p.risk_score || 0) >= 40 ? 'bg-yellow-500' : 'bg-green-500'}`}
                      style={{ width: `${Math.min(100, p.risk_score || 0)}%` }}
                    />
                  </div>
                </GlassCard>
              ))}
            </div>
          )
        )}

        {tab === 'flight' && (
          loading ? <LoadingSpinner /> : flightRisks.length === 0 ? (
            <EmptyState icon="✈️" title="Tidak ada flight risk" subtitle="Tidak ada karyawan dengan risiko resign tinggi" />
          ) : (
            <div className="space-y-2">
              {flightRisks.map((f, idx) => (
                <GlassCard key={idx} className="p-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-white text-sm font-medium">{f.nama || f.nrp}</p>
                      <p className="text-slate-400 text-xs">{f.divisi || '-'} · KPI: {f.kpi_score || '-'}</p>
                    </div>
                    <Badge color="red">✈️ Flight Risk</Badge>
                  </div>
                  {f.reason && (
                    <p className="text-slate-500 text-xs mt-1">Alasan: {f.reason}</p>
                  )}
                </GlassCard>
              ))}
            </div>
          )
        )}

        {tab === 'warnings' && (
          loading ? <LoadingSpinner /> : earlyWarnings.length === 0 ? (
            <EmptyState icon="⚠️" title="Tidak ada peringatan" subtitle="Sistem belum mendeteksi risiko" />
          ) : (
            <div className="space-y-2">
              {earlyWarnings.map((w, idx) => (
                <GlassCard key={idx} className="p-3">
                  <div className="flex items-start gap-2">
                    <span className="text-lg">⚠️</span>
                    <div className="flex-1">
                      <p className="text-white text-sm font-medium">{w.title || w.nrp || '-'}</p>
                      <p className="text-slate-400 text-xs">{w.message || w.description || w.detail || '-'}</p>
                      {w.severity && (
                        <Badge color={w.severity === 'high' ? 'red' : w.severity === 'medium' ? 'yellow' : 'blue'} className="mt-1">
                          {w.severity}
                        </Badge>
                      )}
                    </div>
                  </div>
                </GlassCard>
              ))}
            </div>
          )
        )}

        {/* AI Insight */}
        <GlassCard className="p-4">
          <p className="text-white font-semibold text-sm mb-2">🤖 AI Insight</p>
          <p className="text-slate-300 text-xs leading-relaxed">
            {highRisk > 0
              ? `⚠️ ${highRisk} karyawan berisiko tinggi resign. Faktor utama: KPI rendah dan kehadiran buruk. 
                 Rekomendasi: Lakukan 1-on-1 coaching dan review kompensasi.`
              : lowRisk > 0
              ? `✅ Stabilitas tim cukup baik. ${lowRisk} karyawan dalam zona aman. 
                 Pertahankan engagement dengan regular check-in.`
              : '📊 Data belum cukup untuk analisis mendalam. Minimal butuh 1 bulan data KPI dan kehadiran.'
            }
          </p>
        </GlassCard>
      </div>
    </PageLayout>
  );
}
