import { useState } from "react";

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

async function callReset(action, data) {
  const res = await fetch("${SUPABASE_URL}/functions/v1/password-reset", {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
    body: JSON.stringify({ action, ...data }),
  });
  return res.json();
}

export default function PasswordReset() {
  const [step, setStep] = useState(1); // 1=request, 2=verify, 3=reset, 4=done
  const [email, setEmail] = useState("");
  const [token, setToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleRequest(e) {
    e.preventDefault();
    setLoading(true);
    setMsg("");
    const res = await callReset("request", { email });
    setMsg(res.msg || "Terjadi kesalahan.");
    if (res.ok) setStep(2);
    setLoading(false);
  }

  async function handleVerify(e) {
    e.preventDefault();
    setLoading(true);
    setMsg("");
    const res = await callReset("verify", { email, token });
    setMsg(res.msg || "Token tidak valid.");
    if (res.ok) setStep(3);
    setLoading(false);
  }

  async function handleReset(e) {
    e.preventDefault();
    setLoading(true);
    setMsg("");
    if (newPassword.length < 8) {
      setMsg("Password minimal 8 karakter.");
      setLoading(false);
      return;
    }
    const res = await callReset("reset", { email, token, new_password: newPassword });
    setMsg(res.msg || "Gagal.");
    if (res.ok) setStep(4);
    setLoading(false);
  }

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <div className="bg-gray-800 rounded-xl p-8 max-w-md w-full shadow-xl">
        <h1 className="text-2xl font-bold text-white mb-2">Reset Password</h1>
        <p className="text-gray-400 text-sm mb-6">Masukkan email Anda untuk reset password.</p>

        {step === 1 && (
          <form onSubmit={handleRequest} className="space-y-4">
            <input type="email" value={email} onChange={e => setEmail(e.target.value)}
              placeholder="Email" required className="w-full px-4 py-3 bg-gray-700 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none" />
            <button type="submit" disabled={loading}
              className="w-full py-3 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 disabled:opacity-50">
              {loading ? "Mengirim..." : "Kirim Kode Reset"}
            </button>
          </form>
        )}

        {step === 2 && (
          <form onSubmit={handleVerify} className="space-y-4">
            <p className="text-green-400 text-sm">Kode 6 digit telah dikirim ke email Anda.</p>
            <input type="text" value={token} onChange={e => setToken(e.target.value)}
              placeholder="Masukkan kode 6 digit" maxLength={6} required
              className="w-full px-4 py-3 bg-gray-700 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none text-center text-2xl tracking-widest" />
            <button type="submit" disabled={loading}
              className="w-full py-3 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 disabled:opacity-50">
              {loading ? "Verifikasi..." : "Verifikasi Kode"}
            </button>
          </form>
        )}

        {step === 3 && (
          <form onSubmit={handleReset} className="space-y-4">
            <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)}
              placeholder="Password baru (min 8 karakter)" required minLength={8}
              className="w-full px-4 py-3 bg-gray-700 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none" />
            <button type="submit" disabled={loading}
              className="w-full py-3 bg-green-600 text-white rounded-lg font-semibold hover:bg-green-700 disabled:opacity-50">
              {loading ? "Mengubah..." : "Ubah Password"}
            </button>
          </form>
        )}

        {step === 4 && (
          <div className="text-center space-y-4">
            <div className="text-4xl">✅</div>
            <p className="text-green-400 font-semibold">Password berhasil diubah!</p>
            <a href="/" className="inline-block px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              Kembali ke Login
            </a>
          </div>
        )}

        {msg && <p className="mt-4 text-sm text-center text-yellow-400">{msg}</p>}

        <div className="mt-6 text-center">
          <a href="/" className="text-gray-400 text-sm hover:text-white">← Kembali ke Login</a>
        </div>
      </div>
    </div>
  );
}
