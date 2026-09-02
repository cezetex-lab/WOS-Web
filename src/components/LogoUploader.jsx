import { useState, useEffect } from 'react';
import { rpc } from '@/lib/supabase-browser';

export default function LogoUploader({ onUpdated }) {
  const [branding, setBranding] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [form, setForm] = useState({
    company_name: '',
    tagline: '',
    logo_url: '',
    primary_color: '#3b82f6',
  });

  useEffect(() => { loadBranding(); }, []);

  async function loadBranding() {
    setLoading(true);
    try {
      const d = await rpc('get_branding', {});
      if (d && d.company_name) {
        setBranding(d);
        setForm({
          company_name: d.company_name || '',
          tagline: d.tagline || '',
          logo_url: d.logo_url || '',
          primary_color: d.primary_color || '#3b82f6',
        });
      }
    } catch {}
    setLoading(false);
  }

  async function handleSave() {
    setSaving(true);
    setMsg('');
    try {
      const d = await rpc('update_branding', {
        p_company_name: form.company_name || null,
        p_tagline: form.tagline || null,
        p_logo_url: form.logo_url || null,
        p_primary_color: form.primary_color || null,
      });
      if (d?.ok) {
        setMsg('✅ Logo & branding updated!');
        loadBranding();
        if (onUpdated) onUpdated();
      } else {
        setMsg('❌ ' + (d?.msg || 'Gagal update'));
      }
    } catch (e) {
      setMsg('❌ Error: ' + e.message);
    }
    setSaving(false);
  }

  if (loading) return <p style={{ color: '#999', padding: 16 }}>Loading...</p>;

  return (
    <div style={{ padding: 16, maxWidth: 500 }}>
      <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 12 }}>🎨 Logo & Branding</h3>
      <p style={{ fontSize: 12, color: '#666', marginBottom: 16 }}>
        Ganti logo, nama perusahaan, dan warna. Hanya Owner yang bisa mengubah.
      </p>

      {/* Current Logo Preview */}
      <div style={{ marginBottom: 16, textAlign: 'center' }}>
        <div style={{ fontSize: 11, color: '#999', marginBottom: 4 }}>Logo Saat Ini</div>
        {form.logo_url ? (
          <img src={form.logo_url} alt="Logo" style={{ maxWidth: 120, maxHeight: 80, objectFit: 'contain', borderRadius: 8, border: '1px solid #e2e8f0' }} />
        ) : (
          <div style={{ width: 120, height: 80, margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 8, border: '2px dashed #ddd', fontSize: 12, color: '#999' }}>
            Belum ada logo
          </div>
        )}
      </div>

      {/* Form */}
      <div style={{ display: 'grid', gap: 12 }}>
        <div>
          <label style={label}>Nama Perusahaan</label>
          <input value={form.company_name} onChange={e => setForm({...form, company_name: e.target.value})} style={input} placeholder="insightWOS" />
        </div>
        <div>
          <label style={label}>Tagline</label>
          <input value={form.tagline} onChange={e => setForm({...form, tagline: e.target.value})} style={input} placeholder="Workforce Intelligence Platform" />
        </div>
        <div>
          <label style={label}>Logo URL</label>
          <input value={form.logo_url} onChange={e => setForm({...form, logo_url: e.target.value})} style={input} placeholder="https://example.com/logo.png" />
          <p style={{ fontSize: 10, color: '#999', marginTop: 4 }}>
            Upload gambar ke <a href="https://imgbb.com" target="_blank" rel="noreferrer">imgbb.com</a> atau Supabase Storage, lalu paste URL-nya
          </p>
        </div>
        <div>
          <label style={label}>Warna Primer</label>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input type="color" value={form.primary_color} onChange={e => setForm({...form, primary_color: e.target.value})} style={{ width: 40, height: 32, cursor: 'pointer' }} />
            <input value={form.primary_color} onChange={e => setForm({...form, primary_color: e.target.value})} style={{ ...input, width: 120 }} />
          </div>
        </div>
      </div>

      {msg && <p style={{ fontSize: 12, marginTop: 8, padding: 8, borderRadius: 6, background: msg.startsWith('✅') ? '#f0fdf4' : '#fef2f2' }}>{msg}</p>}

      <button onClick={handleSave} disabled={saving} style={{ marginTop: 16, padding: '10px 24px', borderRadius: 8, background: form.primary_color || '#3b82f6', color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 13 }}>
        {saving ? 'Menyimpan...' : '💾 Simpan Branding'}
      </button>
    </div>
  );
}

const label = { display: 'block', fontSize: 11, fontWeight: 600, color: '#555', marginBottom: 4 };
const input = { width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #ddd', fontSize: 13 };
