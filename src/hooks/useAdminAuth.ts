import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';

/**
 * Hook: checks if current user's admin role/permission is allowed for this path.
 * If not, redirects to /admin.
 *
 * Usage in any admin page (mode array — LEGACY, tetap didukung):
 *   useAdminAuth(['admin_pusat', 'admin_hrd']);
 *
 * 270C — dual-accept (ADDITIVE, non-breaking):
 *   useAdminAuth({ permission: 'employee.view_all' });
 *
 * Mode permission HANYA aktif bila sesi punya `permissions` (fetch sukses di
 * initSession). Sesi lama / fetch gagal → `permissions === undefined` →
 * fallback: mode permission dianggap longgar (fail-open sementara 270C–D),
 * mode array tetap dipakai sebagai defense-in-depth.
 */
export default function useAdminAuth(arg: string[] | { permission: string } = []) {
  const navigate = useNavigate();
  const session = getSession();
  const role = session?.role || '';
  const permissions = session?.permissions;

  const isArrayMode = Array.isArray(arg);
  const allowedRoles = isArrayMode ? arg : [];
  const permission = isArrayMode ? undefined : arg.permission;

  // 270C: stabilkan deps — argumen array/objek literal dibuat baru tiap render,
  // jadi effect memakai key string (hanya berubah bila ISI-nya berubah).
  const allowedRolesKey = allowedRoles.join('|');
  const permissionsKey = permissions ? permissions.join('|') : '__undef__';

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
    if (!roleSettled) return; // OPS-12: tunggu role termuat / fail-safe sebelum memutuskan redirect
    if (role === 'owner' || role === 'admin_pusat') return; // owner & pusat bypass
    if (permission && permissions !== undefined) {
      // 270C: permissions ADA → pakai permissions, fail-closed ([] = ditolak).
      if (!permissions.includes(permission)) navigate('/admin', { replace: true });
      return;
    }
    // Mode permission tanpa `permissions` (sesi lama/fetch gagal) → fallback longgar.
    if (!isArrayMode) return;
    if (allowedRoles.length === 0) return; // legacy: izinkan
    if (!allowedRoles.includes(role)) {
      navigate('/admin', { replace: true });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- deps distabilkan via *Key (lihat di atas)
  }, [role, roleSettled, navigate, permission, allowedRolesKey, permissionsKey]);

  const isAllowed =
    role === 'owner' || role === 'admin_pusat'
      ? true
      : permission && permissions !== undefined
        ? permissions.includes(permission)
        : allowedRoles.length === 0 || allowedRoles.includes(role);

  return { role, isAllowed };
}
