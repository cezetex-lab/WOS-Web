// ============================================================
// Integrations.jsx — #92-97 Integrations & Ecosystem
// Webhooks, SSO, Slack/Teams notifications
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getSession } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, Input, Toggle, StatItem, Divider
} from '../../lib/design-system';

function Modal({ onClose, title, children }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4" onClick={onClose}>
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md max-h-[80vh] overflow-y-auto p-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-white font-semibold text-sm">{title}</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-white text-lg">✕</button>
        </div>
        {children}
      </div>
    </div>
  );
}

const EVENT_OPTIONS = [
  { key: 'leave_approved', label: '✈️ Cuti Disetujui' },
  { key: 'leave_rejected', label: '❌ Cuti Ditolak' },
  { key: 'kpi_alert', label: '📊 KPI Alert' },
  { key: 'turnover_warning', label: '⚠️ Turnover Warning' },
  { key: 'pkwt_expiry', label: '📅 PKWT Expiry' },
  { key: 'new_registration', label: '📝 Pendaftaran Baru' },
  { key: 'task_completed', label: '✅ Task Selesai' },
  { key: 'safety_incident', label: '🦺 Insiden Safety' },
];

const CHANNEL_ICONS = {
  slack: '💬', teams: '👥', whatsapp: '📱', email: '📧'
};

