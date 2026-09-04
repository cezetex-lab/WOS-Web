import { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { getSession, initSession, supabase } from '@/lib/supabase-browser';

const PUBLIC_ROUTES = ['/', '/owner', '/owner/dashboard'];

export default function SessionGuard({ children }) {
  const navigate = useNavigate();
  const location = useLocation();
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    // P2 FIX: Initialize session from backend RPC (not sessionStorage)
    initSession().then(async (session) => {
      // Register session for concurrent session control
      if (session) {
        try {
          const sid = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2);
          await supabase.rpc("register_session", { p_session_id: sid, p_ip: "", p_ua: navigator.userAgent });
        } catch(e) { /* non-critical */ }
      }
      if (PUBLIC_ROUTES.includes(location.pathname)) {
        setChecking(false);
        return;
      }
      if (!session?.nrp) {
        navigate('/', { replace: true });
      }
      setChecking(false);
    }).catch(() => {
      if (!PUBLIC_ROUTES.includes(location.pathname)) {
        navigate('/', { replace: true });
      }
      setChecking(false);
    });
  }, [navigate, location.pathname]);

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
