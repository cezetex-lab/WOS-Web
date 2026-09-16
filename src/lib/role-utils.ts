/**
 * Role helpers — single source of truth for admin role detection (§0.5 G2).
 *
 * Actual DB roles: admin_pusat, admin_hrd, admin_finance, admin_camp,
 * admin_mining, admin_mill, admin_estate. There is NO plain 'admin' role
 * in the database, but we keep `role === 'admin'` as a safety fallback
 * for any future role consolidation.
 */

/** Returns true if the role is an admin role (admin_* or 'admin'). */
export function isAdminRole(role?: string | null): boolean {
  if (!role) return false;
  return role.startsWith('admin_') || role === 'admin';
}
