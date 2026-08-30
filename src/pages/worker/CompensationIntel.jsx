// ============================================================
// CompensationIntel.jsx — #42 Compensation Intelligence
// Analisis kompensasi: basic, allowance, deduction, benefit
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Badge, LoadingSpinner, EmptyState,
  StatItem, SectionHeader
} from '../../lib/design-system';

const fmt = (n) => Number(n || 0).toLocaleString('id-ID');

export default function CompensationIntel() {
  const nrp = getSession()?.nrp || 'NRP001';
  const [loading, setLoading] = useState(true);
  const [payroll, setPayroll] = useState([]);
  const [benefits, setBenefits] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [p, b] = await Promise.all([
        rpc('get_worker_payroll', { p_nrp: nrp }),
        rpc('get_worker_benefits', { p_nrp: nrp }),
      ]);
      setPayroll(p?.data || p || []);
      setBenefits(b?.data || b || []);
    } catch (err) {
      console.error(err);
    }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Latest payroll
  const latest = Array.isArray(payroll) && payroll.length > 0 ? payroll[payroll.length - 1] : {};
  const basic = Number(latest.basic_salary || latest.gaji_pokok || 0);
  const allowances = Number(latest.allowances || latest.tunjangan || 0);
  const deductions = Number(latest.deductions || latest.potongan || 0);
  const net = Number(latest.net_salary || latest.gaji_bersih || 0) || (basic + allowances - deductions);

  // Trend
  const months = Array.isArray(payroll) ? payroll.slice(-6) : [];

  if (loading) return <PageLayout backTo="/worker" title="Compensation Intel"><LoadingSpinner text="Memuat data kompensasi..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="Compensation Intelligence" subtitle="Analisis kompensasi bulanan">
      {/* ── SUMMARY ── */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        <StatItem label="Gaji Pokok" value={fmt(basic)} color="#38bdf8" suffix="" />
        <StatItem label="Tunjangan" value={fmt(allowances)} color="#34d399" suffix="" />
        <StatItem label="Potongan" value={fmt(deductions)} color="#f87171" suffix="" />
        <StatItem label="Gaji Bersih" value={fmt(net)} color="#2dd4bf" suffix="" />
      </div>

      {/* ── BREAKDOWN ── */}
      <GlassCard title="Breakdown Gaji" icon="💰" accent="teal" className="mb-4">
        <div className="space-y-2">
          {[
            { label: 'Gaji Pokok', value: basic, color: 'bg-blue-500' },
            { label: 'Tunjangan', value: allowances, color: 'bg-emerald-500' },
            { label: 'Potongan', value: deductions, color: 'bg-red-500', negative: true },
          ].map((item, i) => (
            <div key={i} className="flex items-center justify-between py-2 border-b border-white/3 last:border-0">
              <div className="flex items-center gap-2">
                <div className={`w-2 h-2 rounded-full ${item.color}`} />
                <span className="text-xs text-slate-300">{item.label}</span>
              </div>
              <span className={`text-xs font-bold ${item.negative ? 'text-red-400' : 'text-white'}`}>
                {item.negative ? '-' : ''} Rp {fmt(item.value)}
              </span>
            </div>
          ))}
          <div className="flex items-center justify-between py-2 border-t border-white/10">
            <span className="text-sm font-bold text-teal-400">Total Bersih</span>
            <span className="text-sm font-bold text-teal-400">Rp {fmt(net)}</span>
          </div>
        </div>
      </GlassCard>

      {/* ── BENEFITS ── */}
      <GlassCard title="Benefit Aktif" icon="🎁" accent="green" className="mb-4">
        {benefits.length === 0 ? (
          <p className="text-xs text-slate-500">Tidak ada benefit terdaftar</p>
        ) : (
          <div className="space-y-2">
            {(Array.isArray(benefits) ? benefits : []).map((b, i) => (
              <div key={i} className="flex items-center justify-between p-2 bg-slate-900/40 rounded-xl border border-white/5">
                <div>
                  <p className="text-xs font-bold text-white">{b.name || b.nama || '-'}</p>
                  <p className="text-[10px] text-slate-500">{b.type || b.tipe || '-'}</p>
                </div>
                <Badge status={b.status || 'Aktif'} type="success" />
              </div>
            ))}
          </div>
        )}
      </GlassCard>

      {/* ── PAYROLL HISTORY ── */}
      <GlassCard title="Riwayat Gaji (6 Bulan)" icon="📈" accent="blue">
        {months.length === 0 ? (
          <EmptyState icon="💰" title="Belum ada data payroll" />
        ) : (
          <div className="space-y-2">
            {months.reverse().map((m, i) => {
              const mNet = Number(m.net_salary || m.gaji_bersih || 0) || (Number(m.basic_salary || m.gaji_pokok || 0) + Number(m.allowances || m.tunjangan || 0) - Number(m.deductions || m.potongan || 0));
              return (
                <div key={i} className="flex items-center justify-between p-2 bg-slate-900/40 rounded-xl border border-white/5">
                  <span className="text-xs text-slate-400">{m.periode || m.period || '-'}</span>
                  <span className="text-xs font-bold text-teal-400">Rp {fmt(mNet)}</span>
                </div>
              );
            })}
          </div>
        )}
      </GlassCard>
    </PageLayout>
  );
}
