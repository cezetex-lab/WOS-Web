import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';

/**
 * Hook: checks if current user's admin role is allowed for this path.
 * If not, redirects to /admin.
 *
 * Usage in any admin page:
 *   useAdminAuth(['admin_pusat', 'admin_hrd']);
 */
export default function useAdminAuth(allowedRoles: string[] = []) {
  const navigate = useNavigate();
  const session = getSession();
  const role = session?.role || '';

  // OPS-12: saat deep-link/refresh, sesi di sessionStorage belum tertulis → role='' sementara.
  // Jangan redirect sebelum role termuat (atau fail-safe habis) agar user authorized tidak di-bounce.
  const [roleSettled, setRoleSettled] = useState(false);

  useEffect(() => {
    if (role) {
      setRoleSettled(true);
      return;
    }
    // Fail-safe 8 dtk (bukan 3) — token refresh bisa 5,6 dtk saat jaringan lambat; jangan bounce user authorized.
    const t = setTimeout(() => setRoleSettled(true), 8000);
    return () => clearTimeout(t);
  }, [role]);

  useEffect(() => {
    if (allowedRoles.length === 0) return;
    if (!roleSettled) return; // OPS-12: tunggu role termuat / fail-safe sebelum memutuskan redirect
    if (role === 'owner' || role === 'admin_pusat') return; // owner & pusat bypass
    if (!allowedRoles.includes(role)) {
      navigate('/admin', { replace: true });
    }
  }, [role, roleSettled, navigate, allowedRoles]);

  return { role, isAllowed: allowedRoles.length === 0 || role === 'owner' || role === 'admin_pusat' || allowedRoles.includes(role) };
}
