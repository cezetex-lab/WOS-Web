// ============================================================
// IncentiveCalc.jsx — #45 Incentive Auto-Calculation
// RPC: calculate_incentive, get_incentives (from 028)
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../../lib/supabase-browser';
import useAdminAuth from '@/hooks/useAdminAuth';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, StatItem, Input, Divider
} from '../../../lib/design-system';

function formatRupiah(n) {
  return 'Rp ' + (n || 0).toLocaleString('id-ID');
}

const INCENTIVE_TYPES = [
  { key: 'kpi', label: '🎯 KPI Bonus', desc: 'Berdasarkan skor KPI bulanan', color: 'green' },
  { key: 'attendance', label: '✅ Kehadiran', desc: 'Bonus hadir sempurna', color: 'blue' },
  { key: 'production', label: '🏭 Produksi', desc: 'Bonus capaian produksi', color: 'orange' },
  { key: 'safety', label: '🦺 Safety', desc: 'Bonus zero incident', color: 'teal' },
];

export default function IncentiveCalc() {
  useAdminAuth(["admin_pusat", "admin_finance"]);
  const nrp = getSession()?.nrp;
  const [loading, setLoading] = useState(true);
  const [incentives, setIncentives] = useState([]);
  const [calculating, setCalculating] = useState(false);
  const [targetNrp, setTargetNrp] = useState('');
  const [period, setPeriod] = useState(getCurrentPeriod());
  const [tab, setTab] = useState('list');

  function getCurrentPeriod() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  }

  const fetchIncentives = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await supabase.rpc('get_incentives', { p_nrp: nrp });
      if (data?.ok) setIncentives(data.data || []);
    } catch (e) {
      // Fallback: try direct query
      try {
        const { data } = await supabase.rpc('get_incentives', { p_nrp: nrp });
        if (data) setIncentives(data);
      } catch (e2) { }
    }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchIncentives(); }, [fetchIncentives]);

  const calculateIncentive = async (calcNrp) => {
    setCalculating(true);
    try {
      const { data } = await supabase.rpc('calculate_incentive', { p_nrp: calcNrp || nrp });
      if (data?.ok) {
        alert(`✅ Incentive dihitung!\n\nKPI Bonus: ${formatRupiah(data.kpi_bonus)}\nAttendance: ${formatRupiah(data.attendance_bonus)}\nTotal: ${formatRupiah(data.total)}`);
        fetchIncentives();
      } else {
        alert('⚠️ Gagal menghitung incentive: ' + (data?.error || 'Unknown error'));
      }
    } catch (e) { }
    setCalculating(false);
  };

  // Aggregate stats
  const totalPaid = incentives.reduce((sum, i) => sum + (i.amount || i.total || 0), 0);
  const thisMonth = incentives.filter(i => i.period === period);
  const totalThisMonth = thisMonth.reduce((sum, i) => sum + (i.amount || i.total || 0), 0);

  const tabs = [
    { key: 'list', label: '📋 Riwayat Incentive' },
    { key: 'calc', label: '🧮 Hitung Incentive' },
    { key: 'rules', label: '📐 Aturan' },
  ];

  return (
    <PageLayout title="🧮 Insentif Otomatis">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {/* Stats */}
        <div className="grid grid-cols-2 gap-3">
          <StatItem label="Total Dibayar" value={formatRupiah(totalPaid)} />
          <StatItem label="Bulan Ini" value={formatRupiah(totalThisMonth)} color="green" />
        </div>

        {tab === 'list' && (
          loading ? <LoadingSpinner /> : incentives.length === 0 ? (
            <EmptyState icon="🧮" title="Belum ada insentif" subtitle="Hitung insentif dari tab 'Hitung Incentive'" />
          ) : (
            <div className="space-y-2">
              {incentives.map((inc, idx) => (
                <GlassCard key={idx} className="p-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-white text-sm font-medium">{inc.period || inc.periode || '-'}</p>
                      <p className="text-slate-400 text-xs">{inc.type || inc.category || 'General'} · {inc.nrp}</p>
                    </div>
                    <p className="text-green-400 font-semibold text-sm">{formatRupiah(inc.amount || inc.total)}</p>
                  </div>
                  {inc.detail && (
                    <p className="text-slate-500 text-xs mt-1">{inc.detail}</p>
                  )}
                </GlassCard>
              ))}
            </div>
          )
        )}

        {tab === 'calc' && (
          <div className="space-y-4">
            <GlassCard className="p-4">
              <p className="text-white font-semibold text-sm mb-3">🧮 Hitung Insentif</p>
              <Input label="NRP Karyawan" value={targetNrp} onChange={setTargetNrp} placeholder="NRP (kosongkan untuk diri sendiri)" />
              <Input label="Periode" value={period} onChange={setPeriod} placeholder="YYYY-MM" />
              <Button onClick={() => calculateIncentive(targetNrp)} className="w-full mt-3" disabled={calculating}>
                {calculating ? '⏳ Menghitung...' : '🧮 Hitung Sekarang'}
              </Button>
            </GlassCard>

            {/* Formula Preview */}
            <GlassCard className="p-4">
              <p className="text-white font-semibold text-sm mb-2">📐 Formula Perhitungan</p>
              <div className="space-y-2 text-xs">
                {INCENTIVE_TYPES.map(t => (
                  <div key={t.key} className="flex items-center justify-between bg-slate-800/30 rounded p-2">
                    <span className="text-white">{t.label}</span>
                    <span className="text-slate-400">{t.desc}</span>
                  </div>
                ))}
              </div>
            </GlassCard>
          </div>
        )}

        {tab === 'rules' && (
          <div className="space-y-3">
            <GlassCard className="p-4">
              <p className="text-white font-semibold text-sm mb-2">📐 Aturan Insentif</p>
              <div className="space-y-2 text-xs text-slate-300">
                <p>🎯 <strong>KPI Bonus:</strong> Skor KPI × Bobo persentase × Gaji Pokok</p>
                <p>✅ <strong>Kehadiran:</strong> Hadir sempurna = 2% gaji · 1 alpha = -5%</p>
                <p>🏭 <strong>Produksi:</strong> Over target 110%+ = bonus 5% · Under 90% = -3%</p>
                <p>🦺 <strong>Safety:</strong> Zero incident bulanan = 3% bonus</p>
                <Divider />
                <p className="text-slate-400">Perhitungan dilakukan otomatis setiap akhir bulan oleh sistem.</p>
              </div>
            </GlassCard>
          </div>
        )}
      </div>
    </PageLayout>
  );
}
