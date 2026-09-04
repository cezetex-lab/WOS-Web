import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';

/**
 * Hook: checks if current user's admin role is allowed for this path.
 * If not, redirects to /admin.
 * 
 * Usage in any admin page:
 *   useAdminAuth(['admin_pusat', 'admin_hrd']);
 */
export default function useAdminAuth(allowedRoles = []) {
  const navigate = useNavigate();
  const session = getSession();
  const role = session?.role || '';

  useEffect(() => {
    if (allowedRoles.length === 0) return;
    if (role === 'owner' || role === 'admin_pusat') return; // owner & pusat bypass
    if (!allowedRoles.includes(role)) {
      console.warn(`[AdminAuth] Role "${role}" not in [${allowedRoles}]. Redirecting.`);
      navigate('/admin', { replace: true });
    }
  }, [role, navigate]);

  return { role, isAllowed: allowedRoles.length === 0 || role === 'owner' || role === 'admin_pusat' || allowedRoles.includes(role) };
}
