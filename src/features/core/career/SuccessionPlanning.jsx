import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';

export default function SuccessionPlanning() {
  const [matrix, setMatrix] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { loadMatrix(); }, []);

  async function loadMatrix() {
    setLoading(true);
    try {
      const d = await rpc('get_succession_matrix', {});
      setMatrix(d?.ok !== false ? (d || []) : []);
    } catch { setMatrix([]); }
    setLoading(false);
  }

  return (
    <div style={{ padding: 16 }}>
      <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>👥 Succession Planning</h2>
      <p style={{ fontSize: 12, color: '#666', marginBottom: 16 }}>Rencana suksesi untuk posisi kunci organisasi</p>

      {loading ? <p style={{ color: '#999' }}>Loading...</p> : matrix.length === 0 ? (
        <div style={{ padding: 24, textAlign: 'center', background: '#f8fafc', borderRadius: 8, border: '1px dashed #ddd' }}>
          <p style={{ color: '#999', fontSize: 13 }}>Belum ada data succession planning</p>
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {matrix.map((row, i) => (
            <div key={i} style={{ padding: 16, borderRadius: 8, border: '1px solid #e2e8f0', background: '#fff' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                <div>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{row.position || row.posisi}</span>
                  <span style={{ fontSize: 11, color: '#999', marginLeft: 8 }}>{row.department || row.divisi}</span>
                </div>
                <span style={{ padding: '2px 10px', borderRadius: 10, fontSize: 11, 
                  background: row.readiness === 'Ready' ? '#dcfce7' : '#fef3c7',
                  color: row.readiness === 'Ready' ? '#166534' : '#92400e'
                }}>{row.readiness || 'TBD'}</span>
              </div>
              <div style={{ fontSize: 12, color: '#555' }}>
                <div>Candidate: <strong>{row.candidate_name || row.candidate_nrp || '-'}</strong></div>
                <div>Current Holder: <strong>{row.current_holder || '-'}</strong></div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
