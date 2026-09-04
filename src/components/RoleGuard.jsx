import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase-browser';

/**
 * RoleGuard — Wraps protected routes, verifies user role.
 * Props:
 *   allowedRoles: string[] — e.g. ['admin_pusat','admin_hrd','admin_finance']
 *   redirectTo: string — where to redirect if unauthorized (default: '/')
 *
 * Usage:
 *   <RoleGuard allowedRoles={['admin_pusat']}>
 *     <AdminDashboard />
 *   </RoleGuard>
 *
 *   <RoleGuard allowedRoles={['worker','admin_mining','admin_mill','admin_estate']}>
 *     <WorkerPages />
 *   </RoleGuard>
 */
export default function RoleGuard({ children, allowedRoles = [], redirectTo = '/' }) {
  const navigate = useNavigate();
  const [checking, setChecking] = useState(true);
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        console.log('[RoleGuard] Checking authorization for roles:', allowedRoles);
        
        // Check Supabase Auth session
        const { data: { session } } = await supabase.auth.getSession();
        console.log('[RoleGuard] Supabase session:', session ? 'exists' : 'none');
        
        if (!session?.user) {
          console.log('[RoleGuard] No Supabase session, redirecting to login');
          if (!cancelled) { navigate('/', { replace: true }); setChecking(false); }
          return;
        }

        // Get user context via RPC
        console.log('[RoleGuard] Calling get_current_user_context RPC...');
        const { data: ctx, error } = await supabase.rpc('get_current_user_context');
        console.log('[RoleGuard] RPC result:', { ctx, error });
        
        if (!cancelled) {
          if (error || !ctx) {
            console.error('[RoleGuard] RPC failed or returned null:', error);
            navigate(redirectTo, { replace: true });
          } else {
            const userRole = ctx.role;
            const isOwner = ctx.is_owner === true;
            console.log('[RoleGuard] User context:', { userRole, isOwner, allowedRoles });

            // Owner bypasses all role checks
            if (isOwner) {
              console.log('[RoleGuard] Owner detected, authorizing access');
              setAuthorized(true);
            } else if (allowedRoles.length === 0) {
              // No role restriction — any authenticated user can access
              console.log('[RoleGuard] No role restrictions, authorizing access');
              setAuthorized(true);
            } else if (allowedRoles.includes(userRole)) {
              console.log('[RoleGuard] User role matches allowed roles, authorizing access');
              setAuthorized(true);
            } else {
              // Unauthorized — redirect based on role
              console.log('[RoleGuard] User role not in allowed roles, redirecting');
              if (isOwner) {
                // Owner should never reach here (bypass above), but just in case
                setAuthorized(true);
              } else if (userRole === 'worker') {
                navigate('/worker', { replace: true });
              } else if (userRole?.startsWith('admin_')) {
                navigate('/admin', { replace: true });
              } else {
                navigate(redirectTo, { replace: true });
              }
            }
          }
          setChecking(false);
        }
      } catch (err) {
        console.error('[RoleGuard] Exception during authorization check:', err);
        if (!cancelled) { navigate(redirectTo, { replace: true }); setChecking(false); }
      }
    })();
    return () => { cancelled = true; };
  }, [navigate, redirectTo, JSON.stringify(allowedRoles)]);

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
