// ============================================================
// WorkerOvertime.jsx — #21 Pengajuan Lembur + Kalkulasi Rate
// Rate: Weekday 1.5x, Saturday 2x, Holiday 3x
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input, Badge, DataTable,
  LoadingSpinner, EmptyState, Tabs, SectionHeader, useToast
} from '../../lib/design-system';

const RATE_MULTIPLIERS = {
  weekday:   { label: 'Hari Kerja',   rate: 1.5, color: 'blue' },
  saturday:  { label: 'Sabtu',        rate: 2.0, color: 'orange' },
  holiday:   { label: 'Hari Libur',   rate: 3.0, color: 'red' },
  night:     { label: 'Malam (22-07)', rate: 2.0, color: 'purple' },
};

function getOvertimeType(dateStr) {
  if (!dateStr) return 'weekday';
  const d = new Date(dateStr);
  const day = d.getDay();
  if (day === 0) return 'holiday';
  if (day === 6) return 'saturday';
  const hour = d.getHours();
  if (hour >= 22 || hour < 7) return 'night';
  return 'weekday';
}

export default function WorkerOvertime() {
  const toast = useToast();
  const nrp = getSession()?.nrp || 'NRP001';
  const [loading, setLoading] = useState(true);
  const [overtime, setOvertime] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [activeTab, setActiveTab] = useState('all');
  const [submitting, setSubmitting] = useState(false);

  // ── FORM ──
  const [formDate, setFormDate] = useState('');
  const [formHours, setFormHours] = useState('');
  const [formReason, setFormReason] = useState('');
  const [formType, setFormType] = useState('weekday');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_overtime', { p_nrp: nrp });
      const items = result?.data || result || [];
      setOvertime(Array.isArray(items) ? items : []);
    } catch (err) {
      console.error('Overtime RPC failed:', err);
      setOvertime([]);
    }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Auto-detect type when date changes
  useEffect(() => {
    if (formDate) setFormType(getOvertimeType(formDate));
  }, [formDate]);

  // ── SUBMIT ──
  const handleSubmit = async () => {
    if (!formDate || !formHours || !formReason) {
      toast.warning('Isi semua field');
      return;
    }
    setSubmitting(true);
    try {
      const rateConfig = RATE_MULTIPLIERS[formType];
      await rpc('create_worker_request', {
        p_nrp: nrp,
        p_type: 'Lembur',
        p_detail: `${formDate} | ${formHours} jam | ${rateConfig.label} (${rateConfig.rate}x) | ${formReason}`,
        p_note: formReason,
      });
      toast.success(`Pengajuan lembur ${rateConfig.label} diajukan!`);
      setShowForm(false);
      setFormDate('');
      setFormHours('');
      setFormReason('');
      fetchData();
    } catch (err) {
      toast.error('Gagal mengajukan lembur');
    }
    setSubmitting(false);
  };

  const filtered = activeTab === 'all' ? overtime
    : overtime.filter(o => (o.status || '').toLowerCase() === activeTab);

  const columns = [
    {
      key: 'created_at',
      label: 'Tanggal',
      render: (val) => (
        <span className="text-xs text-slate-300">
          {val ? new Date(val).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) : '-'}
        </span>
      ),
    },
    {
      key: 'type',
      label: 'Tipe',
      render: (val, row) => {
        const t = (val || '').toLowerCase();
        const typeKey = t.includes('sabtu') ? 'saturday' : t.includes('libur') ? 'holiday' : t.includes('malam') ? 'night' : 'weekday';
        const cfg = RATE_MULTIPLIERS[typeKey];
        return <Badge status={`${cfg.label} (${cfg.rate}x)`} type="info" />;
      },
    },
    {
      key: 'detail',
      label: 'Detail',
      render: (val) => (
        <span className="text-xs text-slate-400 truncate block max-w-[120px]">{val || '-'}</span>
      ),
    },
    {
      key: 'status',
      label: 'Status',
      render: (val) => {
        const t = (val || '').toLowerCase();
        const bt = t === 'approved' || t === 'active' ? 'success' : t === 'pending' ? 'warning' : 'danger';
        return <Badge status={val || 'Pending'} type={bt} />;
      },
    },
  ];

  // Rate card data
  const rates = Object.entries(RATE_MULTIPLIERS);

  return (
    <PageLayout backTo="/worker" title="Pengajuan Lembur" subtitle={`${overtime.length} pengajuan`}>
      {/* ── RATE INFO ── */}
      <GlassCard title="Kalkulasi Tarif Lembur" icon="💰" accent="orange" className="mb-4">
        <div className="grid grid-cols-2 gap-2">
          {rates.map(([key, cfg]) => (
            <div key={key} className={`p-2 rounded-xl bg-${cfg.color === 'blue' ? 'blue' : cfg.color === 'orange' ? 'orange' : cfg.color === 'red' ? 'red' : 'purple'}-500/10 border border-${cfg.color === 'blue' ? 'blue' : cfg.color === 'orange' ? 'orange' : cfg.color === 'red' ? 'red' : 'purple'}-500/20`}>
              <div className="text-xs font-bold text-white">{cfg.label}</div>
              <div className="text-lg font-bold text-teal-400">{cfg.rate}x</div>
            </div>
          ))}
        </div>
        <p className="text-[10px] text-slate-500 mt-2">* Tarif dikalikan upah per jam sesuai UMR</p>
      </GlassCard>

      {/* ── ACTION ── */}
      <Button color="teal" onClick={() => setShowForm(!showForm)} className="mb-4 w-full">
        {showForm ? '✕ Tutup Form' : '+ Ajukan Lembur'}
      </Button>

      {/* ── FORM ── */}
      {showForm && (
        <GlassCard title="Form Pengajuan Lembur" icon="📝" accent="teal" className="mb-4">
          <div className="space-y-3">
            <Input label="Tanggal Lembur" type="date" value={formDate} onChange={(e) => setFormDate(e.target.value)} icon="📅" />
            <Input label="Jam Lembur" type="number" placeholder="Contoh: 3" value={formHours} onChange={(e) => setFormHours(e.target.value)} icon="⏰" />
            <Input label="Alasan" placeholder="Alasan lembur..." value={formReason} onChange={(e) => setFormReason(e.target.value)} icon="📝" />

            {/* Auto-detected type */}
            <div className="p-3 rounded-xl bg-slate-800/50 border border-white/5">
              <p className="text-[10px] text-slate-500 uppercase font-bold mb-1">Tipe Terdeteksi</p>
              <div className="flex items-center gap-2">
                <Badge status={RATE_MULTIPLIERS[formType].label} type="info" />
                <span className="text-lg font-bold text-teal-400">{RATE_MULTIPLIERS[formType].rate}x</span>
              </div>
            </div>

            <Button color="teal" onClick={handleSubmit} disabled={submitting} className="w-full">
              {submitting ? 'Mengirim...' : '📤 Ajukan Lembur'}
            </Button>
          </div>
        </GlassCard>
      )}

      {/* ── TABS ── */}
      <Tabs
        tabs={[
          { id: 'all', label: 'Semua', count: overtime.length },
          { id: 'pending', label: 'Pending', count: overtime.filter(o => (o.status || '').toLowerCase() === 'pending').length },
          { id: 'approved', label: 'Approved', count: overtime.filter(o => (o.status || '').toLowerCase() === 'approved').length },
        ]}
        active={activeTab}
        onChange={setActiveTab}
        className="mb-4"
      />

      {/* ── TABLE ── */}
      {loading ? (
        <LoadingSpinner text="Memuat data lembur..." />
      ) : filtered.length === 0 ? (
        <EmptyState icon="⏰" title="Belum ada pengajuan lembur" subtitle="Klik tombol di atas untuk mengajukan" />
      ) : (
        <GlassCard accent="blue">
          <DataTable columns={columns} data={filtered} searchPlaceholder="Cari lembur..." />
        </GlassCard>
      )}
    </PageLayout>
  );
}
