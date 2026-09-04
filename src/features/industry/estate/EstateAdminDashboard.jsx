import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';
import { useNavigate } from 'react-router-dom';
import useAdminAuth from '@/hooks/useAdminAuth';

export default function EstateAdminDashboard() {
  useAdminAuth(["admin_pusat", "admin_estate"]);
  const navigate = useNavigate();
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const r = await rpc('get_industry_admin_stats', { p_industry: 'estate' });
        setStats(r || {});
      } catch (e) { /* silent */ }
      setLoading(false);
    })();
  }, []);

  const modules = [
    { name: 'Harvest Record', path: '/worker/harvest', icon: '🌴', desc: 'Catatan Panen TBS' },
    { name: 'Block Management', path: '/worker/blocks', icon: '🗺️', desc: 'Pengelolaan Blok Kebun' },
    { name: 'Transport TBS', path: '/worker/transport', icon: '🚛', desc: 'Transportasi TBS ke PKS' },
    { name: 'Nursery', path: '/worker/nursery', icon: '🌱', desc: 'Pembibitan Sawit' },
    { name: 'Irrigation', path: '/worker/irrigation', icon: '💧', desc: 'Sistem Irigasi' },
    { name: 'Facility Request', path: '/worker/facility', icon: '🏗️', desc: 'Pengajuan Fasilitas' },
    { name: 'Medical Checkup', path: '/worker/medical', icon: '🏥', desc: 'Pemeriksaan Kesehatan' },
  ];

  if (loading) return <div className="min-h-screen flex items-center justify-center"><div className="animate-spin w-8 h-8 border-2 border-green-400 border-t-transparent rounded-full"></div></div>;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center gap-3 mb-8">
          <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-emerald-600 rounded-xl flex items-center justify-center text-2xl">🌴</div>
          <div>
            <h1 className="text-white font-bold text-xl">Admin Perkebunan (Estate)</h1>
            <p className="text-gray-400 text-sm">Dashboard administrasi perkebunan kelapa sawit</p>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-green-400">{stats.workers || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Karyawan</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-emerald-400">{stats.blocks || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Blok Aktif</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-lime-400">{stats.harvest || 0}</div>
            <div className="text-gray-400 text-xs mt-1">Catatan Panen</div>
          </div>
          <div className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-4 text-center">
            <div className="text-2xl font-bold text-green-400">Active</div>
            <div className="text-gray-400 text-xs mt-1">Status</div>
          </div>
        </div>

        <h3 className="text-white font-bold text-sm mb-4">Modul Perkebunan</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {modules.map(m => (
            <button key={m.path} onClick={() => navigate(m.path)} className="bg-gray-800/60 border border-gray-700/50 rounded-xl p-5 text-left hover:border-green-500/50 hover:bg-gray-700/40 transition-all group">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">{m.icon}</span>
                <span className="text-white font-bold text-sm group-hover:text-green-400 transition-colors">{m.name}</span>
              </div>
              <p className="text-gray-400 text-xs">{m.desc}</p>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
