import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner } from '@/lib/design-system';

export default function PackingLog() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.rpc('get_packing_log', { p_limit: 50 });
      setLogs(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat data packing..." />;

  const today = logs.filter(l => l.date === new Date().toISOString().slice(0, 10));
  const cpo = today.filter(l => l.product === 'CPO').reduce((s, l) => s + (l.quantity || 0), 0);
  const pk = today.filter(l => l.product === 'PK').reduce((s, l) => s + (l.quantity || 0), 0);
  const dispatched = today.filter(l => l.status === 'DISPATCHED').length;

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">📦 Packing & Loading</h1>
      <p className="text-slate-400 text-sm mb-6">Output tracking — Pabrik PKS</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="🫒" value={`${(cpo / 1000).toFixed(1)}K`} label="CPO Hari Ini" trend="kg" color="teal" />
        <MetricCard icon="🥜" value={`${(pk / 1000).toFixed(1)}K`} label="PK Hari Ini" trend="kg" color="orange" />
        <MetricCard icon="🚛" value={dispatched} label="Dispatched" trend="Truk" color="blue" />
        <MetricCard icon="📊" value={today.length} label="Total Log" trend="Hari ini" color="purple" />
      </div>

      <GlassCard title="Log Packing & Loading" icon="📦" accent="blue">
        {logs.length === 0 ? (
          <p className="text-slate-400 text-sm">Belum ada data packing</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-slate-500 text-xs border-b border-white/5">
                  <th className="text-left py-2">Tanggal</th>
                  <th className="text-left py-2">Waktu</th>
                  <th className="text-left py-2">Produk</th>
                  <th className="text-right py-2">Qty (kg)</th>
                  <th className="text-left py-2">Batch</th>
                  <th className="text-left py-2">Tujuan</th>
                  <th className="text-left py-2">Truk</th>
                  <th className="text-center py-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((l) => (
                  <tr key={l.id} className="border-b border-white/5 hover:bg-white/5">
                    <td className="py-2 text-white">{l.date}</td>
                    <td className="py-2 text-slate-300">{l.time}</td>
                    <td className="py-2">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                        l.product === 'CPO' ? 'bg-teal-500/20 text-teal-400' :
                        l.product === 'PK' ? 'bg-orange-500/20 text-orange-400' :
                        'bg-blue-500/20 text-blue-400'
                      }`}>{l.product}</span>
                    </td>
                    <td className="py-2 text-right text-white font-bold">{l.quantity?.toLocaleString()}</td>
                    <td className="py-2 text-slate-300 font-mono text-xs">{l.batch_id || '-'}</td>
                    <td className="py-2 text-slate-300 text-xs">{l.destination}</td>
                    <td className="py-2 text-slate-300">{l.truck_plate || '-'}</td>
                    <td className="py-2 text-center">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                        l.status === 'DISPATCHED' ? 'bg-green-500/20 text-green-400' :
                        l.status === 'LOADED' ? 'bg-yellow-500/20 text-yellow-400' :
                        'bg-slate-500/20 text-slate-400'
                      }`}>{l.status}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </GlassCard>
    </div>
  );
}
