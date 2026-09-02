import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';

export default function TimesheetManagement() {
  const [timesheets, setTimesheets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');

  useEffect(() => { loadTimesheets(); }, []);

  async function loadTimesheets() {
    setLoading(true);
    try {
      const d = await rpc('admin_get_timesheet', {});
      setTimesheets(d?.ok !== false ? (d || []) : []);
    } catch { setTimesheets([]); }
    setLoading(false);
  }

  const filtered = filter === 'all' ? timesheets : timesheets.filter(t => t.status_hadir === filter);

  return (
    <div style={{ padding: 16 }}>
      <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>📋 Timesheet Management</h2>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        {['all', 'Hadir', 'Terlambat', 'Alpha', 'Cuti'].map(f => (
          <button key={f} onClick={() => setFilter(f)}
            style={{ padding: '6px 14px', borderRadius: 6, border: filter === f ? '2px solid #3b82f6' : '1px solid #ddd', 
              background: filter === f ? '#eff6ff' : '#fff', cursor: 'pointer', fontSize: 12 }}>
            {f === 'all' ? 'Semua' : f}
          </button>
        ))}
      </div>

      {loading ? <p style={{ color: '#999' }}>Loading...</p> : (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr style={{ background: '#f1f5f9' }}>
                <th style={th}>NRP</th>
                <th style={th}>Nama</th>
                <th style={th}>Departemen</th>
                <th style={th}>Tanggal</th>
                <th style={th}>Shift</th>
                <th style={th}>Masuk</th>
                <th style={th}>Keluar</th>
                <th style={th}>Jam Kerja</th>
                <th style={th}>Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.slice(0, 100).map((row, i) => (
                <tr key={i} style={{ borderBottom: '1px solid #eee' }}>
                  <td style={td}>{row.nrp}</td>
                  <td style={td}>{row.nama}</td>
                  <td style={td}>{row.divisi || '-'}</td>
                  <td style={td}>{row.date}</td>
                  <td style={td}>{row.shift || '-'}</td>
                  <td style={td}>{row.jam_masuk || '-'}</td>
                  <td style={td}>{row.jam_keluar || '-'}</td>
                  <td style={td}>{row.jam_kerja ? `${row.jam_kerja}j` : '-'}</td>
                  <td style={td}>
                    <span style={{ padding: '2px 8px', borderRadius: 10, fontSize: 11,
                      background: row.status_hadir === 'Hadir' ? '#dcfce7' : '#fee2e2',
                      color: row.status_hadir === 'Hadir' ? '#166534' : '#991b1b'
                    }}>{row.status_hadir || '-'}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p style={{ fontSize: 11, color: '#999', marginTop: 8 }}>Menampilkan {filtered.length} dari {timesheets.length} records</p>
        </div>
      )}
    </div>
  );
}

const th = { textAlign: 'left', padding: '8px 6px', fontSize: 11, fontWeight: 600, color: '#555' };
const td = { padding: '6px', fontSize: 12 };
