// FacilityRequest.tsx — Estate Facility Request (Mess, Kerja, Dll)
import { useState, useEffect } from 'react';
import { rpc, isRpcError } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

interface FacilityReq {
  id?: string | number;
  type?: string;
  description?: string;
  status?: string;
  location?: string;
  priority?: string;
  submitted?: string;
  assigned?: string;
  [key: string]: unknown;
}

const PRI_COLOR: Record<string, 'danger' | 'warning' | 'info' | 'default'> = { URGENT: 'danger', HIGH: 'warning', MEDIUM: 'info', LOW: 'default' };
const STATUS_COLOR: Record<string, 'warning' | 'info' | 'success' | 'danger' | 'default'> = { PENDING: 'warning', APPROVED: 'info', IN_PROGRESS: 'info', RESOLVED: 'success' };

export default function FacilityRequest() {
  const [loading, setLoading] = useState(true);
  const [requests, setRequests] = useState<FacilityReq[]>([]);
  const [formType, setFormType] = useState('Mess Repair');
  const [formDesc, setFormDesc] = useState('');
  const [formPriority, setFormPriority] = useState('MEDIUM');
  const [submitting, setSubmitting] = useState(false);
  const toast = useToast();

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    try {
      const r = await rpc<{ data?: FacilityReq[] }>('admin_get_facility_requests');
      setRequests(isRpcError(r) ? [] : (r?.data ?? []));
    } catch (e: unknown) {
      setRequests([]);
    }
    setLoading(false);
  }

  async function handleSubmit() {
    if (!formDesc.trim()) {
      toast.error('Deskripsi wajib diisi');
      return;
    }
    setSubmitting(true);
    try {
      const r = await rpc('create_facility_request', {
        p_type: formType,
        p_desc: formDesc,
        p_priority: formPriority,
      });
      if (r?.ok) {
        toast.success(r.msg || 'Request terkirim');
        setFormDesc('');
        loadData();
      } else {
        toast.error(r?.msg || 'Gagal mengirim request');
      }
    } catch (e: unknown) {
      toast.error('Gagal mengirim request');
    }
    setSubmitting(false);
  }

  if (loading) return <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center"><LoadingSpinner text="Memuat data fasilitas..." /></div>;

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 pb-24">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <h1 className="text-xl font-bold text-white mb-1">🏠 Fasilitas</h1>
        <p className="text-xs text-slate-400 mb-4">Request perbaikan mess, kantor, kendaraan</p>

        <div className="grid grid-cols-2 gap-2 mb-4">
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-amber-400">{requests.filter(r => r.status === 'PENDING').length}</div><div className="text-[11px] text-slate-400">Pending</div></GlassCard>
          <GlassCard className="text-center p-3"><div className="text-xl font-bold text-blue-400">{requests.filter(r => r.status === 'IN_PROGRESS').length}</div><div className="text-[11px] text-slate-400">In Progress</div></GlassCard>
        </div>

        <div className="space-y-2">
          {requests.map((r, i) => (
            <GlassCard key={i} className="p-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-sm font-bold text-white">{r.id} — {r.type}</span>
                <Badge status={r.status || 'PENDING'} type={STATUS_COLOR[r.status || 'PENDING'] || 'default'} />
              </div>
              <p className="text-xs text-slate-300 mb-2">{r.description}</p>
              <div className="flex justify-between text-[11px] text-slate-500">
                <span>📍 {r.location} • <Badge status={r.priority || 'MEDIUM'} type={PRI_COLOR[r.priority || 'MEDIUM'] || 'default'} /></span>
                <span>{r.submitted}</span>
              </div>
              {r.assigned && <div className="text-[11px] text-teal-400 mt-1">👤 {r.assigned}</div>}
            </GlassCard>
          ))}
        </div>

        <GlassCard title="📝 Ajukan Request" icon="📝" accent="blue" className="mt-4">
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-2">
              <select aria-label="Jenis request fasilitas" value={formType} onChange={e => setFormType(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option>Mess Repair</option><option>Office Supply</option><option>Vehicle Repair</option><option>Water System</option><option>Electricity</option><option>Other</option>
              </select>
              <select aria-label="Prioritas request" value={formPriority} onChange={e => setFormPriority(e.target.value)} className="bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option value="LOW">LOW</option><option value="MEDIUM">MEDIUM</option><option value="HIGH">HIGH</option><option value="URGENT">URGENT</option>
              </select>
            </div>
            <textarea value={formDesc} onChange={e => setFormDesc(e.target.value)} className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white h-16" placeholder="Deskripsi perbaikan..." />
            <button onClick={handleSubmit} disabled={submitting} className="w-full py-2 rounded-lg bg-blue-500/20 text-blue-400 text-sm font-bold hover:bg-blue-500/30 disabled:opacity-50">
              {submitting ? '⏳ Mengirim...' : '📤 Kirim Request'}
            </button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
