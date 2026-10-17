import { useState, useEffect } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, DataTable, Badge, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function SuccessionPlanning() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // BT fix (42883): get_succession(p_nrp text) TANPA DEFAULT — wajib kirim
    // p_nrp dari session; tanpa argumen PostgREST membalas "function does not exist".
    rpc('get_succession', { p_nrp: getSession()?.nrp ?? '' }).then(r => {
      setData(Array.isArray(r) ? r : []);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  return (
    <PageLayout title="Rencana Suksesi" subtitle="Perencanaan penerus jabatan strategis">
      <GlassCard>
        {loading ? <LoadingSpinner /> : data.length === 0 ? (
          <EmptyState title="Belum ada data rencana suksesi" />
        ) : (
          <DataTable data={data} columns={[
            { key: 'position', label: 'Posisi' },
            { key: 'incumbent', label: 'Pemegang Saat Ini' },
            { key: 'successor_1', label: 'Kandidat 1' },
            { key: 'successor_2', label: 'Kandidat 2' },
            { key: 'readiness', label: 'Kesiapan', render: (v: unknown) => <Badge status={String(v)} type={v === "ready" ? "success" : v === "development" ? "warning" : "default"} /> },
            { key: 'target_date', label: 'Target Date' },
          ]} />
        )}
      </GlassCard>
    </PageLayout>
  );
}
