// ============================================================
// MultiStepRequest.jsx — #28 Multi-step Wizard Form
// Submit cuti/lembur/sakit/izin/perjalanan dengan wizard steps
// ============================================================

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, getSession } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, Button, Badge, LoadingSpinner } from '../../../lib/design-system';

const REQUEST_TYPES = [
  { id: 'Cuti', icon: '✈️', label: 'Cuti', color: 'blue', fields: ['start_date', 'end_date', 'reason'] },
  { id: 'Izin', icon: '📌', label: 'Izin', color: 'teal', fields: ['date', 'reason'] },
  { id: 'Sakit', icon: '🏥', label: 'Sakit', color: 'red', fields: ['start_date', 'end_date', 'reason', 'medical_note'] },
  { id: 'Lembur', icon: '⏰', label: 'Lembur', color: 'orange', fields: ['date', 'hours', 'reason'] },
  { id: 'Training', icon: '🎓', label: 'Training', color: 'purple', fields: ['training_name', 'start_date', 'end_date', 'reason'] },
  { id: 'Dinas', icon: '🚗', label: 'Perjalanan Dinas', color: 'green', fields: ['destination', 'start_date', 'end_date', 'purpose'] },
];

export default function MultiStepRequest() {
  const navigate = useNavigate();
  const nrp = getSession()?.nrp;
  const [step, setStep] = useState(0); // 0=type, 1=form, 2=review, 3=submitting, 4=done
  const [selectedType, setSelectedType] = useState(null);
  const [formData, setFormData] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState(null);

  const currentType = REQUEST_TYPES.find(t => t.id === selectedType);

  const handleSelectType = (type) => {
    setSelectedType(type.id);
    setFormData({});
    setStep(1);
  };

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async () => {
    setStep(3);
    setSubmitting(true);
    try {
      const { data, error } = await supabase.rpc('submit_request', {
        p_nrp: nrp,
        p_type: selectedType,
        p_details: JSON.stringify(formData),
      });
      if (error) throw error;
      setResult(data);
      setStep(4);
    } catch (err) {
      setResult({ ok: false, msg: err.message });
      setStep(4);
    }
    setSubmitting(false);
  };

  // ── Step 0: Select Type ──
  if (step === 0) {
    return (
      <PageLayout backTo="/worker" title="Pengajuan Baru" subtitle="Pilih jenis pengajuan">
        <div className="grid grid-cols-2 gap-3">
          {REQUEST_TYPES.map(type => (
            <button
              key={type.id}
              onClick={() => handleSelectType(type)}
              className={`p-4 rounded-2xl bg-slate-800/50 border border-white/5 hover:border-${type.color}-500/30 transition-all text-center`}
            >
              <span className="text-3xl block mb-2">{type.icon}</span>
              <span className="text-sm font-semibold text-white">{type.label}</span>
            </button>
          ))}
        </div>
      </PageLayout>
    );
  }

  // ── Step 1: Form ──
  if (step === 1) {
    return (
      <PageLayout backTo="/worker" title={`Pengajuan ${currentType?.label}`} subtitle="Isi detail pengajuan">
        <GlassCard accent={currentType?.color}>
          <div className="space-y-4">
            {currentType?.fields.map(field => (
              <div key={field}>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  {field.replace(/_/g, ' ')}
                </label>
                {field.includes('reason') || field.includes('purpose') || field.includes('medical_note') ? (
                  <textarea
                    value={formData[field] || ''}
                    onChange={e => handleChange(field, e.target.value)}
                    className="w-full bg-slate-800/50 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:border-sky-500/50 focus:outline-none resize-none"
                    rows={3}
                    placeholder={`Masukkan ${field.replace(/_/g, ' ')}...`}
                  />
                ) : field.includes('hours') ? (
                  <input
                    type="number"
                    min="1"
                    max="12"
                    value={formData[field] || ''}
                    onChange={e => handleChange(field, e.target.value)}
                    className="w-full bg-slate-800/50 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:border-sky-500/50 focus:outline-none"
                    placeholder="Jumlah jam"
                  />
                ) : (
                  <input
                    type="date"
                    value={formData[field] || ''}
                    onChange={e => handleChange(field, e.target.value)}
                    className="w-full bg-slate-800/50 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:border-sky-500/50 focus:outline-none"
                  />
                )}
              </div>
            ))}

            <div className="flex gap-2 pt-2">
              <Button color="ghost" size="sm" onClick={() => setStep(0)}>← Kembali</Button>
              <Button color={currentType?.color} size="sm" className="flex-1" onClick={() => setStep(2)}>
                Lanjut → Review
              </Button>
            </div>
          </div>
        </GlassCard>
      </PageLayout>
    );
  }

  // ── Step 2: Review ──
  if (step === 2) {
    return (
      <PageLayout backTo="/worker" title="Review Pengajuan" subtitle="Pastikan data sudah benar">
        <GlassCard accent="blue">
          <div className="space-y-3 mb-4">
            <div className="flex items-center gap-2">
              <span className="text-2xl">{currentType?.icon}</span>
              <div>
                <h3 className="text-sm font-bold text-white">{currentType?.label}</h3>
                <p className="text-xs text-slate-400">Oleh: {nrp}</p>
              </div>
            </div>
            <div className="border-t border-white/5 pt-3 space-y-2">
              {Object.entries(formData).map(([key, value]) => (
                <div key={key} className="flex justify-between items-center">
                  <span className="text-xs text-slate-400">{key.replace(/_/g, ' ')}</span>
                  <span className="text-xs font-semibold text-white">{value}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="p-3 bg-sky-500/10 border border-sky-500/20 rounded-xl mb-4">
            <p className="text-xs text-sky-400">📋 Pengajuan akan dikirim ke atasan langsung untuk approval.</p>
          </div>

          <div className="flex gap-2">
            <Button color="ghost" size="sm" onClick={() => setStep(1)}>← Edit</Button>
            <Button color="green" size="sm" className="flex-1" onClick={handleSubmit} disabled={submitting}>
              {submitting ? 'Mengirim...' : '✅ Kirim Pengajuan'}
            </Button>
          </div>
        </GlassCard>
      </PageLayout>
    );
  }

  // ── Step 3: Submitting ──
  if (step === 3) {
    return (
      <PageLayout backTo="/worker" title="Mengirim...">
        <LoadingSpinner text="Mengirim pengajuan..." />
      </PageLayout>
    );
  }

  // ── Step 4: Done ──
  return (
    <PageLayout backTo="/worker" title={result?.ok ? '✅ Berhasil' : '❌ Gagal'}>
      <GlassCard accent={result?.ok ? 'green' : 'red'}>
        <div className="text-center py-4">
          <span className="text-4xl block mb-3">{result?.ok ? '✅' : '❌'}</span>
          <p className="text-sm text-white mb-4">{result?.msg}</p>
          {result?.ok && result?.approver && (
            <p className="text-xs text-slate-400">Menunggu approval dari: <b className="text-white">{result.approver}</b></p>
          )}
          <Button color="blue" size="sm" onClick={() => { setStep(0); setSelectedType(null); setFormData({}); setResult(null); }}>
            Buat Pengajuan Baru
          </Button>
        </div>
      </GlassCard>
    </PageLayout>
  );
}
