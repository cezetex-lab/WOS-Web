// RoleMatrixPage.jsx — Mapping Role & Permission
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, LoadingSpinner, EmptyState } from '../../../lib/design-system';

const ROLE_LEVELS = {
  1: { label: 'Worker', color: 'blue', icon: '👷' },
  2: { label: 'Supervisor', color: 'teal', icon: '👨‍💼' },
  3: { label: 'Manager', color: 'green', icon: '🧑‍💼' },
  4: { label: 'Sr. Manager', color: 'orange', icon: '👔' },
  5: { label: 'Admin', color: 'red', icon: '🔑' },
};

export default function RoleMatrixPage() {
  const [loading, setLoading] = useState(true);
  const [roles, setRoles] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_role_matrix');
      setRoles(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Group by role_level
  const grouped = React.useMemo(() => {
    const map = {};
    roles.forEach(r => {
      const level = r.role_level || 1;
      if (!map[level]) map[level] = { ...ROLE_LEVELS[level], level, users: [] };
      map[level].users.push(r);
    });
    return Object.values(map).sort((a, b) => b.level - a.level);
  }, [roles]);

  const statCards = [
    { icon: '🔑', value: roles.length, label: 'Total Users', color: 'blue' },
    { icon: '👥', value: grouped.length, label: 'Role Levels', color: 'teal' },
    { icon: '🛡️', value: roles.filter(r => r.role_level >= 4).length, label: 'Admin+', color: 'red' },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Role Matrix"><LoadingSpinner text="Memuat role matrix..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="🔑 Role Matrix" subtitle={`${roles.length} user terdaftar`}>
      <div className="grid grid-cols-3 gap-3 mb-6">
        {statCards.map((s, i) => <MetricCard key={i} {...s} />)}
      </div>
      <div className="space-y-4">
        {grouped.map((group) => (
          <GlassCard key={group.level} accent={group.color}>
            <div className="flex items-center gap-3 mb-3">
              <span className="text-2xl">{group.icon}</span>
              <div>
                <h3 className="text-sm font-bold text-white">{group.label} (Level {group.level})</h3>
                <p className="text-xs text-slate-400">{group.users.length} user</p>
              </div>
              <Badge status={`${group.users.length} user`} type={group.color} />
            </div>
            <div className="space-y-2">
              {group.users.slice(0, 10).map((u, i) => (
                <div key={i} className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-xs font-bold">
                      {(u.nama || u.nrp || '?')[0]}
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-white">{u.nama || u.nrp}</p>
                      <p className="text-[11px] text-slate-400">{u.nrp} • {u.divisi || '-'}</p>
                    </div>
                  </div>
                  <Badge status={group.label} type={group.color} />
                </div>
              ))}
              {group.users.length > 10 && <p className="text-xs text-slate-400 text-center py-1">+{group.users.length - 10} lainnya</p>}
            </div>
          </GlassCard>
        ))}
        {grouped.length === 0 && <EmptyState title="Tidak ada data role" subtitle="Belum ada user terdaftar" icon="🔑" />}
      </div>
    </PageLayout>
  );
}
