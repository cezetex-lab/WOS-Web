import { useState, useEffect } from 'react';
import { rpc, getSession } from '@/lib/supabase-browser';

export default function CareerDevelopment() {
  const [careerPath, setCareerPath] = useState(null);
  const [loading, setLoading] = useState(true);
  const session = getSession();

  useEffect(() => { loadCareerPath(); }, []);

  async function loadCareerPath() {
    setLoading(true);
    try {
      const nrp = session?.nrp || 'NRP001';
      const d = await rpc('get_worker_career', { p_nrp: nrp });
      setCareerPath(d?.ok !== false ? d : null);
    } catch { setCareerPath(null); }
    setLoading(false);
  }

  return (
    <div style={{ padding: 16 }}>
      <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>🚀 Career Development</h2>
      <p style={{ fontSize: 12, color: '#666', marginBottom: 16 }}>Pengembangan karir dan jalur karir Anda</p>

      {loading ? <p style={{ color: '#999' }}>Loading...</p> : !careerPath ? (
        <div style={{ padding: 24, textAlign: 'center', background: '#f8fafc', borderRadius: 8, border: '1px dashed #ddd' }}>
          <p style={{ color: '#999', fontSize: 13 }}>Data career path belum tersedia</p>
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {/* Current Position */}
          <div style={{ padding: 16, borderRadius: 8, border: '2px solid #3b82f6', background: '#eff6ff' }}>
            <div style={{ fontSize: 11, color: '#3b82f6', fontWeight: 600, marginBottom: 4 }}>POSISI SAAT INI</div>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{careerPath.current_position || careerPath.posisi || '-'}</div>
            <div style={{ fontSize: 12, color: '#555' }}>{careerPath.department || careerPath.divisi || '-'}</div>
          </div>

          {/* Career Path */}
          {careerPath.next_positions && careerPath.next_positions.length > 0 && (
            <div style={{ padding: 16, borderRadius: 8, border: '1px solid #e2e8f0' }}>
              <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>📍 Jalur Karir Selanjutnya</div>
              {careerPath.next_positions.map((pos, i) => (
                <div key={i} style={{ padding: '8px 0', borderBottom: i < careerPath.next_positions.length - 1 ? '1px solid #f1f5f9' : 'none' }}>
                  <div style={{ fontSize: 13, fontWeight: 500 }}>{pos.title || pos}</div>
                  {pos.gap && <div style={{ fontSize: 11, color: '#f59e0b' }}>Gap: {pos.gap}</div>}
                </div>
              ))}
            </div>
          )}

          {/* Skills */}
          {careerPath.skills && (
            <div style={{ padding: 16, borderRadius: 8, border: '1px solid #e2e8f0' }}>
              <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>💡 Skills & Kompetensi</div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {(Array.isArray(careerPath.skills) ? careerPath.skills : []).map((skill, i) => (
                  <span key={i} style={{ padding: '4px 10px', borderRadius: 12, fontSize: 11, background: '#f1f5f9', color: '#334155' }}>
                    {typeof skill === 'string' ? skill : skill.name || skill}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
