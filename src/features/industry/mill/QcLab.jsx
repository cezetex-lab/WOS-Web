import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase-browser';
import { GlassCard, MetricCard, LoadingSpinner } from '@/lib/design-system';

export default function QcLab() {
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.rpc('get_qc_results', { p_limit: 50 });
      setResults(data?.data || []);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner text="Memuat data QC Lab..." />;

  const pass = results.filter(r => r.result === 'PASS').length;
  const review = results.filter(r => r.result === 'REVIEW').length;
  const reject = results.filter(r => r.result === 'REJECT').length;
  const avgFfa = results.length > 0 ? (results.reduce((s, r) => s + (r.ffa || 0), 0) / results.length).toFixed(2) : 0;
  const avgMoisture = results.length > 0 ? (results.reduce((s, r) => s + (r.moisture || 0), 0) / results.length).toFixed(2) : 0;

  return (
    <div className="max-w-7xl mx-auto px-4 py-6 pb-28">
      <h1 className="text-2xl font-bold text-white mb-2">🧪 QC Laboratory</h1>
      <p className="text-slate-400 text-sm mb-6">Quality Control CPO — Pabrik PKS</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <MetricCard icon="✅" value={pass} label="PASS" trend="Batch" color="green" />
        <MetricCard icon="⚠️" value={review} label="REVIEW" trend="Perlu cek" color="orange" />
        <MetricCard icon="❌" value={reject} label="REJECT" trend="Batch" color="red" />
        <MetricCard icon="📊" value={results.length} label="Total Sample" trend="Hari ini" color="blue" />
      </div>

      <GlassCard title="Standar Kualitas CPO" icon="📋" accent="teal" className="mb-6">
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-center">
          <div className="p-3 bg-slate-800/50 rounded-xl">
            <p className="text-[10px] text-slate-500">FFA</p>
            <p className="text-lg font-bold text-white">{avgFfa}%</p>
            <p className="text-[10px] text-green-400">Max: 5.0%</p>
          </div>
          <div className="p-3 bg-slate-800/50 rounded-xl">
            <p className="text-[10px] text-slate-500">Moisture</p>
            <p className="text-lg font-bold text-white">{avgMoisture}%</p>
            <p className="text-[10px] text-green-400">Max: 0.3%</p>
          </div>
          <div className="p-3 bg-slate-800/50 rounded-xl">
            <p className="text-[10px] text-slate-500">DOBI</p>
            <p className="text-lg font-bold text-white">3.5</p>
            <p className="text-[10px] text-green-400">Min: 3.0</p>
          </div>
          <div className="p-3 bg-slate-800/50 rounded-xl">
            <p className="text-[10px] text-slate-500">Color</p>
            <p className="text-lg font-bold text-white">22</p>
            <p className="text-[10px] text-green-400">Max: 30</p>
          </div>
          <div className="p-3 bg-slate-800/50 rounded-xl">
            <p className="text-[10px] text-slate-500">Dirt</p>
            <p className="text-lg font-bold text-white">0.04%</p>
            <p className="text-[10px] text-green-400">Max: 0.1%</p>
          </div>
        </div>
      </GlassCard>

      <GlassCard title="Hasil QC Hari Ini" icon="📊" accent="blue">
        {results.length === 0 ? (
          <p className="text-slate-400 text-sm">Belum ada sample hari ini</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-slate-500 text-xs border-b border-white/5">
                  <th className="text-left py-2">Batch</th>
                  <th className="text-left py-2">Waktu</th>
                  <th className="text-right py-2">FFA%</th>
                  <th className="text-right py-2">Moisture%</th>
                  <th className="text-right py-2">DOBI</th>
                  <th className="text-right py-2">Color</th>
                  <th className="text-center py-2">Result</th>
                  <th className="text-left py-2">Notes</th>
                </tr>
              </thead>
              <tbody>
                {results.map((r) => (
                  <tr key={r.id} className="border-b border-white/5 hover:bg-white/5">
                    <td className="py-2 text-white font-mono text-xs">{r.batch_id}</td>
                    <td className="py-2 text-slate-300">{r.time}</td>
                    <td className="py-2 text-right text-white">{r.ffa}</td>
                    <td className="py-2 text-right text-white">{r.moisture}</td>
                    <td className="py-2 text-right text-white">{r.dobi}</td>
                    <td className="py-2 text-right text-white">{r.color}</td>
                    <td className="py-2 text-center">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                        r.result === 'PASS' ? 'bg-green-500/20 text-green-400' :
                        r.result === 'REVIEW' ? 'bg-yellow-500/20 text-yellow-400' :
                        'bg-red-500/20 text-red-400'
                      }`}>{r.result}</span>
                    </td>
                    <td className="py-2 text-slate-400 text-xs">{r.notes}</td>
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
