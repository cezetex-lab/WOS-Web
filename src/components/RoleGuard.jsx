import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';

/**
 * RoleGuard — Wraps protected routes, verifies user role + login entry.
 * Props:
 *   allowedRoles: string[] — e.g. ['admin_pusat','admin_hrd','admin_finance']
 *   entry: string — 'worker' | 'admin' | 'dashboard' — tab login yang dipakai.
 *     Sesi hanya valid bila session.entry === entry (isolasi 3 page:
 *     login via tab lain TIDAK bisa pindah page tanpa login ulang).
 *   redirectTo: string — where to redirect if unauthorized (default: '/')
 *
 * Usage:
 *   <RoleGuard allowedRoles={['admin_pusat']} entry="admin">
 *     <AdminDashboard />
 *   </RoleGuard>
 *
 *   <RoleGuard allowedRoles={['worker','admin_mining','admin_mill','admin_estate']} entry="worker">
 *     <WorkerPages />
 *   </RoleGuard>
 */

export default function RoleGuard({ children, allowedRoles = [], entry = null, redirectTo = '/' }) {
  const navigate = useNavigate();
  const [checking, setChecking] = useState(true);
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        // Check local app session (Supabase Auth JWT tidak dipakai untuk worker —
        // mereka login via RPC token + sessionStorage 'wos_user').
        const s = getSession();
        if (!s?.nrp) {
          if (!cancelled) { navigate('/', { replace: true }); setChecking(false); }
          return;
        }

        // Isolasi entry: sesi yang dibuat dari tab login lain tidak berlaku.
        // Sesi lama (sebelum field entry ada) bersifat legacy → tetap diizinkan
        // agar tidak mengunci user yang sudah login.
        if (entry && s.entry && s.entry !== entry && s.role !== 'owner') {
          if (!cancelled) { navigate(redirectTo, { replace: true }); setChecking(false); }
          return;
        }

        // Role check: owner bypass semua.
        const userRole = s.role;
        const isOwner = s.is_owner === true || userRole === 'owner';
        if (!cancelled) {
          if (isOwner) {
            setAuthorized(true);
          } else if (allowedRoles.length === 0) {
            setAuthorized(true);
          } else if (allowedRoles.includes(userRole)) {
            setAuthorized(true);
          } else {
            // Role tidak diizinkan → kembalikan ke login (isolasi 3 page:
            // tidak auto-lempar ke page lain, user harus login ulang dari tab yang benar).
            navigate(redirectTo, { replace: true });
          }
          setChecking(false);
        }
      } catch (err) {
        console.error('[RoleGuard] Exception during authorization check:', err);
        if (!cancelled) { navigate(redirectTo, { replace: true }); setChecking(false); }
      }
    })();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [navigate, redirectTo, entry, JSON.stringify(allowedRoles)]);

  if (checking) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
        <div className="text-white text-center">
          <div className="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
          <p className="text-sm opacity-70">Verifying access...</p>
        </div>
      </div>
    );
  }

  if (!authorized) return null;
  return children;
}
