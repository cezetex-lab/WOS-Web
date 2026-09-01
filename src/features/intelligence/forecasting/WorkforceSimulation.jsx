// ============================================================
// WorkforceSimulation.jsx — #90 Workforce Simulation
// RPC: run_simulation, get_simulations
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Input, StatItem, Divider
} from '../../../lib/design-system';

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

const SCENARIOS = [
  { key: 'turnover', label: '🔄 Turnover Impact', icon: '🔄', desc: 'Simulasi dampak turnover terhadap profit & headcount' },
  { key: 'hiring', label: '👥 Hiring Surge', icon: '👥', desc: 'Simulasi jika hiring 10-30% headcount baru' },
  { key: 'budget', label: '💰 Budget Cut', icon: '💰', desc: 'Simulasi dampak pengurangan budget SDM' },
  { key: 'kpi', label: '📊 KPI Improvement', icon: '📊', desc: 'Simulasi jika KPI naik 10-20%' },
];

const PRESET_SCENARIOS = [
  { name: 'Best Case', turnover: -5, hiring: 10, budget: 5, kpi: 15 },
  { name: 'Worst Case', turnover: 20, hiring: -5, budget: -15, kpi: -10 },
  { name: 'Status Quo', turnover: 0, hiring: 0, budget: 0, kpi: 0 },
  { name: 'Growth Mode', turnover: -3, hiring: 20, budget: 10, kpi: 10 },
];

