// ============================================================
// Payroll.jsx — Halaman Payroll / Gaji Karyawan
// RPC: admin_get_payroll, admin_get_payroll_summary
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, rpc } from '../../../lib/supabase-browser';
import useAdminAuth from '@/hooks/useAdminAuth';
import {
  PageLayout, MetricCard, GlassCard, DataTable, Badge,
  Tabs, LoadingSpinner, EmptyState, Button, Avatar, StatItem
} from '../../../lib/design-system';

// ──────────────────────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────────────────────
function formatRupiah(n) {
  useAdminAuth(["admin_pusat", "admin_finance"]);
  if (n == null || isNaN(n)) return '-';
  return 'Rp ' + Number(n).toLocaleString('id-ID');
}

function getCurrentPeriod() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

function getPeriodLabel(period) {
  if (!period) return '-';
  const [y, m] = period.split('-');
  const months = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
  return `${months[parseInt(m) - 1] || m} ${y}`;
}

// Generate last 6 months for period filter
function getRecentPeriods(count = 6) {
  const periods = [];
  const now = new Date();
  for (let i = 0; i < count; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const label = `${['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'][d.getMonth()]} ${d.getFullYear()}`;
    periods.push({ id: key, label });
  }
  return periods;
}

// ──────────────────────────────────────────────────────────────
// MAIN COMPONENT
// ──────────────────────────────────────────────────────────────
export default function Payroll() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [payroll, setPayroll] = useState([]);
  const [summary, setSummary] = useState({});
  const [period, setPeriod] = useState(getCurrentPeriod());
  const [activeTab, setActiveTab] = useState('all');
  const [selected, setSelected] = useState(null);

  const periods = getRecentPeriods();

  // ── FETCH DATA ──
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [payrollResult, summaryResult] = await Promise.all([
        rpc('admin_get_payroll', { p_period: period }),
        rpc('admin_get_payroll_summary', { p_period: period }),
      ]);

      // Payroll data
      if (payrollResult?.ok !== false && Array.isArray(payrollResult)) {
        setPayroll(payrollResult);
      } else if (payrollResult?.data && Array.isArray(payrollResult.data)) {
        setPayroll(payrollResult.data);
      } else {
        setPayroll([]);
      }

      // Summary
      if (summaryResult && typeof summaryResult === 'object') {
        setSummary(summaryResult);
      }
    } catch (err) { }
    setLoading(false);
  }, [period]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── COMPUTED STATS ──
  const totalGross = payroll.reduce((s, p) => s + (p.gross_salary || p.total_gaji || 0), 0);
  const totalPotongan = payroll.reduce((s, p) => s + (p.total_potongan || p.deductions || 0), 0);
  const totalNett = payroll.reduce((s, p) => s + (p.nett_salary || p.gaji_bersih || 0), 0);

  // ── FILTER ──
  const filtered = payroll.filter(row => {
    if (activeTab === 'pkwt')  return (row.jenis || '').toUpperCase() === 'PKWT';
    if (activeTab === 'pkwtt') return (row.jenis || '').toUpperCase() === 'PKWTT';
    if (activeTab === 'processed') return row.status === 'Processed' || row.status === 'Paid';
    if (activeTab === 'pending') return row.status === 'Pending' || row.status === 'Draft';
    return true;
  });

  // ── STAT CARDS ──
  const statCards = [
    {
      icon: '💰',
      value: formatRupiah(summary.total_net || totalNett),
      label: 'Total Gaji Bersih',
      trend: getPeriodLabel(period),
      color: 'green',
    },
    {
      icon: '👥',
      value: summary.total_employees || payroll.length || 0,
      label: 'Karyawan',
      trend: 'Diproses',
      color: 'blue',
    },
    {
      icon: '📈',
      value: formatRupiah(summary.avg_salary || (payroll.length > 0 ? totalNett / payroll.length : 0)),
      label: 'Rata-rata Gaji',
      trend: 'Per Orang',
      color: 'teal',
    },
    {
      icon: '📋',
      value: formatRupiah(totalPotongan),
      label: 'Total Potongan',
      trend: `${summary.total_deduction_items || '-'} Item`,
      color: 'orange',
    },
  ];

  // ── TABLE COLUMNS ──
  const columns = [
    {
      key: 'nama',
      label: 'Nama',
      render: (val, row) => (
        <div className="flex items-center gap-2">
          <Avatar name={val} size="sm" />
          <div className="min-w-0">
            <div className="text-xs font-semibold text-white truncate">{val}</div>
            <div className="text-[11px] text-slate-500">{row.nrp || '-'}</div>
          </div>
        </div>
      ),
    },
    {
      key: 'divisi',
      label: 'Divisi',
      render: (val) => (
        <span className="text-xs text-slate-300">{val || '-'}</span>
      ),
    },
    {
      key: 'gross_salary',
      label: 'Gross',
      render: (val, row) => {
        const v = val || row.total_gaji || 0;
        return <span className="text-xs font-semibold text-white">{formatRupiah(v)}</span>;
      },
    },
    {
      key: 'total_potongan',
      label: 'Potongan',
      render: (val, row) => {
        const v = val || row.deductions || 0;
        return <span className="text-xs text-red-400">-{formatRupiah(v)}</span>;
      },
    },
    {
      key: 'nett_salary',
      label: 'Bersih',
      render: (val, row) => {
        const v = val || row.gaji_bersih || 0;
        return <span className="text-xs font-bold text-emerald-400">{formatRupiah(v)}</span>;
      },
    },
    {
      key: 'status',
      label: 'Status',
      render: (val) => {
        const v = (val || '').toLowerCase();
        const t = v === 'paid' || v === 'processed' ? 'success' : v === 'pending' || v === 'draft' ? 'warning' : 'default';
        return <Badge status={val || 'Draft'} type={t} />;
      },
    },
  ];

  // ── LOADING ──
  if (loading) {
    return (
      <PageLayout backTo="/admin" title="Payroll" subtitle="Manajemen gaji karyawan">
        <LoadingSpinner text="Memuat data payroll..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/admin" title="Payroll" subtitle={getPeriodLabel(period)}>
      {/* ── PERIOD SELECTOR ── */}
      <div className="flex gap-2 overflow-x-auto pb-2 mb-4 -mx-4 px-4 scrollbar-hide">
        {periods.map(p => (
          <button
            key={p.id}
            onClick={() => setPeriod(p.id)}
            className={`
              flex-shrink-0 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all
              ${period === p.id
                ? 'bg-teal-500/20 text-teal-400 border border-teal-500/30'
                : 'bg-slate-800/50 text-slate-400 border border-white/5 hover:bg-slate-700/50 hover:text-white'
              }
            `}
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* ── METRICS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => (
          <MetricCard key={i} {...s} />
        ))}
      </div>

      {/* ── BREAKDOWN ── */}
      <GlassCard title="Rincian" icon="📊" accent="teal" className="mb-4">
        <div className="grid grid-cols-2 gap-3">
          <StatItem
            label="Gross Salary"
            value={formatRupiah(totalGross)}
            color="#38bdf8"
          />
          <StatItem
            label="Total Potongan"
            value={formatRupiah(totalPotongan)}
            color="#f87171"
          />
          <StatItem
            label="Nett Salary"
            value={formatRupiah(totalNett)}
            color="#34d399"
          />
          <StatItem
            label="Avg per Karyawan"
            value={payroll.length > 0 ? formatRupiah(totalNett / payroll.length) : '-'}
            color="#818cf8"
          />
        </div>
      </GlassCard>

      {/* ── FILTER TABS ── */}
      <div className="mb-4">
        <Tabs
          tabs={[
            { id: 'all',       label: 'Semua',       count: payroll.length },
            { id: 'processed', label: 'Diproses',    count: payroll.filter(p => (p.status || '').toLowerCase() === 'processed' || (p.status || '').toLowerCase() === 'paid').length },
            { id: 'pending',   label: 'Pending',     count: payroll.filter(p => (p.status || '').toLowerCase() === 'pending' || (p.status || '').toLowerCase() === 'draft').length },
            { id: 'pkwt',      label: 'PKWT',        count: payroll.filter(p => (p.jenis || '').toUpperCase() === 'PKWT').length },
            { id: 'pkwtt',     label: 'PKWTT',       count: payroll.filter(p => (p.jenis || '').toUpperCase() === 'PKWTT').length },
          ]}
          active={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* ── DATA TABLE ── */}
      <GlassCard accent="green">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-bold text-white/90 tracking-wide">📋 Detail Payroll</h3>
          <Button
            color="teal"
            size="sm"
            variant="outline"
            onClick={() => {
              // Export to CSV
              if (filtered.length === 0) return;
              const headers = ['NRP','Nama','Divisi','Gross','Potongan','Bersih','Status'];
              const rows = filtered.map(r => [
                r.nrp || '', r.nama || '', r.divisi || '',
                r.gross_salary || r.total_gaji || 0,
                r.total_potongan || r.deductions || 0,
                r.nett_salary || r.gaji_bersih || 0,
                r.status || 'Draft'
              ]);
              const csv = [headers, ...rows].map(r => r.join(',')).join('\n');
              const blob = new Blob([csv], { type: 'text/csv' });
              const url = URL.createObjectURL(blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = `payroll-${period}.csv`;
              a.click();
              URL.revokeObjectURL(url);
            }}
          >
            📤 Export CSV
          </Button>
        </div>

        <DataTable
          columns={columns}
          data={filtered}
          searchPlaceholder="Cari nama, NRP, divisi..."
          onRowClick={(row) => setSelected(row)}
          emptyMessage={`Tidak ada data payroll untuk ${getPeriodLabel(period)}`}
        />
      </GlassCard>

      {/* ── PAYROLL DETAIL MODAL ── */}
      {selected && (
        <PayrollDetail
          data={selected}
          onClose={() => setSelected(null)}
          onNavigate={(path) => {
            setSelected(null);
            navigate(path);
          }}
        />
      )}
    </PageLayout>
  );
}

// ──────────────────────────────────────────────────────────────
// PAYROLL DETAIL MODAL
// ──────────────────────────────────────────────────────────────
function PayrollDetail({ data, onClose, onNavigate }) {
  const d = data;

  const gross = d.gross_salary || d.total_gaji || 0;
  const potongan = d.total_potongan || d.deductions || 0;
  const nett = d.nett_salary || d.gaji_bersih || 0;

  const potonganItems = [
    { label: 'BPJS Kesehatan', value: d.bpjs_kes || d.bpjs_health || 0 },
    { label: 'BPJS Ketenagakerjaan', value: d.bpjs_tk || d.bpjs_employment || 0 },
    { label: 'PPH 21', value: d.pph21 || d.tax || 0 },
    { label: 'Pinjaman', value: d.pinjaman || d.loan || 0 },
    { label: 'Lainnya', value: d.other_deductions || d.potongan_lain || 0 },
  ].filter(p => p.value > 0);

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm animate-fade-in" onClick={onClose} />
      <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto animate-slide-up">
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 rounded-full bg-slate-600" />
        </div>

        <div className="px-5 pb-8">
          {/* Header */}
          <div className="flex items-center gap-4 mb-5">
            <Avatar name={d.nama} size="lg" />
            <div className="flex-1 min-w-0">
              <h2 className="text-lg font-bold text-white truncate">{d.nama || '-'}</h2>
              <p className="text-xs text-slate-400">{d.nrp || '-'} • {d.divisi || '-'}</p>
              <div className="mt-1">
                <Badge
                  status={d.status || 'Draft'}
                  type={(d.status || '').toLowerCase() === 'paid' ? 'success' : 'warning'}
                />
              </div>
            </div>
          </div>

          {/* Salary Breakdown */}
          <GlassCard title="Rincian Gaji" icon="💰" accent="green" className="mb-4">
            <div className="space-y-2">
              <div className="flex justify-between items-center py-1.5 border-b border-white/5">
                <span className="text-xs text-slate-400">Gross Salary</span>
                <span className="text-sm font-bold text-white">{formatRupiah(gross)}</span>
              </div>

              {potonganItems.length > 0 && (
                <div className="pl-3 border-l-2 border-red-500/30 space-y-1.5 my-2">
                  <span className="text-[11px] font-bold text-red-400 uppercase tracking-wider">Potongan</span>
                  {potonganItems.map((p, i) => (
                    <div key={i} className="flex justify-between items-center">
                      <span className="text-xs text-slate-400">{p.label}</span>
                      <span className="text-xs text-red-400">-{formatRupiah(p.value)}</span>
                    </div>
                  ))}
                </div>
              )}

              <div className="flex justify-between items-center py-2 border-t border-white/10">
                <span className="text-xs font-bold text-white">Total Potongan</span>
                <span className="text-sm font-bold text-red-400">-{formatRupiah(potongan)}</span>
              </div>

              <div className="flex justify-between items-center py-2 bg-emerald-500/10 -mx-5 px-5 rounded-xl">
                <span className="text-sm font-bold text-white">Gaji Bersih</span>
                <span className="text-lg font-bold text-emerald-400">{formatRupiah(nett)}</span>
              </div>
            </div>
          </GlassCard>

          {/* Info Grid */}
          <GlassCard title="Info Tambahan" icon="📋" accent="blue" className="mb-4">
            <div className="space-y-1">
              {[
                { label: 'Jenis Kontrak', value: d.jenis || d.contract_type || '-' },
                { label: 'Rekening Bank', value: d.bank_account || d.no_rek || '-' },
                { label: 'Bank', value: d.bank_name || d.nama_bank || '-' },
                { label: 'Tanggal Bayar', value: d.payment_date || d.tgl_bayar || '-' },
              ].map((row, i) => (
                <div key={i} className="flex items-center justify-between py-2 border-b border-white/3 last:border-0">
                  <span className="text-xs text-slate-400">{row.label}</span>
                  <span className="text-xs font-semibold text-white">{row.value}</span>
                </div>
              ))}
            </div>
          </GlassCard>

          {/* Actions */}
          <div className="flex gap-2">
            <Button
              color="teal"
              size="sm"
              className="flex-1"
              onClick={() => onNavigate(`/worker/payroll?nrp=${d.nrp}`)}
            >
              💰 Slip Gaji
            </Button>
            <Button
              color="ghost"
              size="sm"
              onClick={onClose}
            >
              ✕
            </Button>
          </div>
        </div>
      </div>
    </>
  );
}
