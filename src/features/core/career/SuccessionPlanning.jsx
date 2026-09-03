import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, DataTable, Badge, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function SuccessionPlanning() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    rpc('get_succession', {}).then(r => {
      setData(Array.isArray(r) ? r : []);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  return (
    <PageLayout title="Rencana Suksesi" subtitle="Perencanaan penerus jabatan strategis">
      <GlassCard>
        {loading ? <LoadingSpinner /> : data.length === 0 ? (
          <EmptyState message="Belum ada data rencana suksesi" />
        ) : (
          <DataTable data={data} columns={[
            { key: 'position', label: 'Posisi' },
            { key: 'incumbent', label: 'Pemegang Saat Ini' },
            { key: 'successor_1', label: 'Kandidat 1' },
            { key: 'successor_2', label: 'Kandidat 2' },
            { key: 'readiness', label: 'Kesiapan', render: v => <Badge variant={v === "ready" ? "success" : v === "development" ? "warning" : "default"}>{v}</Badge> },
            { key: 'target_date', label: 'Target Date' },
          ]} />
        )}
      </GlassCard>
    </PageLayout>
  );
}
