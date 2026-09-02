// FacilityRequest.jsx — Estate Facility Request (Mess, Kerja, Dll)
import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { GlassCard, Badge, LoadingSpinner, useToast } from '@/lib/design-system';

const REQUESTS = [
  { id: 'FAC-001', type: 'Mess Repair', location: 'Mess Blok A', description: 'Atap bocor kamar 3', status: 'IN_PROGRESS', priority: 'HIGH', submitted: '2026-08-25', assigned: 'Maintenance Team' },
  { id: 'FAC-002', type: 'Office Supply', location: 'Kantor Estate', description: 'Printer toner habis', status: 'APPROVED', priority: 'MEDIUM', submitted: '2026-08-27', assigned: 'Admin' },
  { id: 'FAC-003', type: 'Vehicle Repair', location: 'Garage', description: 'Ban depan truk T-003 bocor', status: 'PENDING', priority: 'HIGH', submitted: '2026-08-28', assigned: null },
  { id: 'FAC-004', type: 'Water System', location: 'Mess Blok B', description: 'Pompa air mati', status: 'RESOLVED', priority: 'URGENT', submitted: '2026-08-22', assigned: 'Plumber' },
  { id: 'FAC-005', type: 'Electricity', location: 'Gudang', description: 'MCB sering trip', status: 'PENDING', priority: 'MEDIUM', submitted: '2026-08-28', assigned: null },
];

const PRI_COLOR = { URGENT: 'danger', HIGH: 'warning', MEDIUM: 'info', LOW: 'default' };
const STATUS_COLOR = { PENDING: 'warning', APPROVED: 'info', IN_PROGRESS: 'info', RESOLVED: 'success' };

export default function FacilityRequest() {
  const [loading, setLoading] = useState(true);
  const [requests, setRequests] = useState([]);

  useEffect(() => { rpc('admin_get_facility_requests').then(r => { setRequests(r?.data || []); setLoading(false); }).catch(() => setLoading(false)); }, []);

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
                <Badge status={r.status} type={STATUS_COLOR[r.status]} />
              </div>
              <p className="text-xs text-slate-300 mb-2">{r.description}</p>
              <div className="flex justify-between text-[11px] text-slate-500">
                <span>📍 {r.location} • <Badge status={r.priority} type={PRI_COLOR[r.priority]} /></span>
                <span>{r.submitted}</span>
              </div>
              {r.assigned && <div className="text-[11px] text-teal-400 mt-1">👤 {r.assigned}</div>}
            </GlassCard>
          ))}
        </div>

        <GlassCard title="📝 Ajukan Request" icon="📝" accent="blue" className="mt-4">
          <div className="space-y-3">
            <select className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
              <option>Mess Repair</option><option>Office Supply</option><option>Vehicle Repair</option><option>Water System</option><option>Electricity</option><option>Other</option>
            </select>
            <textarea className="w-full bg-slate-800/50 border border-white/10 rounded-lg px-3 py-2 text-sm text-white h-16" placeholder="Deskripsi perbaikan..." />
            <button className="w-full py-2 rounded-lg bg-blue-500/20 text-blue-400 text-sm font-bold hover:bg-blue-500/30">📤 Kirim Request</button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
