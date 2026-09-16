import React, { useState, useEffect } from 'react';
import { rpc, isRpcError } from '@/lib/supabase-browser';

interface LogoUploaderProps {
  onSaved?: () => void;
}

interface BrandingResult {
  company_name?: string;
  tagline?: string;
  logo_url?: string;
  primary_color?: string;
}

interface UpdateResult {
  ok?: boolean;
  msg?: string;
}

export default function LogoUploader({ onSaved }: LogoUploaderProps) {
  const [logoUrl, setLogoUrl] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [tagline, setTagline] = useState('');
  const [primaryColor, setPrimaryColor] = useState('#3b82f6');
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [loaded, setLoaded] = useState(false);

  // Muat nilai branding saat ini agar Owner melihat kondisi eksisting
  // (get_branding public; update tetap owner-only via RPC update_branding).
  useEffect(() => {
    rpc<BrandingResult>('get_branding', {}).then(d => {
      if (!isRpcError(d)) {
        setCompanyName(d.company_name || '');
        setTagline(d.tagline || '');
        setLogoUrl(d.logo_url || '');
        if (d.primary_color) setPrimaryColor(d.primary_color);
      }
    }).catch(() => {}).finally(() => setLoaded(true));
  }, []);

  async function handleSave() {
    setSaving(true);
    setMsg('');
    try {
      const res = await rpc<UpdateResult>('update_branding', {
        p_logo_url: logoUrl || null,
        p_company_name: companyName || null,
        p_tagline: tagline || null,
        p_primary_color: primaryColor || null,
      });
      if (res?.ok === false) setMsg('❌ ' + (res.msg || 'Gagal'));
      else { setMsg('✅ Branding tersimpan!'); if (onSaved) onSaved(); }
    } catch (e: unknown) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      setMsg('❌ Gagal: ' + errorMsg);
    }
    setSaving(false);
  }

  return (
    <div className="space-y-4">
      <h3 className="text-white font-semibold">🎨 Logo &amp; Branding</h3>
      <p className="text-gray-500 text-xs">Nama &amp; logo tampil di halaman login, drawer, dan header. Sumber: tabel <code className="text-cyan-400">branding</code> (bukan hardcode JS).</p>
      {!loaded && <p className="text-gray-500 text-xs">Memuat branding saat ini...</p>}
      <div>
        <label className="block text-gray-400 text-sm mb-1">Logo URL (upload ke imgbb.com, paste URL)</label>
        <input type="url" value={logoUrl} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setLogoUrl(e.target.value)} placeholder="https://i.ibb.co/..." className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm" />
        {logoUrl && <img src={logoUrl} alt="Preview" className="mt-2 h-16 rounded" onError={(e: React.SyntheticEvent<HTMLImageElement, Event>) => { (e.target as HTMLImageElement).style.display = 'none'; }} />}
      </div>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Nama Perusahaan</label>
        <input type="text" value={companyName} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setCompanyName(e.target.value)} placeholder="insightWIP" className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm" />
      </div>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Tagline</label>
        <input type="text" value={tagline} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setTagline(e.target.value)} className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm" />
      </div>
      <div>
        <label className="block text-gray-400 text-sm mb-1">Warna Primer</label>
        <div className="flex items-center gap-3">
          <input type="color" value={primaryColor} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPrimaryColor(e.target.value)} className="w-10 h-10 rounded cursor-pointer" />
          <span className="text-gray-400 text-sm">{primaryColor}</span>
        </div>
      </div>
      <button onClick={handleSave} disabled={saving || !loaded} className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50">{saving ? 'Menyimpan...' : 'Simpan Branding'}</button>
      {msg && <p className={`text-sm ${msg.startsWith('✅') ? 'text-green-400' : 'text-red-400'}`}>{msg}</p>}
    </div>
  );
}
