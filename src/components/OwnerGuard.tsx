import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase-browser';

/**
 * OwnerGuard — Protects /owner/* routes.
 * Only the specific authorized owner account can access.
 * Server-side: check_owner_identity() verifies auth_id in system_owner_identity.
 * Client-side: checks Supabase Auth session + role === 'owner'.
 */
export default function OwnerGuard({ children }) {
  const navigate = useNavigate();
  const [checking, setChecking] = useState(true);
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session?.user) {
          if (!cancelled) { navigate('/owner', { replace: true }); setChecking(false); }
          return;
        }
        // Check if user is owner via server-side RPC
        const { data, error } = await supabase.rpc('check_owner_identity');
        if (!cancelled) {
          if (error || data !== true) {
            navigate('/', { replace: true });
          } else {
            setAuthorized(true);
          }
          setChecking(false);
        }
      } catch {
        if (!cancelled) { navigate('/owner', { replace: true }); setChecking(false); }
      }
    })();
    return () => { cancelled = true; };
  }, [navigate]);

  if (checking) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
        <div className="text-white text-center">
          <div className="animate-spin w-8 h-8 border-2 border-amber-400 border-t-transparent rounded-full mx-auto mb-4"></div>
          <p className="text-sm text-gray-400">Verifying owner access...</p>
        </div>
      </div>
    );
  }

  if (!authorized) return null;
  return children;
}
