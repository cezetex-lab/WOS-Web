import { useState } from 'react';
import { rpc } from '@/lib/supabase-browser';

export default function LogoUploader({ onSaved }) {
  const [logoUrl, setLogoUrl] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [tagline, setTagline] = useState('');
  const [primaryColor, setPrimaryColor] = useState('#3b82f6');
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  async function handleSave() {
    setSaving(true);
    setMsg('');
    try {
      await rpc('update_branding', {
        p_logo_url: logoUrl || null,
        p_company_name: companyName || null,
        p_tagline: tagline || null,
        p_primary_color: primaryColor || null,
      });
      setMsg('Branding tersimpan!');
      if (onSaved) onSaved();
    } catch (e) {
      setMsg('Gagal: ' + e.message);
    }
    setSaving(false);
  }

  return (
    <div className="space-y-4">
      <h3 className="text-white font-semibold">Logo & Branding</h3>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Logo URL (upload ke imgbb.com, paste URL)</label>
        <input type="url" value={logoUrl} onChange={e => setLogoUrl(e.target.value)} placeholder="https://i.ibb.co/..." className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm" />
        {logoUrl && <img src={logoUrl} alt="Preview" className="mt-2 h-16 rounded" onError={e => e.target.style.display='none'} />}
      </div>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Nama Perusahaan</label>
        <input type="text" value={companyName} onChange={e => setCompanyName(e.target.value)} className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm" />
      </div>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Tagline</label>
        <input type="text" value={tagline} onChange={e => setTagline(e.target.value)} className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm" />
      </div>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Warna Primer</label>
        <div className="flex items-center gap-3">
          <input type="color" value={primaryColor} onChange={e => setPrimaryColor(e.target.value)} className="w-10 h-10 rounded cursor-pointer" />
          <span className="text-gray-400 text-sm">{primaryColor}</span>
        </div>
      </div>
      <button onClick={handleSave} disabled={saving} className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50">{saving ? 'Menyimpan...' : 'Simpan Branding'}</button>
      {msg && <p className="text-sm text-green-400">{msg}</p>}
    </div>
  );
}