export default function WorkforceSimulation() {
  const nrp = getSession()?.nrp;
  const [loading, setLoading] = useState(true);
  const [simulating, setSimulating] = useState(false);
  const [simulations, setSimulations] = useState([]);
  const [selectedScenario, setSelectedScenario] = useState(null);
  const [params, setParams] = useState({ turnover: 0, hiring: 0, budget: 0, kpi: 0 });
  const [result, setResult] = useState(null);

  const fetchSimulations = useCallback(async () => {
    setLoading(true);
    try {
      // Try to get past simulations
      const { data } = await supabase.rpc('get_simulations');
      if (data) setSimulations(data);
    } catch (e) { console.warn('Sim fetch error:', e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchSimulations(); }, [fetchSimulations]);

  const runSimulation = async () => {
    setSimulating(true);
    setResult(null);
    try {
      // Use the existing run_simulation RPC for turnover
      const { data } = await supabase.rpc('run_simulation', { p_turnover_change: params.turnover || 0 });
      if (data?.ok) {
        setResult({
          scenario: selectedScenario,
          params: { ...params },
          result: data.result || data,
          headline: data.msg || 'Simulasi selesai',
        });
      } else {
        // Fallback: calculate locally
        const { data: summary } = await supabase.rpc('get_dashboard_stats');
        const hc = summary?.total_employees || 2000;
        const avgSalary = 8000000;
        const currentCost = hc * avgSalary * 12;

        const newHc = Math.round(hc * (1 + (params.hiring || 0) / 100));
        const turnoverLoss = Math.round(hc * Math.max(0, params.turnover || 0) / 100);
        const newHcAfterTurnover = newHc - turnoverLoss;
        const newCost = newHcAfterTurnover * avgSalary * 12;
        const costDelta = newCost - currentCost;
        const profitImpact = -costDelta * 0.3;

        setResult({
          scenario: selectedScenario,
          params: { ...params },
          result: {
            current_hc: hc,
            new_hc: newHcAfterTurnover,
            turnover_loss: turnoverLoss,
            hiring_gain: Math.round(hc * Math.max(0, params.hiring || 0) / 100),
            cost_change: costDelta,
            profit_impact: profitImpact,
            roi_pct: currentCost > 0 ? Math.round((profitImpact / currentCost) * 10000) / 100 : 0,
          },
          headline: `Headcount: ${hc} → ${newHcAfterTurnover} | Cost: Rp ${costDelta > 0 ? '+' : ''}${(costDelta / 1000000).toFixed(1)}M`,
        });
      }
    } catch (e) {
      console.warn('Simulation error:', e);
      setResult({ error: 'Gagal menjalankan simulasi' });
    }
    setSimulating(false);
  };

  const applyPreset = (preset) => {
    setParams({ turnover: preset.turnover, hiring: preset.hiring, budget: preset.budget, kpi: preset.kpi });
    setSelectedScenario(preset.name);
  };

  return (
    <PageLayout title="🧪 Workforce Simulation">
      <div className="space-y-4">
        {/* Preset Scenarios */}
        <GlassCard className="p-4">
          <p className="text-white font-semibold text-sm mb-3">⚡ Quick Scenarios</p>
          <div className="grid grid-cols-2 gap-2">
            {PRESET_SCENARIOS.map((p) => (
              <button
                key={p.name}
                onClick={() => applyPreset(p)}
                className={`p-3 rounded-xl text-left transition-all ${
                  selectedScenario === p.name
                    ? 'bg-blue-500/20 border border-blue-500/30'
                    : 'bg-slate-800/50 hover:bg-slate-800'
                }`}
              >
                <p className="text-white text-xs font-semibold">{p.name}</p>
                <p className="text-slate-400 text-[10px]">
                  TO: {p.turnover > 0 ? '+' : ''}{p.turnover}% | Hire: {p.hiring > 0 ? '+' : ''}{p.hiring}%
                </p>
              </button>
            ))}
          </div>
        </GlassCard>

        {/* Custom Parameters */}
        <GlassCard className="p-4">
          <p className="text-white font-semibold text-sm mb-3">🎛️ Custom Parameters</p>
          <div className="space-y-3">
            {[
              { key: 'turnover', label: '🔄 Turnover Change (%)', min: -50, max: 50 },
              { key: 'hiring', label: '👥 Hiring Change (%)', min: -50, max: 100 },
              { key: 'budget', label: '💰 Budget Change (%)', min: -50, max: 50 },
              { key: 'kpi', label: '📊 KPI Change (%)', min: -30, max: 30 },
            ].map((p) => (
              <div key={p.key}>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs text-slate-400">{p.label}</label>
                  <span className={`text-xs font-mono ${params[p.key] > 0 ? 'text-green-400' : params[p.key] < 0 ? 'text-red-400' : 'text-slate-400'}`}>
                    {params[p.key] > 0 ? '+' : ''}{params[p.key]}%
                  </span>
                </div>
                <input
                  type="range"
                  min={p.min}
                  max={p.max}
                  value={params[p.key]}
                  onChange={(e) => setParams({ ...params, [p.key]: parseInt(e.target.value) })}
                  className="w-full h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-blue-500"
                />
              </div>
            ))}
          </div>
          <Button onClick={runSimulation} className="w-full mt-4" disabled={simulating}>
            {simulating ? '⏳ Mensimulasikan...' : '🧪 Jalankan Simulasi'}
          </Button>
        </GlassCard>

        {/* Results */}
        {result && !result.error && (
          <GlassCard className="p-4">
            <p className="text-white font-semibold text-sm mb-3">📊 Hasil Simulasi</p>
            <p className="text-slate-300 text-xs mb-3">{result.headline}</p>
            <div className="grid grid-cols-2 gap-3">
              <StatItem label="Headcount" value={result.result.new_hc || '-'} color="blue" />
              <StatItem label="Turnover Loss" value={result.result.turnover_loss || 0} color="red" />
              <StatItem label="Hiring Gain" value={result.result.hiring_gain || 0} color="green" />
              <StatItem label="Cost Change" value={`Rp ${((result.result.cost_change || 0) / 1000000).toFixed(1)}M`} color={result.result.cost_change > 0 ? 'red' : 'green'} />
            </div>
            {result.result.profit_impact !== undefined && (
              <div className="mt-3 bg-slate-800/50 rounded-lg p-3 text-center">
                <p className={`text-2xl font-bold ${result.result.profit_impact >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                  {result.result.profit_impact >= 0 ? '+' : ''}Rp {(result.result.profit_impact / 1000000).toFixed(1)}M
                </p>
                <p className="text-xs text-slate-400">Profit Impact (est.)</p>
              </div>
            )}
          </GlassCard>
        )}

        {result?.error && (
          <GlassCard className="p-4 border-red-500/30">
            <p className="text-red-400 text-sm">⚠️ {result.error}</p>
          </GlassCard>
        )}

        {/* History */}
        {simulations.length > 0 && (
          <GlassCard className="p-4">
            <p className="text-white font-semibold text-sm mb-3">📋 Riwayat Simulasi</p>
            <div className="space-y-2">
              {simulations.map((sim) => (
                <div key={sim.id} className="bg-slate-800/30 rounded-lg p-2">
                  <p className="text-white text-xs">{sim.scenario_name || sim.id}</p>
                  <p className="text-slate-500 text-[10px]">{new Date(sim.created_at).toLocaleString('id-ID')}</p>
                </div>
              ))}
            </div>
          </GlassCard>
        )}

        {loading && <LoadingSpinner />}
      </div>
    </PageLayout>
  );
}
