import { useState, useEffect } from 'react';
import { getSession } from '@/lib/supabase-browser';
import { rpc } from '@/lib/supabase-browser';
import { PageLayout, GlassCard, DataTable, Badge, LoadingSpinner, EmptyState } from '@/lib/design-system';

export default function CareerDevelopment() {
  const session = getSession();
  const nrp = session?.nrp;
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!nrp) { setLoading(false); return; }
    rpc('get_career_path', { p_nrp: nrp }).then(r => {
      setData(Array.isArray(r) ? r : []);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [nrp]);

  return (
    <PageLayout title="Pengembangan Karir" subtitle="Rencana dan progres pengembangan karir Anda">
      <GlassCard>
        {loading ? <LoadingSpinner /> : data.length === 0 ? (
          <EmptyState message="Belum ada data pengembangan karir" />
        ) : (
          <DataTable
            data={data}
            columns={[
              { key: 'career_level', label: 'Level' },
              { key: 'target_position', label: 'Target Posisi' },
              { key: 'timeline', label: 'Timeline' },
              { key: 'gap_analysis', label: 'Gap Analysis' },
              { key: 'action_plan', label: 'Rencana Aksi' },
              { key: 'status', label: 'Status', render: v => <Badge variant={v === 'active' ? 'success' : 'default'}>{v}</Badge> },
            ]}
          />
        )}
      </GlassCard>
    </PageLayout>
  );
}
