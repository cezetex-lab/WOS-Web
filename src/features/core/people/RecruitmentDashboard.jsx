// RecruitmentDashboard.jsx — Manajemen Lowongan & Rekrutmen
import React, { useState, useEffect, useCallback } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import { PageLayout, GlassCard, MetricCard, DataTable, Badge, Button, LoadingSpinner, EmptyState, Tabs } from '../../../lib/design-system';

export default function RecruitmentDashboard() {
  const [loading, setLoading] = useState(true);
  const [vacancies, setVacancies] = useState([]);
  const [candidates, setCandidates] = useState([]);
  const [tab, setTab] = useState('vacancies');
  const [selectedVacancy, setSelectedVacancy] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [v, c] = await Promise.all([
        rpc('admin_get_vacancies'),
        rpc('get_candidate_pipeline'),
      ]);
      setVacancies(Array.isArray(v) ? v : v?.data || []);
      setCandidates(Array.isArray(c) ? c : c?.data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const stages = ['Applied', 'Screening', 'Interview', 'Offer', 'Hired', 'Rejected'];
  const stageCount = stages.reduce((acc, s) => {
    acc[s] = candidates.filter(c => c.stage === s).length;
    return acc;
  }, {});

  const vacancyColumns = [
    { key: 'title', label: 'Posisi', render: v => <span className="text-sm font-semibold text-white">{v || '-'}</span> },
    { key: 'department', label: 'Divisi', render: v => <Badge status={v || '-'} type="info" /> },
    { key: 'location', label: 'Lokasi', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'applicants', label: 'Pelamar', render: v => <span className="text-sm font-bold text-blue-400">{v || 0}</span> },
    { key: 'status', label: 'Status', render: v => <Badge status={v || 'Open'} type={v === 'Open' ? 'success' : v === 'Closed' ? 'danger' : 'warning'} /> },
  ];

  const candidateColumns = [
    { key: 'candidate_name', label: 'Nama', render: v => <span className="text-sm font-semibold text-white">{v}</span> },
    { key: 'candidate_email', label: 'Email', render: v => <span className="text-xs text-slate-300">{v || '-'}</span> },
    { key: 'stage', label: 'Stage', render: v => <Badge status={v} type={v === 'Hired' ? 'success' : v === 'Rejected' ? 'danger' : v === 'Interview' ? 'warning' : 'info'} /> },
    { key: 'rating', label: 'Rating', render: v => <span className="text-sm text-yellow-400">{'⭐'.repeat(Math.min(v || 0, 5))}</span> },
    { key: 'created_at', label: 'Tanggal', render: v => <span className="text-xs text-slate-300">{v ? new Date(v).toLocaleDateString('id-ID') : '-'}</span> },
  ];

  if (loading) return <PageLayout backTo="/admin" title="Rekrutmen"><LoadingSpinner text="Memuat data rekrutmen..." /></PageLayout>;

  return (
    <PageLayout backTo="/admin" title="📌 Rekrutmen" subtitle={`${vacancies.length} lowongan, ${candidates.length} pelamar`}>
      <div className="grid grid-cols-4 gap-3 mb-6">
        <MetricCard icon="📋" value={vacancies.length} label="Lowongan" color="blue" />
        <MetricCard icon="👥" value={candidates.length} label="Pelamar" color="teal" />
        <MetricCard icon="🎯" value={stageCount['Hired'] || 0} label="Hired" color="green" />
        <MetricCard icon="⏳" value={stageCount['Interview'] || 0} label="Interview" color="orange" />
      </div>

      {/* Pipeline Visual */}
      <GlassCard accent="blue" className="mb-4">
        <h3 className="text-xs font-bold text-white mb-3">📊 Pipeline Overview</h3>
        <div className="flex gap-1">
          {stages.filter(s => s !== 'Rejected').map(s => (
            <div key={s} className="flex-1 text-center">
              <div className={`h-2 rounded-full mb-1 ${s === 'Hired' ? 'bg-green-500' : s === 'Interview' ? 'bg-orange-500' : 'bg-blue-500'}`} style={{ height: `${Math.max((stageCount[s] || 0) * 8, 4)}px` }} />
              <p className="text-[10px] text-slate-400">{s}</p>
              <p className="text-xs font-bold text-white">{stageCount[s] || 0}</p>
            </div>
          ))}
        </div>
      </GlassCard>

      <Tabs tabs={[
        { id: 'vacancies', label: '📋 Lowongan', count: vacancies.length },
        { id: 'candidates', label: '👥 Pelamar', count: candidates.length },
      ]} active={tab} onChange={setTab} />

      <div className="mt-4">
        <GlassCard accent="blue">
          {tab === 'vacancies' ? (
            <DataTable columns={vacancyColumns} data={vacancies} searchPlaceholder="Cari lowongan..." emptyMessage="Belum ada lowongan" />
          ) : (
            <DataTable columns={candidateColumns} data={candidates} searchPlaceholder="Cari pelamar..." emptyMessage="Belum ada pelamar" />
          )}
        </GlassCard>
      </div>
    </PageLayout>
  );
}
