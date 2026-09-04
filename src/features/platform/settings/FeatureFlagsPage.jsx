// FeatureFlagsPage.jsx — Toggle fitur aktif/nonaktif
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, Badge, Button, LoadingSpinner, Toggle } from '../../../lib/design-system';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function FeatureFlagsPage() {
  useAdminAuth(["admin_pusat"]);
  const [loading, setLoading] = useState(true);
  const [flags, setFlags] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('admin_get_feature_flags');
      setFlags(Array.isArray(result) ? result : result?.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const toggleFlag = async (flag) => {
    try {
      await rpc('admin_set_feature_flag', { p_flag: flag.flag || flag.key || flag.name, p_enabled: !flag.enabled });
      setFlags(flags.map(f => f.id === flag.id ? { ...f, enabled: !f.enabled } : f));
    } catch (e) { }
  };

  const enabledCount = flags.filter(f => f.enabled).length;

  if (loading) return <PageLayout backTo="/admin" title="Feature Flags"><LoadingSpinner text="Memuat feature flags..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="⚙️ Feature Flags" subtitle={`${flags.length} fitur terdaftar`}>
      <div className="grid grid-cols-2 gap-3 mb-6">
        <MetricCard icon="🟢" value={enabledCount} label="Aktif" color="green" />
        <MetricCard icon="🔴" value={flags.length - enabledCount} label="Nonaktif" color="red" />
      </div>
      <div className="space-y-2">
        {flags.map(flag => (
          <GlassCard key={flag.id} accent={flag.enabled ? 'green' : 'slate'}>
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-white">{flag.flag || flag.key || flag.name}</span>
                  <Badge status={flag.enabled ? 'ON' : 'OFF'} type={flag.enabled ? 'success' : 'danger'} />
                </div>
                {flag.description && <p className="text-xs text-slate-400 mt-1">{flag.description}</p>}
              </div>
              <button
                onClick={() => toggleFlag(flag)}
                className={`relative w-12 h-6 rounded-full transition-colors ${flag.enabled ? 'bg-green-500' : 'bg-slate-600'}`}
              >
                <span className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${flag.enabled ? 'left-6' : 'left-0.5'}`} />
              </button>
            </div>
          </GlassCard>
        ))}
        {flags.length === 0 && (
          <GlassCard accent="slate">
            <p className="text-center text-sm text-slate-400">Tidak ada feature flags</p>
          </GlassCard>
        )}
      </div>
    </PageLayout>
  );
}
