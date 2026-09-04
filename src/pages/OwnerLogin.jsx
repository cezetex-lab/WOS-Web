import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase-browser';
import { rpc } from '@/lib/supabase-browser';

export default function OwnerLogin() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('owner@insightwos.com');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) throw new Error('Email atau password salah');

      const result = await rpc('owner_login', { p_email: email });
      if (result && result.ok === false) {
        throw new Error(result.msg || 'Akses ditolak');
      }

      setSession({
        nrp: 'OWNER001',
        nama: 'System Owner',
        role: 'owner',
        role_level: 5,
        is_owner: true,
        email: email,
      });

      navigate('/owner/dashboard');
    } catch (err) {
      setError(err.message || 'Login gagal');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <div className="w-full max-w-md p-8 bg-gray-800/80 backdrop-blur-xl rounded-2xl border border-gray-700/50 shadow-2xl">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-gradient-to-br from-amber-500 to-orange-600 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-amber-500/25">
            <span className="text-3xl">&#x1f510;</span>
          </div>
          <h1 className="text-2xl font-bold text-white">System Owner</h1>
          <p className="text-gray-400 text-sm mt-2">Platform Management Console</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm">
              {error}
            </div>
          )}
          <div>
            <label className="block text-gray-400 text-sm mb-2">Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} className="w-full px-4 py-3 bg-gray-700/50 border border-gray-600/50 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-amber-500/50" required />
          </div>
          <div>
            <label className="block text-gray-400 text-sm mb-2">Password</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} className="w-full px-4 py-3 bg-gray-700/50 border border-gray-600/50 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-amber-500/50" placeholder="Masukkan password" required />
          </div>
          <button type="submit" disabled={loading} className="w-full py-3 bg-gradient-to-r from-amber-500 to-orange-600 text-white font-semibold rounded-lg hover:from-amber-600 hover:to-orange-700 transition-all disabled:opacity-50">
            {loading ? 'Memverifikasi...' : 'Masuk sebagai Owner'}
          </button>
        </form>

        <div className="mt-6 text-center">
          <a href="/" className="text-gray-500 text-sm hover:text-gray-400 transition-colors">
            Kembali ke login umum
          </a>
        </div>
      </div>
    </div>
  );
}
