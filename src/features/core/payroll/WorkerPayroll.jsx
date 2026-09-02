// WorkerPayroll.jsx — Slip gaji bulanan karyawan
import { getSession } from '@/lib/supabase-browser';
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState, Button } from '../../../lib/design-system';

export default function WorkerPayroll() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [selected, setSelected] = useState(null);

    const nrp = getSession()?.nrp || 'NRP001';

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_payroll', { p_nrp: nrp });
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const formatRp = (v) => `Rp ${(parseFloat(v || 0)).toLocaleString('id-ID')}`;
  const totalNet = data.reduce((s, r) => s + parseFloat(r.net_salary || r.take_home || 0), 0);

  if (loading) return <PageLayout backTo="/worker" title="Slip Gaji"><LoadingSpinner text="Memuat slip gaji..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="💰 Slip Gaji" subtitle={`${data.length} periode`}>
      <div className="grid grid-cols-2 gap-3 mb-6">
        <MetricCard icon="💰" value={formatRp(totalNet / Math.max(data.length, 1))} label="Rata-rata Bersih" color="green" />
        <MetricCard icon="📅" value={data.length} label="Total Slip" color="blue" />
      </div>

      {/* Payroll Cards */}
      <div className="space-y-3">
        {data.map((row, i) => (
          <GlassCard key={i} accent="green" className="cursor-pointer hover:border-green-500/30 transition-all" onClick={() => setSelected(selected === i ? null : i)}>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-bold text-white">{row.period || row.periode || `Periode ${i + 1}`}</p>
                <p className="text-xs text-slate-400 mt-1">{row.divisi || '-'}</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-green-400">{formatRp(row.net_salary || row.take_home)}</p>
                <p className="text-[10px] text-slate-400">Bersih</p>
              </div>
            </div>

            {selected === i && (
              <div className="mt-4 pt-4 border-t border-white/10 space-y-2">
                <div className="flex justify-between text-xs">
                  <span className="text-green-400">Gaji Pokok</span>
                  <span className="text-white font-semibold">{formatRp(row.basic_salary || row.base_salary)}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-blue-400">Tunjangan</span>
                  <span className="text-white font-semibold">+{formatRp(row.allowance)}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-orange-400">Lembur</span>
                  <span className="text-white font-semibold">+{formatRp(row.overtime_pay)}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-yellow-400">Bonus</span>
                  <span className="text-white font-semibold">+{formatRp(row.bonus)}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-red-400">Potongan</span>
                  <span className="text-white font-semibold">-{formatRp(row.deduction)}</span>
                </div>
                <div className="border-t border-white/10 pt-2 flex justify-between text-sm">
                  <span className="text-green-400 font-bold">Gaji Bersih</span>
                  <span className="text-green-400 font-bold">{formatRp(row.net_salary || row.take_home)}</span>
                </div>
              </div>
            )}
          </GlassCard>
        ))}
        {data.length === 0 && <EmptyState title="Belum ada slip gaji" subtitle="Slip gaji akan muncul setelah proses payroll" icon="💰" />}
      </div>
    </PageLayout>
  );
}
