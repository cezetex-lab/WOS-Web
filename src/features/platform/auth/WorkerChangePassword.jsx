// ============================================================
// WorkerChangePassword.jsx — Worker Ganti Password Sendiri
// RPC: worker_change_password(nrp, old_password, new_password)
// ============================================================

import { getSession } from '@/lib/supabase-browser';
import React, { useState } from 'react';
import { rpc } from '../../../lib/supabase-browser';
import {
  PageLayout, GlassCard, Button, Input
} from '../../../lib/design-system';

export default function WorkerChangePassword() {
  const session = getSession();
  const nrp = session?.nrp || "";
  const nama = session?.nama || nrp;

  const [form, setForm] = useState({ old: '', new: '', confirm: '' });
  const [changing, setChanging] = useState(false);
  const [result, setResult] = useState(null);
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setResult(null);

    // Validation
    if (!form.old) {
      setResult({ type: 'error', text: 'Masukkan password lama' });
      return;
    }
    if (form.new.length < 8) {
      setResult({ type: 'error', text: 'Password baru minimal 8 karakter' });
      return;
    }
    if (form.new === form.old) {
      setResult({ type: 'error', text: 'Password baru harus berbeda dari password lama' });
      return;
    }
    if (form.new !== form.confirm) {
      setResult({ type: 'error', text: 'Konfirmasi password tidak cocok' });
      return;
    }

    setChanging(true);
    try {
      const res = await rpc('worker_change_password', {
        p_nrp: nrp,
        p_old: form.old,
        p_new: form.new,
      });
      if (res?.ok) {
        setResult({ type: 'success', text: `✅ ${res.msg || 'Password berhasil diubah!'}` });
        setForm({ old: '', new: '', confirm: '' });
      } else {
        setResult({ type: 'error', text: res?.msg || 'Gagal mengubah password. Password lama salah.' });
      }
    } catch (e) {
      setResult({ type: 'error', text: 'Error: ' + e.message });
    }
    setChanging(false);
  };

  const toggleShow = () => setShowPassword(!showPassword);
  const inputType = showPassword ? 'text' : 'password';

  return (
    <PageLayout backTo="/worker" title="🔒 Ganti Password" subtitle={`Ubah password untuk ${nama}`}>
      {/* Security Tips */}
      <GlassCard accent="teal" className="mb-6">
        <div className="space-y-2">
          <p className="text-xs text-teal-300 font-semibold">💡 Tips Keamanan Password:</p>
          <ul className="text-[11px] text-slate-400 space-y-1 ml-4 list-disc">
            <li>Minimal 8 karakter</li>
            <li>Gunakan kombinasi huruf besar, kecil, dan angka</li>
            <li>Jangan gunakan nama atau tanggal lahir</li>
            <li>Jangan bagikan password ke orang lain</li>
            <li>Ganti password secara berkala</li>
          </ul>
        </div>
      </GlassCard>

      {/* Change Password Form */}
      <GlassCard accent="blue" title="🔑 Ubah Password" icon="🔐">
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input
            label="Password Lama"
            type={inputType}
            placeholder="Masukkan password saat ini"
            value={form.old}
            onChange={e => setForm({ ...form, old: e.target.value })}
            icon="🔑"
          />
          <Input
            label="Password Baru"
            type={inputType}
            placeholder="Minimal 8 karakter"
            value={form.new}
            onChange={e => setForm({ ...form, new: e.target.value })}
            icon="🔒"
          />
          <Input
            label="Konfirmasi Password Baru"
            type={inputType}
            placeholder="Ulangi password baru"
            value={form.confirm}
            onChange={e => setForm({ ...form, confirm: e.target.value })}
            icon="🔒"
          />

          {/* Show/Hide toggle */}
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={showPassword}
              onChange={toggleShow}
              className="w-4 h-4 rounded border-slate-600 bg-slate-800 text-teal-500 focus:ring-teal-500"
            />
            <span className="text-xs text-slate-400">Tampilkan password</span>
          </label>

          {/* Password strength indicator */}
          {form.new && (
            <div className="space-y-1">
              <div className="flex gap-1">
                {[1, 2, 3, 4].map(i => {
                  const strength = form.new.length >= 12 ? 4 : form.new.length >= 10 ? 3 : form.new.length >= 8 ? 2 : 1;
                  return (
                    <div
                      key={i}
                      className={`h-1 flex-1 rounded-full transition ${
                        i <= strength
                          ? strength <= 1 ? 'bg-red-500'
                            : strength <= 2 ? 'bg-orange-500'
                            : strength <= 3 ? 'bg-yellow-500'
                            : 'bg-green-500'
                          : 'bg-slate-700'
                      }`}
                    />
                  );
                })}
              </div>
              <p className="text-[10px] text-slate-500">
                {form.new.length < 8 ? 'Lemah' : form.new.length < 10 ? 'Sedang' : form.new.length < 12 ? 'Kuat' : 'Sangat Kuat'}
              </p>
            </div>
          )}

          <Button
            type="submit"
            color="teal"
            disabled={changing || !form.old || !form.new || !form.confirm}
          >
            {changing ? '⏳ Mengubah...' : '🔒 Ubah Password'}
          </Button>
        </form>

        {result && (
          <div className={`mt-4 p-3 rounded-xl text-sm font-semibold ${
            result.type === 'success'
              ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
              : 'bg-red-500/20 text-red-300 border border-red-500/30'
          }`}>
            {result.text}
          </div>
        )}
      </GlassCard>

      {/* Session info */}
      <GlassCard accent="slate" className="mt-4">
        <div className="space-y-2 text-xs">
          <div className="flex justify-between">
            <span className="text-slate-400">NRP</span>
            <span className="text-white font-semibold">{nrp}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-400">Terakhir login</span>
            <span className="text-white font-semibold">{new Date().toLocaleString('id-ID')}</span>
          </div>
        </div>
      </GlassCard>
    </PageLayout>
  );
}
