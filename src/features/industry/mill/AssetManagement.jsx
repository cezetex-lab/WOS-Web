// ============================================================
// AssetManagement.jsx — #131-134 Asset Management
// RPC: get_assets, checkout_asset, checkin_asset, admin_get_assets, admin_get_asset_assignments
// ============================================================

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, rpc, getSession } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Badge, LoadingSpinner,
  EmptyState, Tabs, Input, StatItem, Divider
} from '../../../lib/design-system';

// Inline Modal
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

const CATEGORIES = [
  { key: 'all', label: '📦 Semua' },
  { key: 'equipment', label: '🚜 Alat Berat' },
  { key: 'vehicle', label: '🚛 Kendaraan' },
  { key: 'it', label: '💻 IT & Elektronik' },
  { key: 'office', label: '🏢 Kantor' },
  { key: 'safety', label: '🦺 Safety' },
];

const CONDITION_COLORS = { good: 'green', fair: 'yellow', poor: 'red', maintenance: 'orange' };

export default function AssetManagement() {
  const nrp = getSession()?.nrp;
  const [loading, setLoading] = useState(true);
  const [assets, setAssets] = useState([]);
  const [assignments, setAssignments] = useState([]);
  const [tab, setTab] = useState('inventory');
  const [catFilter, setCatFilter] = useState('all');
  const [showCheckout, setShowCheckout] = useState(null);
  const [showCheckin, setShowCheckin] = useState(null);
  const [condition, setCondition] = useState('good');
  const [note, setNote] = useState('');

  const fetchAssets = useCallback(async () => {
    setLoading(true);
    try {
      const { data: a1 } = await supabase.rpc('admin_get_assets');
      if (a1?.ok) setAssets(a1.data || []);
      const { data: a2 } = await supabase.rpc('admin_get_asset_assignments');
      if (a2?.ok) setAssignments(a2.data || []);
    } catch (e) { }
    setLoading(false);
  }, []);

  useEffect(() => { fetchAssets(); }, [fetchAssets]);

  const handleCheckout = async (assetId) => {
    try {
      await supabase.rpc('checkout_asset', { p_asset_id: assetId, p_nrp: nrp });
      setShowCheckout(null);
      fetchAssets();
    } catch (e) { }
  };

  const handleCheckin = async (assetId) => {
    try {
      await supabase.rpc('checkin_asset', { p_asset_id: assetId, p_condition: condition });
      setShowCheckin(null);
      setCondition('good');
      fetchAssets();
    } catch (e) { }
  };

  const filtered = catFilter === 'all' ? assets : assets.filter(a => a.category === catFilter);
  const totalAssets = assets.length;
  const checkedOut = assignments.filter(a => !a.returned_at).length;
  const available = totalAssets - checkedOut;

  const tabs = [
    { key: 'inventory', label: '📦 Inventaris' },
    { key: 'assignments', label: '🔄 Check-in/out' },
    { key: 'vehicles', label: '🚛 Kendaraan' },
    { key: 'facility', label: '🏢 Fasilitas' },
  ];

  return (
    <PageLayout title="📦 Manajemen Aset">
      <div className="space-y-4">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />

        {/* Stats */}
        <div className="grid grid-cols-3 gap-3">
          <StatItem label="Total Aset" value={totalAssets} />
          <StatItem label="Tersedia" value={available} color="green" />
          <StatItem label="Dipinjam" value={checkedOut} color="orange" />
        </div>

        {tab === 'inventory' && (
          <>
            {/* Category Filter */}
            <div className="flex gap-2 overflow-x-auto pb-2">
              {CATEGORIES.map(c => (
                <button
                  key={c.key}
                  onClick={() => setCatFilter(c.key)}
                  className={`px-3 py-1.5 rounded-lg text-xs whitespace-nowrap transition-all ${
                    catFilter === c.key ? 'bg-blue-500 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                  }`}
                >
                  {c.label}
                </button>
              ))}
            </div>

            {loading ? <LoadingSpinner /> : filtered.length === 0 ? (
              <EmptyState icon="📦" title="Belum ada aset" subtitle="Aset akan muncul di sini setelah didaftarkan" />
            ) : (
              <div className="space-y-2">
                {filtered.map((a) => (
                  <GlassCard key={a.id} className="p-3">
                    <div className="flex items-center justify-between">
                      <div className="flex-1">
                        <p className="text-white text-sm font-medium">{a.name || a.machine_id || `Aset #${a.id}`}</p>
                        <p className="text-slate-400 text-xs">{a.category || '-'} · {a.location || '-'}</p>
                      </div>
                      <Badge color={CONDITION_COLORS[a.condition] || 'slate'}>{a.condition || 'N/A'}</Badge>
                    </div>
                  </GlassCard>
                ))}
              </div>
            )}
          </>
        )}

        {tab === 'assignments' && (
          loading ? <LoadingSpinner /> : assignments.length === 0 ? (
            <EmptyState icon="🔄" title="Belum ada peminjaman" subtitle="Check-in/out aset akan tercatat di sini" />
          ) : (
            <div className="space-y-2">
              {assignments.map((a) => (
                <GlassCard key={a.id} className="p-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-white text-sm">{a.asset_name || a.machine_id || `Aset #${a.asset_id}`}</p>
                      <p className="text-slate-400 text-xs">oleh: {a.nrp || a.user_nrp} · {a.date || a.checked_out_at || '-'}</p>
                    </div>
                    <Badge color={a.returned_at ? 'green' : 'orange'}>
                      {a.returned_at ? '✅ Dikembalikan' : '🔄 Dipinjam'}
                    </Badge>
                  </div>
                </GlassCard>
              ))}
            </div>
          )
        )}

        {tab === 'vehicles' && (
          <div className="space-y-2">
            {assets.filter(a => a.category === 'vehicle' || a.type === 'vehicle').length === 0 ? (
              <EmptyState icon="🚛" title="Belum ada kendaraan" subtitle="Data kendaraan akan muncul setelah didaftarkan" />
            ) : (
              assets.filter(a => a.category === 'vehicle' || a.type === 'vehicle').map((a) => (
                <GlassCard key={a.id} className="p-3">
                  <p className="text-white text-sm">{a.name || a.machine_id}</p>
                  <p className="text-slate-400 text-xs">{a.plate || '-'} · {a.condition || '-'}</p>
                </GlassCard>
              ))
            )}
          </div>
        )}

        {tab === 'facility' && (
          <EmptyState icon="🏢" title="Fasilitas Kantor" subtitle="Pengajuan perbaikan mess, perumahan, atau fasilitas akan ada di sini" />
        )}
      </div>

      {/* Checkout Modal */}
      {showCheckout && (
        <Modal onClose={() => setShowCheckout(null)} title="📤 Checkout Aset">
          <div className="space-y-3">
            <p className="text-slate-300 text-sm">Pinjam aset: {showCheckout.name || showCheckout.machine_id}?</p>
            <Button onClick={() => handleCheckout(showCheckout.id)} className="w-full">✅ Konfirmasi Pinjam</Button>
          </div>
        </Modal>
      )}

      {/* Checkin Modal */}
      {showCheckin && (
        <Modal onClose={() => setShowCheckin(null)} title="📥 Check-in Aset">
          <div className="space-y-3">
            <p className="text-slate-300 text-sm">Kembalikan: {showCheckin.name || showCheckin.machine_id}</p>
            <div>
              <label className="text-xs text-slate-400 mb-1 block">Kondisi Saat Dikembalikan</label>
              <div className="flex gap-2">
                {['good', 'fair', 'poor'].map(c => (
                  <button
                    key={c}
                    onClick={() => setCondition(c)}
                    className={`flex-1 py-2 rounded-lg text-xs font-semibold ${
                      condition === c ? 'bg-blue-500 text-white' : 'bg-slate-700 text-slate-300'
                    }`}
                  >
                    {c === 'good' ? '✅ Baik' : c === 'fair' ? '⚠️ Cukup' : '🔴 Rusak'}
                  </button>
                ))}
              </div>
            </div>
            <Button onClick={() => handleCheckin(showCheckin.id)} className="w-full">✅ Kembalikan</Button>
          </div>
        </Modal>
      )}
    </PageLayout>
  );
}
