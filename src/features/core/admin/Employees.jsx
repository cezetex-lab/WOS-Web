// ============================================================
// Employees.jsx — Halaman Kelola Karyawan
// RPC: admin_get_employees, admin_get_employee_stats
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, MetricCard, GlassCard, DataTable, Badge,
  Tabs, LoadingSpinner, EmptyState, Button, Avatar
} from '../../../lib/design-system';

// ──────────────────────────────────────────────────────────────
// CONFIG
// ──────────────────────────────────────────────────────────────
const TABS = [
  { id: 'all',     label: 'Semua' },
  { id: 'active',  label: 'Aktif' },
  { id: 'pkwt',    label: 'PKWT' },
  { id: 'pkwtt',   label: 'PKWTT' },
  { id: 'inactive',label: 'Non-Aktif' },
];

// ──────────────────────────────────────────────────────────────
// MAIN COMPONENT
// ──────────────────────────────────────────────────────────────
export default function Employees() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [employees, setEmployees] = useState([]);
  const [stats, setStats] = useState({});
  const [activeTab, setActiveTab] = useState('all');
  const [selected, setSelected] = useState(null); // detail modal
  const [searchTerm, setSearchTerm] = useState('');

  // ── FETCH DATA ──
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      // Parallel fetch
      const [empResult, statsResult] = await Promise.all([
        rpc('admin_get_employees'),
        rpc('admin_get_employee_stats'),
      ]);

      // Employees
      if (empResult?.ok !== false && Array.isArray(empResult)) {
        setEmployees(empResult);
      } else if (empResult?.data && Array.isArray(empResult.data)) {
        setEmployees(empResult.data);
      } else {
        setEmployees([]);
      }

      // Stats
      if (statsResult && typeof statsResult === 'object') {
        setStats(statsResult);
      }
    } catch (err) {
      console.error('Failed to load employees:', err);
    }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── FILTER ──
  const filtered = employees.filter(emp => {
    // Tab filter
    if (activeTab === 'active')  return emp.status === 'Aktif' || emp.is_active === true;
    if (activeTab === 'inactive') return emp.status === 'Non-Aktif' || emp.is_active === false;
    if (activeTab === 'pkwt')   return emp.jenis === 'PKWT' || emp.contract_type === 'PKWT';
    if (activeTab === 'pkwtt')  return emp.jenis === 'PKWTT' || emp.contract_type === 'PKWTT';
    return true;
  });

  // ── STAT CARDS ──
  const statCards = [
    {
      icon: '👥',
      value: stats.total || employees.length || 0,
      label: 'Total Karyawan',
      trend: 'Semua',
      color: 'blue',
    },
    {
      icon: '✅',
      value: stats.active || employees.filter(e => e.status === 'Aktif' || e.is_active === true).length,
      label: 'Aktif',
      trend: 'Hari Ini',
      color: 'green',
    },
    {
      icon: '📄',
      value: stats.pkwt || employees.filter(e => e.jenis === 'PKWT' || e.contract_type === 'PKWT').length,
      label: 'PKWT',
      trend: `${stats.expiring_soon || 0} Segera Habis`,
      color: 'orange',
    },
    {
      icon: '📋',
      value: stats.pkwtt || employees.filter(e => e.jenis === 'PKWTT' || e.contract_type === 'PKWTT').length,
      label: 'PKWTT',
      trend: 'Tetap',
      color: 'teal',
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
            <div className="text-[10px] text-slate-500">{row.nrp || '-'}</div>
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
      key: 'jabatan',
      label: 'Jabatan',
      render: (val) => (
        <span className="text-xs text-slate-400 truncate block max-w-[120px]">{val || '-'}</span>
      ),
    },
    {
      key: 'jenis',
      label: 'Kontrak',
      render: (val) => {
        const v = val || '';
        const isPKWT = v.toUpperCase() === 'PKWT';
        return <Badge status={v || '-'} type={isPKWT ? 'warning' : 'info'} />;
      },
    },
    {
      key: 'status',
      label: 'Status',
      render: (val) => {
        const v = val || '';
        const isActive = v === 'Aktif' || v.toLowerCase() === 'active';
        return <Badge status={v || '-'} type={isActive ? 'success' : 'danger'} />;
      },
    },
  ];

  // ── LOADING ──
  if (loading) {
    return (
      <PageLayout backTo="/admin" title="Karyawan" subtitle="Kelola data seluruh karyawan">
        <LoadingSpinner text="Memuat data karyawan..." />
      </PageLayout>
    );
  }

  return (
    <PageLayout backTo="/admin" title="Karyawan" subtitle={`${employees.length} karyawan terdaftar`}>
      {/* ── METRICS ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {statCards.map((s, i) => (
          <MetricCard key={i} {...s} />
        ))}
      </div>

      {/* ── FILTER TABS ── */}
      <div className="mb-4">
        <Tabs
          tabs={TABS.map(t => ({
            ...t,
            count: t.id === 'all' ? employees.length
              : t.id === 'active' ? employees.filter(e => e.status === 'Aktif' || e.is_active === true).length
              : t.id === 'pkwt' ? employees.filter(e => (e.jenis || '').toUpperCase() === 'PKWT').length
              : t.id === 'pkwtt' ? employees.filter(e => (e.jenis || '').toUpperCase() === 'PKWTT').length
              : employees.filter(e => e.status === 'Non-Aktif' || e.is_active === false).length,
          }))}
          active={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* ── DATA TABLE ── */}
      <GlassCard accent="blue">
        <DataTable
          columns={columns}
          data={filtered}
          searchPlaceholder="Cari nama, NRP, divisi..."
          onRowClick={(row) => setSelected(row)}
          emptyMessage="Tidak ada data karyawan"
        />
      </GlassCard>

      {/* ── EMPLOYEE DETAIL MODAL ── */}
      {selected && (
        <EmployeeDetail
          employee={selected}
          onClose={() => setSelected(null)}
          onNavigate={(path) => {
            setSelected(null);
            navigate(path);
          }}
          onDeactivate={fetchData}
        />
      )}
    </PageLayout>
  );
}

