// ============================================================
// TrainingForm.jsx — #24 Pengajuan Training + #26 Batal Training
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input, Badge, DataTable,
  LoadingSpinner, EmptyState, Tabs, useToast
} from '../../../lib/design-system';

export default function TrainingForm() {
  const toast = useToast();
  const nrp = getSession()?.nrp || 'NRP001';
  const [loading, setLoading] = useState(true);
  const [trainings, setTrainings] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [activeTab, setActiveTab] = useState('catalog');
  const [submitting, setSubmitting] = useState(false);

  // Form
  const [trainingName, setTrainingName] = useState('');
  const [trainingDate, setTrainingDate] = useState('');
  const [trainingReason, setTrainingReason] = useState('');
  const [trainingBudget, setTrainingBudget] = useState('');

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await rpc('get_worker_learning', { p_nrp: nrp });
      setTrainings(result?.data || result || []);
    } catch (err) {
      setTrainings([]);
    }
    setLoading(false);
  }, [nrp]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // ── ENROLL ──
  const handleEnroll = async () => {
    if (!trainingName || !trainingReason) {
      toast.warning('Isi nama training dan alasan');
      return;
    }
    setSubmitting(true);
    try {
      await rpc('create_worker_request', {
        p_nrp: nrp,
        p_type: 'Training',
        p_detail: `${trainingName} | ${trainingDate || 'TBD'} | Budget: ${trainingBudget || '-'}`,
        p_note: trainingReason,
      });
      toast.success('Pengajuan training diajukan! Menunggu approval 2 level.');
      setShowForm(false);
      setTrainingName('');
      setTrainingDate('');
      setTrainingReason('');
      setTrainingBudget('');
      fetchData();
    } catch (err) {
      toast.error('Gagal mengajukan training');
    }
    setSubmitting(false);
  };

  // ── CANCEL (#26) ──
  const handleCancel = async (item) => {
    if (!confirm(`Batalkan training "${item.name || item.nama || item.title}"?`)) return;
    try {
      await rpc('create_worker_request', {
        p_nrp: nrp,
        p_type: 'Batal Training',
        p_detail: item.id || item.name || item.nama,
        p_note: 'Pembatalan oleh peserta',
      });
      toast.success('Pembatalan training diajukan');
      fetchData();
    } catch (err) {
      toast.error('Gagal membatalkan');
    }
  };

  const enrolled = (Array.isArray(trainings) ? trainings : []).filter(t => (t.status || '').toLowerCase() === 'enrolled' || (t.status || '').toLowerCase() === 'approved');
  const catalog = (Array.isArray(trainings) ? trainings : []).filter(t => (t.status || '').toLowerCase() !== 'enrolled' && (t.status || '').toLowerCase() !== 'approved');

  if (loading) return <PageLayout backTo="/worker" title="Training"><LoadingSpinner text="Memuat data training..." /></PageLayout>;

  return (
    <PageLayout backTo="/worker" title="Pengajuan Training" subtitle="Daftar & kelola pelatihan">
      {/* ── ACTION ── */}
      <Button color="teal" onClick={() => setShowForm(!showForm)} className="mb-4 w-full">
        {showForm ? '✕ Tutup' : '+ Ajukan Training'}
      </Button>

      {/* ── FORM ── */}
      {showForm && (
        <GlassCard title="Form Pengajuan Training" icon="📝" accent="teal" className="mb-4">
          <div className="space-y-3">
            <Input label="Nama Training" placeholder="Contoh: React Advanced Course" value={trainingName} onChange={(e) => setTrainingName(e.target.value)} icon="📚" />
            <Input label="Tanggal" type="date" value={trainingDate} onChange={(e) => setTrainingDate(e.target.value)} icon="📅" />
            <Input label="Estimasi Budget (Rp)" type="number" placeholder="5000000" value={trainingBudget} onChange={(e) => setTrainingBudget(e.target.value)} icon="💰" />
            <Input label="Alasan / Justifikasi" placeholder="Mengapa training ini penting?" value={trainingReason} onChange={(e) => setTrainingReason(e.target.value)} icon="📝" />

            <div className="p-2 bg-blue-500/10 border border-blue-500/20 rounded-xl">
              <p className="text-[11px] text-blue-400 font-bold">ℹ️ Approval 2 Level</p>
              <p className="text-[11px] text-slate-400">Pengajuan akan disetujui oleh atasan langsung, kemudian HR.</p>
            </div>

            <Button color="teal" onClick={handleEnroll} disabled={submitting} className="w-full">
              {submitting ? 'Mengirim...' : '📤 Ajukan Training'}
            </Button>
          </div>
        </GlassCard>
      )}

      {/* ── TABS ── */}
      <Tabs
        tabs={[
          { id: 'catalog', label: 'Katalog', count: catalog.length },
          { id: 'enrolled', label: 'Terdaftar', count: enrolled.length },
        ]}
        active={activeTab}
        onChange={setActiveTab}
        className="mb-4"
      />

      {/* ── LIST ── */}
      <div className="space-y-2">
        {(activeTab === 'enrolled' ? enrolled : catalog).length === 0 ? (
          <EmptyState icon="📚" title={activeTab === 'enrolled' ? 'Belum terdaftar di training' : 'Tidak ada training tersedia'} />
        ) : (
          (activeTab === 'enrolled' ? enrolled : catalog).map((t, i) => (
            <GlassCard key={i} accent="blue">
              <div className="flex items-start justify-between">
                <div className="min-w-0 flex-1">
                  <h4 className="text-sm font-bold text-white">{t.name || t.nama || t.title || '-'}</h4>
                  <p className="text-xs text-slate-400 mt-0.5">{t.date || t.tanggal || t.periode || '-'}</p>
                  <div className="flex gap-2 mt-1">
                    <Badge status={t.status || 'Available'} type={t.status === 'Approved' ? 'success' : t.status === 'Pending' ? 'warning' : 'info'} />
                    {t.budget && <Badge status={`Rp ${Number(t.budget).toLocaleString('id-ID')}`} type="info" />}
                  </div>
                </div>
                {activeTab === 'enrolled' && (
                  <Button color="red" size="sm" variant="outline" onClick={() => handleCancel(t)}>
                    ✕ Batal
                  </Button>
                )}
              </div>
            </GlassCard>
          ))
        )}
      </div>
    </PageLayout>
  );
}
