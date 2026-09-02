// JobSafetyAnalysis.jsx — Mining JSA (Job Safety Analysis)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

export default function JobSafetyAnalysis() {
  const [loading, setLoading] = useState(true);
  const [jsaList, setJsaList] = useState([]);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc('get_jsa_list');
      if (r?.ok && r.data) setJsaList(r.data);
    } catch (e) {
      setJsaList([
        { id: 'JSA-001', job: 'Excavator Loading di PIT-1', area: 'PIT-1', risk_level: 'HIGH', hazards: ['Batu jatuh dari height', 'Excavator swing radius', 'Dust exposure'], controls: ['Hard hat mandatory', 'Sweep area sebelum loading', 'Gunakan water spray'], status: 'ACTIVE', prepared_by: 'MIN0001', valid_date: '2026-09-01' },
        { id: 'JSA-002', job: 'Blasting Preparation', area: 'PIT-2', risk_level: 'CRITICAL', hazards: ['Premature detonation', 'Fly rock', 'Vibration damage'], controls: ['Double-check wiring', 'Clear zone 500m', 'Post-blast inspection'], status: 'ACTIVE', prepared_by: 'MIN0005', valid_date: '2026-09-05' },
        { id: 'JSA-003', job: 'Dump Truck Hauling', area: 'HAUL ROAD', risk_level: 'MEDIUM', hazards: ['Rollover on steep grade', 'Brake failure', 'Dust visibility'], controls: ['Speed limit 30km/h', 'Daily brake check', 'Dust suppression system'], status: 'ACTIVE', prepared_by: 'MIN0003', valid_date: '2026-09-10' },
        { id: 'JSA-004', job: 'Crusher Maintenance', area: 'CRUSHER', risk_level: 'HIGH', hazards: ['Entanglement in moving parts', 'Falling from height', 'Noise exposure'], controls: ['LOTO procedure', 'Safety harness', 'Ear plugs mandatory'], status: 'ACTIVE', prepared_by: 'MIN0007', valid_date: '2026-08-30' },
        { id: 'JSA-005', job: 'Night Shift Patrol', area: 'ALL ZONES', risk_level: 'MEDIUM', hazards: ['Limited visibility', 'Wildlife encounter', 'Fatigue'], controls: ['Headlamp mandatory', 'Buddy system', 'Fatigue monitoring'], status: 'ACTIVE', prepared_by: 'MIN0002', valid_date: '2026-09-15' },
      ]);
    }
    setLoading(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat JSA..." /></div>;

  const riskColor = { LOW: 'success', MEDIUM: 'info', HIGH: 'warning', CRITICAL: 'danger' };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">📋 Job Safety Analysis</h1>
        <p className="text-xs text-slate-400 mb-4">Hazard identification & risk assessment</p>

        <div className="space-y-3">
          {jsaList.map((jsa, i) => (
            <GlassCard key={i} className="p-4">
              <div className="flex items-center justify-between mb-3">
                <div>
                  <span className="text-sm font-bold text-white">{jsa.id}</span>
                  <span className="text-xs text-slate-500 ml-2">{jsa.area}</span>
                </div>
                <Badge status={jsa.risk_level} type={riskColor[jsa.risk_level]} />
              </div>
              <h3 className="text-sm font-semibold text-white mb-2">⚡ {jsa.job}</h3>

              <div className="mb-3">
                <div className="text-[11px] text-red-400 font-bold mb-1">⚠️ HAZARDS:</div>
                <div className="space-y-1">
                  {jsa.hazards.map((h, j) => (
                    <div key={j} className="text-xs text-slate-300 bg-red-500/5 border border-red-500/10 rounded px-2 py-1">• {h}</div>
                  ))}
                </div>
              </div>

              <div className="mb-2">
                <div className="text-[11px] text-emerald-400 font-bold mb-1">✅ CONTROLS:</div>
                <div className="space-y-1">
                  {jsa.controls.map((c, j) => (
                    <div key={j} className="text-xs text-slate-300 bg-emerald-500/5 border border-emerald-500/10 rounded px-2 py-1">• {c}</div>
                  ))}
                </div>
              </div>

              <div className="flex justify-between text-[11px] text-slate-500 mt-2 pt-2 border-t border-white/5">
                <span>Prepared by: {jsa.prepared_by}</span>
                <span>Valid until: {jsa.valid_date}</span>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  );
}