export default function Integrations() {
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('webhooks');
  const [webhooks, setWebhooks] = useState([]);
  const [webhookLogs, setWebhookLogs] = useState([]);
  const [ssoProviders, setSsoProviders] = useState([]);
  const [extNotifs, setExtNotifs] = useState([]);
  const [showAddWebhook, setShowAddWebhook] = useState(false);
  const [newWhName, setNewWhName] = useState('');
  const [newWhUrl, setNewWhUrl] = useState('');
  const [newWhEvents, setNewWhEvents] = useState([]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [wh, whl, sso, en] = await Promise.all([
        supabase.rpc('admin_get_webhooks'),
        supabase.rpc('admin_get_webhook_logs'),
        supabase.rpc('admin_get_sso_providers'),
        supabase.rpc('admin_get_external_notifications'),
      ]);
      if (wh?.data?.ok) setWebhooks(wh.data.data || []);
      if (whl?.data?.ok) setWebhookLogs(whl.data.data || []);
      if (sso?.data?.ok) setSsoProviders(sso.data.data || []);
      if (en?.data?.ok) setExtNotifs(en.data.data || []);
    } catch (e) { console.warn('Integrations fetch error:', e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const createWebhook = async () => {
    if (!newWhName.trim() || !newWhUrl.trim()) return;
    try {
      await supabase.rpc('admin_create_webhook', { p_name: newWhName, p_url: newWhUrl, p_events: newWhEvents });
      setShowAddWebhook(false);
      setNewWhName('');
      setNewWhUrl('');
      setNewWhEvents([]);
      fetchData();
    } catch (e) { console.warn('Create webhook error:', e); }
  };

  const toggleWebhook = async (id, active) => {
    try {
      await supabase.rpc('admin_toggle_webhook', { p_id: id, p_active: !active });
      fetchData();
    } catch (e) { console.warn('Toggle webhook error:', e); }
  };

  const deleteWebhook = async (id) => {
    if (!confirm('Hapus webhook ini?')) return;
    try {
      await supabase.rpc('admin_delete_webhook', { p_id: id });
      fetchData();
    } catch (e) { console.warn('Delete webhook error:', e); }
  };

  const toggleEvent = (key) => {
    setNewWhEvents(prev => prev.includes(key) ? prev.filter(e => e !== key) : [...prev, key]);
  };

  const tabs = [
    { key: 'webhooks', label: '🔗 Webhooks' },
    { key: 'sso', label: '🔑 SSO' },
    { key: 'notifications', label: '💬 Slack/Teams' },
    { key: 'logs', label: '📋 Logs' },
  ];

  return (
    <PageLayout title="⚡ Integrasi & Ekosistem">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {/* Stats */}
        <div className="grid grid-cols-3 gap-3">
          <StatItem label="Webhooks" value={webhooks.length} />
          <StatItem label="SSO Providers" value={ssoProviders.filter(s => s.enabled).length} color="green" />
          <StatItem label="Channels" value={extNotifs.filter(e => e.active).length} color="blue" />
        </div>

        {tab === 'webhooks' && (
          <>
            <Button onClick={() => setShowAddWebhook(true)} className="w-full">
              ➕ Tambah Webhook
            </Button>
            {loading ? <LoadingSpinner /> : webhooks.length === 0 ? (
              <EmptyState icon="🔗" title="Belum ada webhook" subtitle="Webhook akan mengirim notifikasi ke URL eksternal" />
            ) : (
              <div className="space-y-2">
                {webhooks.map((wh) => (
                  <GlassCard key={wh.id} className="p-3">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex-1">
                        <p className="text-white text-sm font-medium">{wh.name}</p>
                        <p className="text-slate-400 text-xs truncate">{wh.url}</p>
                      </div>
                      <Badge color={wh.active ? 'green' : 'slate'}>{wh.active ? '🟢 Active' : '⚪ Off'}</Badge>
                    </div>
                    <div className="flex flex-wrap gap-1 mb-2">
                      {(wh.events || []).map((ev, i) => (
                        <Badge key={i} color="blue">{ev}</Badge>
                      ))}
                    </div>
                    <div className="flex gap-2">
                      <Button onClick={() => toggleWebhook(wh.id, wh.active)} variant="secondary" size="sm">
                        {wh.active ? '⏸️ Disable' : '▶️ Enable'}
                      </Button>
                      <Button onClick={() => deleteWebhook(wh.id)} color="red" size="sm">🗑️</Button>
                    </div>
                  </GlassCard>
                ))}
              </div>
            )}
          </>
        )}

        {tab === 'sso' && (
          loading ? <LoadingSpinner /> : ssoProviders.length === 0 ? (
            <EmptyState icon="🔑" title="Belum ada SSO" subtitle="Konfigurasi OAuth2 SSO untuk single sign-on" />
          ) : (
            <div className="space-y-3">
              {ssoProviders.map((sso) => (
                <GlassCard key={sso.id} className="p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-white text-sm font-semibold">{sso.name}</p>
                      <p className="text-slate-400 text-xs">Type: {sso.provider_type}</p>
                    </div>
                    <Badge color={sso.enabled ? 'green' : 'slate'}>
                      {sso.enabled ? '🟢 Enabled' : '⚪ Disabled'}
                    </Badge>
                  </div>
                  {!sso.enabled && (
                    <p className="text-slate-500 text-xs mt-2">
                      ℹ️ Aktifkan setelah mengisi Client ID & Secret di database
                    </p>
                  )}
                </GlassCard>
              ))}
              <GlassCard className="p-3">
                <p className="text-slate-400 text-xs">
                  💡 SSO memerlukan konfigurasi OAuth2 di provider (Google/Azure).
                  Setelah di-setup, karyawan bisa login dengan akun Google/Microsoft mereka.
                </p>
              </GlassCard>
            </div>
          )
        )}

        {tab === 'notifications' && (
          loading ? <LoadingSpinner /> : extNotifs.length === 0 ? (
            <EmptyState icon="💬" title="Belum ada channel" subtitle="Tambah Slack/Teams webhook untuk notifikasi" />
          ) : (
            <div className="space-y-3">
              {extNotifs.map((ch) => (
                <GlassCard key={ch.id} className="p-4">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-xl">{CHANNEL_ICONS[ch.channel] || '📨'}</span>
                      <div>
                        <p className="text-white text-sm font-semibold capitalize">{ch.channel}</p>
                        <p className="text-slate-400 text-xs">{ch.webhook_url ? '✅ Configured' : '⚠️ No URL'}</p>
                      </div>
                    </div>
                    <Badge color={ch.active ? 'green' : 'slate'}>
                      {ch.active ? '🟢 Active' : '⚪ Off'}
                    </Badge>
                  </div>
                  <div className="flex flex-wrap gap-1">
                    {(ch.event_types || []).map((ev, i) => (
                      <Badge key={i} color="blue">{ev}</Badge>
                    ))}
                  </div>
                </GlassCard>
              ))}
              <GlassCard className="p-3">
                <p className="text-slate-400 text-xs">
                  💡 Setup: Buat Incoming Webhook di Slack/Teams, copy URL, lalu update di database.
                </p>
              </GlassCard>
            </div>
          )
        )}

        {tab === 'logs' && (
          loading ? <LoadingSpinner /> : webhookLogs.length === 0 ? (
            <EmptyState icon="📋" title="Belum ada logs" subtitle="Webhook logs akan muncul di sini" />
          ) : (
            <div className="space-y-2">
              {webhookLogs.map((log) => (
                <GlassCard key={log.id} className="p-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-white text-xs font-medium">{log.event}</p>
                      <p className="text-slate-500 text-xs">{new Date(log.created_at).toLocaleString('id-ID')}</p>
                    </div>
                    <Badge color={log.success ? 'green' : 'red'}>
                      {log.success ? '✅' : '❌'} {log.response_status || '-'}
                    </Badge>
                  </div>
                </GlassCard>
              ))}
            </div>
          )
        )}
      </div>

      {/* Add Webhook Modal */}
      {showAddWebhook && (
        <Modal onClose={() => setShowAddWebhook(false)} title="➕ Tambah Webhook">
          <div className="space-y-3">
            <Input label="Nama" value={newWhName} onChange={setNewWhName} placeholder="Contoh: Slack HR Channel" />
            <Input label="URL" value={newWhUrl} onChange={setNewWhUrl} placeholder="https://hooks.slack.com/..." />
            <div>
              <label className="text-xs text-slate-400 mb-1 block">Events</label>
              <div className="space-y-1">
                {EVENT_OPTIONS.map(ev => (
                  <button
                    key={ev.key}
                    onClick={() => toggleEvent(ev.key)}
                    className={`w-full text-left px-3 py-2 rounded-lg text-xs transition-all ${
                      newWhEvents.includes(ev.key) ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30' : 'bg-slate-800/50 text-slate-400'
                    }`}
                  >
                    {newWhEvents.includes(ev.key) ? '✅' : '☐'} {ev.label}
                  </button>
                ))}
              </div>
            </div>
            <Button onClick={createWebhook} className="w-full">💾 Simpan Webhook</Button>
          </div>
        </Modal>
      )}
    </PageLayout>
  );
}
