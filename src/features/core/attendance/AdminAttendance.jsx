import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';

export default function AdminAttendance() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [periode, setPeriode] = useState(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
  });

  useEffect(() => { loadData(); }, [periode]);

  async function loadData() {
    setLoading(true);
    try {
      const d = await rpc('admin_get_timesheet', {});
      setData(d?.ok !== false ? (d || []) : []);
    } catch { setData([]); }
    setLoading(false);
  }

  const stats = {
    total: data.length,
    hadir: data.filter(d => d.status_hadir === 'Hadir').length,
    terlambat: data.filter(d => d.menit_terlambat > 0).length,
    alpha: data.filter(d => d.status_hadir === 'Alpha').length,
  };

  return (
    <div style={{ padding: 16 }}>
      <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>📅 Admin Attendance Dashboard</h2>
      
      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <input type="month" value={periode} onChange={e => setPeriode(e.target.value)}
          style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid #ddd' }} />
        <button onClick={loadData} style={{ padding: '6px 14px', borderRadius: 6, background: '#10b981', color: '#fff', border: 'none', cursor: 'pointer' }}>
          Refresh
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 16 }}>
        {[
          { label: 'Total', value: stats.total, color: '#3b82f6' },
          { label: 'Hadir', value: stats.hadir, color: '#10b981' },
          { label: 'Terlambat', value: stats.terlambat, color: '#f59e0b' },
          { label: 'Alpha', value: stats.alpha, color: '#ef4444' },
        ].map(s => (
          <div key={s.label} style={{ padding: 12, borderRadius: 8, background: '#f8fafc', border: `2px solid ${s.color}` }}>
            <div style={{ fontSize: 11, color: '#666' }}>{s.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: s.color }}>{s.value}</div>
          </div>
        ))}
      </div>

      {loading ? <p style={{ color: '#999' }}>Loading...</p> : (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr style={{ background: '#f1f5f9' }}>
                <th style={th}>NRP</th>
                <th style={th}>Nama</th>
                <th style={th}>Tanggal</th>
                <th style={th}>Status</th>
                <th style={th}>Masuk</th>
                <th style={th}>Keluar</th>
                <th style={th}>Terlambat</th>
              </tr>
            </thead>
            <tbody>
              {data.slice(0, 50).map((row, i) => (
                <tr key={i} style={{ borderBottom: '1px solid #eee' }}>
                  <td style={td}>{row.nrp}</td>
                  <td style={td}>{row.nama}</td>
                  <td style={td}>{row.date}</td>
                  <td style={td}>
                    <span style={{ 
                      padding: '2px 8px', borderRadius: 10, fontSize: 11,
                      background: row.status_hadir === 'Hadir' ? '#dcfce7' : row.status_hadir === 'Alpha' ? '#fee2e2' : '#fef3c7',
                      color: row.status_hadir === 'Hadir' ? '#166534' : row.status_hadir === 'Alpha' ? '#991b1b' : '#92400e'
                    }}>{row.status_hadir || '-'}</span>
                  </td>
                  <td style={td}>{row.jam_masuk || '-'}</td>
                  <td style={td}>{row.jam_keluar || '-'}</td>
                  <td style={td}>{row.menit_terlambat > 0 ? `${row.menit_terlambat}m` : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

const th = { textAlign: 'left', padding: '8px 6px', fontSize: 11, fontWeight: 600, color: '#555' };
const td = { padding: '6px', fontSize: 12 };
