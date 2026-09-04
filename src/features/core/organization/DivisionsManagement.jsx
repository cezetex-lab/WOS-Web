// DivisionsManagement.jsx — Manajemen Divisi & Departemen
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, Button, LoadingSpinner, EmptyState, Avatar } from '../../../lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function DivisionsManagement() {
  useAdminAuth(["admin_pusat"]);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  const [selected, setSelected] = useState(null);
  const [view, setView] = useState('list'); // list | tree

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_divisions');
      setData(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Group by divisi
  const divisions = React.useMemo(() => {
    const map = {};
    data.forEach(row => {
      const div = row.divisi || row.division || 'Unknown';
      if (!map[div]) map[div] = { name: div, departments: new Set(), employees: 0 };
      map[div].employees++;
      if (row.departemen || row.department) map[div].departments.add(row.departemen || row.department);
    });
    return Object.values(map).map(d => ({ ...d, departments: Array.from(d.departements) }));
  }, [data]);

  const columns = [
    { key: 'divisi', label: 'Divisi', render: (v) => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'departemen', label: 'Departemen', render: (v) => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'nama', label: 'Karyawan', render: (v) => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'nrp', label: 'NRP', render: (v) => <span className="text-xs text-slate-400 font-mono">{v}</span> },
    { key: 'jabatan', label: 'Jabatan', render: (v) => <span className="text-xs text-slate-300">{v || '-'}</span> },
  ];

  const statCards = [
    { icon: '📂', value: divisions.length, label: 'Total Divisi', color: 'blue' },
    { icon: '👥', value: data.length, label: 'Total Karyawan', color: 'green' },
    { icon: '🏛️', value: divisions.reduce((s, d) => s + d.departments.length, 0), label: 'Departemen', color: 'teal' },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Divisi" subtitle="Manajemen divisi & departemen"><LoadingSpinner text="Memuat data divisi..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="📂 Divisi" subtitle={`${divisions.length} divisi, ${data.length} karyawan`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>

      {/* Division Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-6">
        {divisions.map((div, i) => (
          <GlassCard key={i} accent="blue" className="cursor-pointer hover:border-blue-500/30 transition-all" onClick={() => setSelected(selected === div.name ? null : div.name)}>
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-bold text-white">📂 {div.name}</h3>
                <p className="text-xs text-slate-400 mt-1">{div.employees} karyawan • {div.departments.length} departemen</p>
              </div>
              <span className="text-2xl font-bold text-blue-400">{div.employees}</span>
            </div>
            {selected === div.name && div.departments.length > 0 && (
              <div className="mt-3 pt-3 border-t border-white/10">
                <p className="text-xs text-slate-400 mb-2">Departemen:</p>
                <div className="flex flex-wrap gap-1">
                  {div.departments.map((dep, j) => (
                    <Badge key={j} status={dep} type="info" />
                  ))}
                </div>
              </div>
            )}
          </GlassCard>
        ))}
      </div>

      <GlassCard accent="blue">
        <h3 className="text-sm font-bold text-white mb-3">📋 Detail Karyawan per Divisi</h3>
        <DataTable columns={columns} data={selected ? data.filter(d => (d.divisi || d.division) === selected) : data} searchPlaceholder="Cari divisi/karyawan..." onRowClick={(row) => setSelected(row.divisi || row.division)} emptyMessage="Tidak ada data divisi" />
      </GlassCard>
    </PageLayout>
  );
}
