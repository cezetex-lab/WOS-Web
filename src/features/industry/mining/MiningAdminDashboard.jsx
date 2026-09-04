import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { useNavigate } from 'react-router-dom';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function MiningAdminDashboard() {
  useAdminAuth(["admin_pusat", "admin_mining"]);
  const navigate = useNavigate();
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const r = await rpc('get_industry_admin_stats', { p_industry: 'mining' });
        setStats(r || {});
      } catch (e) { /* silent */ }
      setLoading(false);
    })();
  }, []);

  const modules = [
    { name: 'SIMPER', path: '/worker/simper', icon: '📋', desc: 'Surat Izin Memimpin Pekerjaan' },
    { name: 'Heavy Equipment', path: '/worker/heavy-equip', icon: '🚛', desc: 'Monitor Alat Berat' },
    { name: 'Fatigue Monitor', path: '/worker/fatigue', icon: '😴', desc: 'Pemantauan Kelelahan' },
    { name: 'Production Daily', path: '/worker/production', icon: '⛏️', desc: 'Laporan Produksi Harian' },
    { name: 'Safety K3', path: '/worker/safety', icon: '🛡️', desc: 'Keselamatan & Kesehatan Kerja' },
    { name: 'Emergency', path: '/worker/emergency', icon: '🚨', desc: 'Prosedur Darurat' },
    { name: 'JSA', path: '/worker/jsa', icon: '📝', desc: 'Job Safety Analysis' },
  ];

  if (loading) return <div className="min-h-screen flex items-center justify-center"><div className="animate-spin w-8 h-8 border-2 border-amber-400 border-t-transparent rounded-full"></div></div>;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center gap-3 mb-8">
          <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-red-600 rounded-xl flex items-center justify-center text-2xl">⛏️</div>
          <div>
            <h1 className="text-white font-bold text-xl">Admin Tambang (Mining)</h1>
            <p className="text-gray-400 text-sm">Dashboard administrasi operasi pertambangan</p>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-amber-400">{stats.workers || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Karyawan</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-cyan-400">{stats.equipment || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Alat Berat</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-red-400">{stats.safety_incidents || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Insiden Safety</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-green-400">Active</div>
            <div className="text-gray-400 text-xs mt-1">Status</div>
          </div>
        </div>

        <h3 className="text-white font-bold text-sm mb-4">Modul Tambang</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {modules.map(m => (
            <button key={m.path} onClick={() => navigate(m.path)} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5 text-left hover:border-amber-500/50 hover:bg-gray-700/40 transition-all group">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">{m.icon}</span>
                <span className="text-white font-bold text-sm group-hover:text-amber-400 transition-colors">{m.name}</span>
              </div>
              <p className="text-gray-400 text-xs">{m.desc}</p>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
