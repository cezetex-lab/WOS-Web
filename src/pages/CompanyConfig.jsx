import { useState, useEffect } from 'react';
import { rpc, clearSession } from '@/lib/supabase-browser';
import { useNavigate } from 'react-router-dom';

export default function CompanyConfig() {
  const navigate = useNavigate();
  const [configs, setConfigs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [expandedCat, setExpandedCat] = useState(null);
  const [editing, setEditing] = useState(null);
  const [editValue, setEditValue] = useState('');
  const [msg, setMsg] = useState('');
  const [search, setSearch] = useState('');

  useEffect(() => { loadConfig(); }, []);

  async function loadConfig() {
    setLoading(true);
    try {
      const res = await rpc('get_company_config');
      setConfigs(Array.isArray(res) ? res : []);
    } catch {}
    setLoading(false);
  }

  async function saveConfig() {
    if (!editing) return;
    setMsg('');
    try {
      let parsed;
      try { parsed = JSON.parse(editValue); } catch { parsed = { value: editValue }; }
      const res = await rpc('update_company_config', { p_config_id: editing.id, p_value: parsed });
      if (res?.ok) {
        setMsg('✅ ' + res.msg);
        setEditing(null);
        loadConfig();
      } else {
        setMsg('❌ ' + (res?.msg || 'Gagal'));
      }
    } catch (e) { setMsg('❌ ' + e.message); }
  }

  // Group by category
  const grouped = {};
  configs.forEach(c => {
    const cat = c.category_id;
    if (!grouped[cat]) grouped[cat] = { name: c.category_name, icon: c.category_icon, items: [] };
    grouped[cat].items.push(c);
  });

  const filtered = search
    ? configs.filter(c => c.label.toLowerCase().includes(search.toLowerCase()) || c.config_key.toLowerCase().includes(search.toLowerCase()))
    : null;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <header className="bg-gray-800/80 border-b border-gray-700/50 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-xl flex items-center justify-center"><span className="text-xl">⚙️</span></div>
            <div><h1 className="text-white font-bold text-lg">Company Configuration</h1><p className="text-gray-400 text-xs">Konstanta bisnis — adjust sesuai kebutuhan perusahaan</p></div>
          </div>
          <div className="flex items-center gap-3">
            <button onClick={() => navigate('/owner/dashboard')} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg hover:bg-gray-600 text-sm">← Back</button>
            <button onClick={() => { clearSession(); navigate('/owner'); }} className="px-4 py-2 bg-gray-700 text-gray-300 rounded-lg hover:bg-gray-600 text-sm">Logout</button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto p-6">
        {msg && <div className={`p-3 rounded-lg mb-4 text-sm ${msg.startsWith('✅') ? 'bg-green-900/50 text-green-300' : 'bg-red-900/50 text-red-300'}`}>{msg}</div>}

        {/* Search */}
        <div className="mb-6">
          <input type="text" placeholder="Cari config..." value={search} onChange={e => setSearch(e.target.value)}
            className="w-full md:w-96 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white text-sm focus:outline-none focus:border-cyan-500" />
        </div>

        {loading ? <div className="text-center py-20 text-gray-400">Loading...</div> : (
          <>
            {search && filtered ? (
              <div className="space-y-2">
                {filtered.length === 0 && <div className="text-gray-400 text-center py-10">Tidak ditemukan</div>}
                {filtered.map(c => (
                  <ConfigItem key={c.id} config={c} onEdit={() => { setEditing(c); setEditValue(JSON.stringify(c.config_value)); }} />
                ))}
              </div>
            ) : (
              <div className="space-y-4">
                {Object.entries(grouped).length === 0 && <div className="text-gray-400 text-center py-10">Tidak ada config</div>}
                {Object.entries(grouped).map(([catId, cat]) => (
                  <div key={catId} className="bg-gray-800/60 border border-gray-700/50 rounded-xl overflow-hidden">
                    <button onClick={() => setExpandedCat(expandedCat === catId ? null : catId)}
                      className="w-full flex items-center justify-between px-5 py-4 hover:bg-gray-700/30 transition-colors">
                      <div className="flex items-center gap-3">
                        <span className="text-xl">{cat.icon}</span>
                        <div className="text-left">
                          <div className="text-white font-bold text-sm">{cat.name}</div>
                          <div className="text-gray-500 text-xs">{cat.items.length} konfigurasi</div>
                        </div>
                      </div>
                      <span className={`text-gray-400 text-lg transition-transform ${expandedCat === catId ? 'rotate-180' : ''}`}>▾</span>
                    </button>
                    {expandedCat === catId && (
                      <div className="border-t border-gray-700/50 p-4 space-y-2">
                        {cat.items.map(c => (
                          <ConfigItem key={c.id} config={c} onEdit={() => { setEditing(c); setEditValue(JSON.stringify(c.config_value)); }} />
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>

      {/* Edit Modal */}
      {editing && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setEditing(null)}>
          <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-full max-w-lg" onClick={e => e.stopPropagation()}>
            <h3 className="text-white font-bold mb-1">{editing.label}</h3>
            <p className="text-gray-400 text-xs mb-4">{editing.description}</p>
            <div className="mb-2 text-xs text-gray-500">
              Key: <code className="text-cyan-400">{editing.config_key}</code> | Type: <code className="text-cyan-400">{editing.data_type}</code>
            </div>
            {editing.min_value !== null && editing.max_value !== null && (
              <div className="mb-2 text-xs text-gray-500">
                Range: <code className="text-amber-400">{editing.min_value} — {editing.max_value}</code>
              </div>
            )}
            <label className="text-gray-400 text-xs">Value (JSON)</label>
            <textarea value={editValue} onChange={e => setEditValue(e.target.value)} rows={6}
              className="w-full mt-1 px-3 py-2 bg-gray-900 border border-gray-600 rounded-lg text-green-400 text-sm font-mono focus:outline-none focus:border-cyan-500" />
            <div className="flex gap-2 mt-4">
              <button onClick={() => setEditing(null)} className="flex-1 px-4 py-2 bg-gray-700 text-gray-300 rounded-lg text-sm">Batal</button>
              <button onClick={saveConfig} className="flex-1 px-4 py-2 bg-cyan-600 text-white rounded-lg text-sm font-bold hover:bg-cyan-500">Simpan</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ConfigItem({ config, onEdit }) {
  const displayValue = config.config_value?.value !== undefined
    ? JSON.stringify(config.config_value.value)
    : JSON.stringify(config.config_value);

  return (
    <div className="flex items-center justify-between bg-gray-900/60 rounded-lg px-4 py-3 hover:bg-gray-900/80 transition-colors">
      <div className="flex-1 min-w-0">
        <div className="text-gray-200 text-sm font-medium">{config.label}</div>
        <div className="text-gray-500 text-xs truncate">{config.description}</div>
      </div>
      <div className="flex items-center gap-3 ml-4">
        <code className="text-xs text-cyan-400 bg-gray-800 px-2 py-1 rounded max-w-[200px] truncate">{displayValue}</code>
        <button onClick={onEdit} className="px-3 py-1 rounded text-xs font-medium bg-gray-700 text-gray-300 hover:bg-gray-600 whitespace-nowrap">Edit</button>
      </div>
    </div>
  );
}