// ──────────────────────────────────────────────────────────────
// EMPLOYEE DETAIL MODAL
// ──────────────────────────────────────────────────────────────
function EmployeeDetail({ employee, onClose, onNavigate, onDeactivate }) {
  const emp = employee;
  const [deactivating, setDeactivating] = useState(false);

  const infoRows = [
    { label: 'NRP', value: emp.nrp || '-' },
    { label: 'NIK', value: emp.nik || '-' },
    { label: 'Nama', value: emp.nama || '-' },
    { label: 'Email', value: emp.email || '-' },
    { label: 'No. HP', value: emp.phone || emp.no_hp || '-' },
    { label: 'Divisi', value: emp.divisi || emp.division || '-' },
    { label: 'Jabatan', value: emp.jabatan || emp.position || '-' },
    { label: 'Jenis Kontrak', value: emp.jenis || emp.contract_type || '-' },
    { label: 'Status', value: emp.status || '-' },
    { label: 'Tanggal Masuk', value: emp.tanggal_masuk || emp.join_date || '-' },
    { label: 'Tanggal Habis', value: emp.tanggal_habis || emp.contract_end || '-' },
  ];

  return (
    <>
      {/* Overlay */}
      <div
        className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm animate-fade-in"
        onClick={onClose}
      />
      {/* Modal */}
      <div className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-slate-900 border-t border-white/10 rounded-t-3xl overflow-y-auto animate-slide-up">
        {/* Handle */}
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 rounded-full bg-slate-600" />
        </div>

        <div className="px-5 pb-8">
          {/* Header */}
          <div className="flex items-center gap-4 mb-5">
            <Avatar name={emp.nama} size="lg" />
            <div className="flex-1 min-w-0">
              <h2 className="text-lg font-bold text-white truncate">{emp.nama || '-'}</h2>
              <p className="text-xs text-slate-400">{emp.nrp || '-'} • {emp.jabatan || '-'}</p>
              <div className="mt-1">
                <Badge
                  status={emp.status || '-'}
                  type={emp.status === 'Aktif' ? 'success' : 'danger'}
                />
              </div>
            </div>
          </div>

          {/* Info Grid */}
          <div className="space-y-1 mb-5">
            {infoRows.map((row, i) => (
              <div key={i} className="flex items-center justify-between py-2 border-b border-white/3">
                <span className="text-xs text-slate-400">{row.label}</span>
                <span className="text-xs font-semibold text-white">{row.value}</span>
              </div>
            ))}
          </div>

          {/* Actions */}
          <div className="flex gap-2 flex-wrap">
            <Button
              color="blue"
              size="sm"
              className="flex-1"
              onClick={() => onNavigate(`/worker/kpi?nrp=${emp.nrp}`)}
            >
              📊 Lihat KPI
            </Button>
            <Button
              color="teal"
              size="sm"
              className="flex-1"
              onClick={() => onNavigate(`/worker/profile?nrp=${emp.nrp}`)}
            >
              👤 Profil Lengkap
            </Button>
            <Button
              color="purple"
              size="sm"
              className="flex-1"
              onClick={() => onNavigate(`/admin/reset-password?nrp=${emp.nrp}`)}
            >
              🔑 Reset Password
            </Button>
            <Button
              color="ghost"
              size="sm"
              onClick={onClose}
            >
              ✕
            </Button>
            {(emp.status === 'Aktif' || emp.is_active === true) && (
              <Button
                color="red"
                size="sm"
                className="flex-1"
                disabled={deactivating}
                onClick={async () => {
                  if (!confirm(`Nonaktifkan akses ${emp.nama} (${emp.nrp})?\n\nKaryawan tidak akan bisa login lagi.`)) return;
                  setDeactivating(true);
                  try {
                    const result = await rpc('admin_deactivate_worker', { p_nrp: emp.nrp });
                    if (result?.ok) {
                      alert(`✅ ${result.msg}`);
                      onClose();
                      if (onDeactivate) onDeactivate();
                    } else {
                      alert(`❌ ${result?.msg || 'Gagal menonaktifkan'}`);
                    }
                  } catch (e) {
                    alert('Error: ' + e.message);
                  }
                  setDeactivating(false);
                }}
              >
                {deactivating ? '⏳...' : '🚫 Nonaktifkan'}
              </Button>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
