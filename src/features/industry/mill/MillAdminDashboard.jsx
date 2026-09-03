import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { useNavigate } from 'react-router-dom';

export default function MillAdminDashboard() {
  const navigate = useNavigate();
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const r = await rpc('get_industry_admin_stats', { p_industry: 'mill' });
        setStats(r || {});
      } catch (e) { /* silent */ }
      setLoading(false);
    })();
  }, []);

  const modules = [
    { name: 'Boiler Monitor', path: '/worker/boiler', icon: '🔥', desc: 'Pemantauan Boiler PKS' },
    { name: 'Mesin Press', path: '/worker/machines', icon: '⚙️', desc: 'Mesin Press & Pemipahan' },
    { name: 'QC Lab', path: '/worker/qc', icon: '🔬', desc: 'Quality Control Laboratorium' },
    { name: 'Packing Log', path: '/worker/packing', icon: '📦', desc: 'Log Pengemasan CPO' },
    { name: 'Preventive Maintenance', path: '/worker/maintenance', icon: '🔧', desc: 'Pemeliharaan Berkala' },
    { name: 'Breakdown Log', path: '/worker/breakdown', icon: '⚠️', desc: 'Log Kerusakan Mesin' },
    { name: 'Shift Schedule', path: '/worker/shift', icon: '📅', desc: 'Jadwal Shift Pabrik' },
  ];

  if (loading) return <div className="min-h-screen flex items-center justify-center"><div className="animate-spin w-8 h-8 border-2 border-cyan-400 border-t-transparent rounded-full"></div></div>;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center gap-3 mb-8">
          <div className="w-12 h-12 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-xl flex items-center justify-center text-2xl">🏭</div>
          <div>
            <h1 className="text-white font-bold text-xl">Admin Pabrik (Mill/PKS)</h1>
            <p className="text-gray-400 text-sm">Dashboard administrasi pabrik kelapa sawit</p>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-cyan-400">{stats.workers || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Karyawan</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-blue-400">{stats.boilers || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Unit Boiler</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-orange-400">{stats.maintenance || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Maintenance Aktif</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-cyan-400">Active</div>
            <div className="text-gray-400 text-xs mt-1">Status</div>
          </div>
        </div>

        <h3 className="text-white font-bold text-sm mb-4">Modul Pabrik</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {modules.map(m => (
            <button key={m.path} onClick={() => navigate(m.path)} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5 text-left hover:border-cyan-500/50 hover:bg-gray-700/40 transition-all group">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">{m.icon}</span>
                <span className="text-white font-bold text-sm group-hover:text-cyan-400 transition-colors">{m.name}</span>
              </div>
              <p className="text-gray-400 text-xs">{m.desc}</p>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
