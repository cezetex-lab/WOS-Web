// ExportPage.jsx — Ekspor data ke Excel/CSV
import React, { useState, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, Button, LoadingSpinner } from '../../../lib/design-system';

const EXPORT_OPTIONS = [
  { id: 'employees', label: 'Karyawan', icon: '👥', desc: 'Data master karyawan' },
  { id: 'payroll', label: 'Payroll', icon: '💰', desc: 'Slip gaji bulanan' },
  { id: 'attendance', label: 'Kehadiran', icon: '📍', desc: 'Riwayat kehadiran' },
  { id: 'performance', label: 'KPI', icon: '📊', desc: 'Skor performa' },
  { id: 'overtime', label: 'Lembur', icon: '⏰', desc: 'Pengajuan lembur' },
  { id: 'leave', label: 'Cuti', icon: '🌴', desc: 'Pengajuan cuti' },
  { id: 'training', label: 'Training', icon: '📚', desc: 'Program pelatihan' },
  { id: 'assets', label: 'Aset', icon: '🛠️', desc: 'Inventaris aset' },
  { id: 'audit_log', label: 'Audit Log', icon: '📋', desc: 'Log aktivitas' },
];

export default function ExportPage() {
  const [exporting, setExporting] = useState(null);

  const handleExport = useCallback(async (sheet) => {
    setExporting(sheet.id);
    try {
      const result = await rpc('admin_export_sheet', { p_sheet: sheet.id });
      const csv = result?.csv || result?.data;
      if (csv) {
        const blob = new Blob([typeof csv === 'string' ? csv : JSON.stringify(csv, null, 2)], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `insightWOS_${sheet.id}_${new Date().toISOString().slice(0, 10)}.csv`;
        a.click();
        URL.revokeObjectURL(url);
      }
    } catch (e) { if (import.meta.env.DEV) console.error('Export failed:', e); alert('Export gagal. Silakan coba lagi.'); }
    setExporting(null);
  }, []);

  return (
    <PageLayout backTo="/admin" title="📤 Export Data" subtitle="Ekspor data ke Excel/CSV">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {EXPORT_OPTIONS.map(sheet => (
          <GlassCard key={sheet.id} accent="blue" className="cursor-pointer hover:border-blue-500/30 transition-all">
            <div className="flex items-center gap-3">
              <span className="text-3xl">{sheet.icon}</span>
              <div className="flex-1">
                <h3 className="text-sm font-bold text-white">{sheet.label}</h3>
                <p className="text-xs text-slate-400">{sheet.desc}</p>
              </div>
              <Button
                size="sm"
                color="teal"
                disabled={exporting === sheet.id}
                onClick={() => handleExport(sheet)}
              >
                {exporting === sheet.id ? '⏳...' : '📤 Export'}
              </Button>
            </div>
          </GlassCard>
        ))}
      </div>
      <GlassCard accent="slate" className="mt-6">
        <p className="text-xs text-slate-400 text-center">
          📋 File akan diunduh dalam format CSV. Buka dengan Excel atau Google Sheets.
        </p>
      </GlassCard>
    </PageLayout>
  );
}
