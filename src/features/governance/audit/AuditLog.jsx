// ============================================================
// AuditLog.jsx — #98 Audit Trail
// View all system activities with search & filter
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, LoadingSpinner, EmptyState, Badge,
  Input, Tabs, DataTable, Button
} from '../../../lib/design-system';

export default function AuditLog() {
  const [loading, setLoading] = useState(true);
  const [logs, setLogs] = useState([]);
  const [activeTab, setActiveTab] = useState('all');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_audit_log');
      const items = result?.data || result || [];
      setLogs(Array.isArray(items) ? items : []);
    } catch (err) {
      console.error('Audit log RPC failed:', err);
      setLogs([]);
    }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Categorize logs
  const categories = React.useMemo(() => {
    const cats = { all: logs };
    logs.forEach(log => {
      const action = (log.action || '').toLowerCase();
      if (action.includes('login') || action.includes('auth')) {
        cats.auth = [...(cats.auth || []), log];
      } else if (action.includes('create') || action.includes('insert')) {
        cats.create = [...(cats.create || []), log];
      } else if (action.includes('update') || action.includes('edit')) {
        cats.update = [...(cats.update || []), log];
      } else if (action.includes('delete') || action.includes('remove')) {
        cats.delete = [...(cats.delete || []), log];
      } else {
        cats.other = [...(cats.other || []), log];
      }
    });
    return cats;
  }, [logs]);

  const columns = [
    {
      key: 'created_at',
      label: 'Waktu',
      render: (val) => (
        <span className="text-[10px] text-slate-400">
          {val ? new Date(val).toLocaleString('id-ID', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '-'}
        </span>
      ),
    },
    {
      key: 'actor',
      label: 'Actor',
      render: (val) => (
        <span className="text-xs font-semibold text-white">{val || '-'}</span>
      ),
    },
    {
      key: 'action',
      label: 'Aksi',
      render: (val) => {
        const v = (val || '').toLowerCase();
        const type = v.includes('login') || v.includes('auth') ? 'info'
          : v.includes('create') || v.includes('insert') ? 'success'
          : v.includes('delete') || v.includes('remove') ? 'danger'
          : v.includes('update') || v.includes('edit') ? 'warning' : 'default';
        return <Badge status={val || '-'} type={type} />;
      },
    },
    {
      key: 'detail',
      label: 'Detail',
      render: (val) => (
        <span className="text-[10px] text-slate-400 truncate block max-w-[180px]">{val || '-'}</span>
      ),
    },
  ];

  const currentLogs = categories[activeTab] || logs;

  return (
    <PageLayout backTo="/admin" title="Audit Log" subtitle={`${logs.length} aktivitas tercatat`}>
      {/* ── STATS ── */}
      <div className="grid grid-cols-4 gap-2 mb-4">
        {[
          { label: 'Login/Auth', count: categories.auth?.length || 0, color: 'text-blue-400' },
          { label: 'Create', count: categories.create?.length || 0, color: 'text-emerald-400' },
          { label: 'Update', count: categories.update?.length || 0, color: 'text-amber-400' },
          { label: 'Delete', count: categories.delete?.length || 0, color: 'text-red-400' },
        ].map((s, i) => (
          <div key={i} className="p-2 bg-slate-800/50 rounded-xl border border-white/5 text-center">
            <div className={`text-lg font-bold ${s.color}`}>{s.count}</div>
            <div className="text-[9px] text-slate-500">{s.label}</div>
          </div>
        ))}
      </div>

      {/* ── TABS ── */}
      <Tabs
        tabs={[
          { id: 'all', label: 'Semua', count: logs.length },
          { id: 'auth', label: 'Auth', count: categories.auth?.length || 0 },
          { id: 'create', label: 'Create', count: categories.create?.length || 0 },
          { id: 'update', label: 'Update', count: categories.update?.length || 0 },
          { id: 'delete', label: 'Delete', count: categories.delete?.length || 0 },
        ]}
        active={activeTab}
        onChange={setActiveTab}
        className="mb-4"
      />

      {/* ── TABLE ── */}
      {loading ? (
        <LoadingSpinner text="Memuat audit log..." />
      ) : currentLogs.length === 0 ? (
        <EmptyState icon="📋" title="Tidak ada log" subtitle="Belum ada aktivitas tercatat" />
      ) : (
        <GlassCard accent="blue">
          <DataTable
            columns={columns}
            data={currentLogs}
            searchPlaceholder="Cari actor, aksi, atau detail..."
            emptyMessage="Tidak ada log ditemukan"
          />
        </GlassCard>
      )}

      {/* ── EXPORT ── */}
      <div className="mt-4 flex gap-2">
        <Button color="teal" size="sm" onClick={() => {
          const csv = ['Waktu,Actor,Aksi,Detail'];
          logs.forEach(l => csv.push(`"${l.created_at}","${l.actor}","${l.action}","${l.detail || ''}"`));
          const blob = new Blob([csv.join('\n')], { type: 'text/csv' });
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a'); a.href = url; a.download = 'audit_log.csv'; a.click();
        }}>
          📤 Export CSV
        </Button>
        <Button color="ghost" size="sm" onClick={fetchData}>🔄 Refresh</Button>
      </div>
    </PageLayout>
  );
}
