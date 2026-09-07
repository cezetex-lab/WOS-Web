import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getSession, initSession, supabase } from '@/lib/supabase-browser';

const PUBLIC_ROUTES = ['/', '/owner', '/owner/dashboard'];

export default function SessionGuard({ children }) {
  const navigate = useNavigate();
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    // P2 FIX: Initialize session from backend RPC (not sessionStorage)
    // RUN ONCE per mount: efek ini sebelumnya punya deps [navigate,
    // location.pathname] sehingga initSession + register_session dieksekusi
    // ulang (dengan session_id UUID BARU) di setiap perpindahan halaman —
    // men-spam tabel active_sessions.
    let cancelled = false;
    initSession().then(async (session) => {
      if (cancelled) return;
      // Register session for concurrent session control — satu session_id
      // stabil per tab browser agar upsert, bukan insert baru tiap navigasi.
      if (session) {
        try {
          let sid = sessionStorage.getItem('wos_session_id');
          if (!sid) {
            sid = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2);
            sessionStorage.setItem('wos_session_id', sid);
          }
          await supabase.rpc("register_session", { p_session_id: sid, p_ip: "", p_ua: navigator.userAgent });
        } catch(e) { /* non-critical */ }
      }
      const path = window.location.pathname;
      if (PUBLIC_ROUTES.includes(path)) {
        setChecking(false);
        return;
      }
      if (!session?.nrp) {
        navigate('/', { replace: true });
      }
      setChecking(false);
    }).catch(() => {
      if (!PUBLIC_ROUTES.includes(window.location.pathname)) {
        navigate('/', { replace: true });
      }
      setChecking(false);
    });
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (checking) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
        <div className="text-white text-center">
          <div className="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
          <p className="text-sm opacity-70">Memverifikasi sesi...</p>
        </div>
      </div>
    );
  }
  return children;
}
