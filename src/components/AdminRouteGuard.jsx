import { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';

/**
 * AdminRouteGuard — redirects if user role doesn't match allowed roles for this path.
 * Used inside admin sub-pages to enforce least-privilege access.
 */

const ROLE_ACCESS = {

  '/admin/analytics': ["admin_pusat"],

  '/admin/approval-workflow': ["admin_pusat", "admin_hrd"],

  '/admin/approvals': ["admin_pusat", "admin_hrd"],

  '/admin/assets': ["admin_pusat", "admin_produksi"],

  '/admin/audit': ["admin_pusat", "admin_finance"],

  '/admin/badges': ["admin_pusat", "admin_hrd"],

  '/admin/budget': ["admin_pusat", "admin_finance"],

  '/admin/career': ["admin_pusat", "admin_hrd"],

  '/admin/certifications': ["admin_pusat", "admin_hrd"],

  '/admin/chain': ["admin_pusat"],

  '/admin/divisions': ["admin_pusat"],

  '/admin/employees': ["admin_pusat", "admin_hrd"],

  '/admin/estate': ["admin_pusat", "admin_estate"],

  '/admin/exit': ["admin_pusat", "admin_hrd"],

  '/admin/export': ["admin_pusat", "admin_finance"],

  '/admin/facility': ["admin_pusat", "admin_produksi"],

  '/admin/features': ["admin_pusat"],

  '/admin/headcount': ["admin_pusat"],

  '/admin/incentive': ["admin_pusat", "admin_finance"],

  '/admin/integrations': ["admin_pusat"],

  '/admin/kpi': ["admin_pusat", "admin_hrd", "admin_finance", "admin_produksi"],

  '/admin/learning': ["admin_pusat", "admin_hrd"],

  '/admin/leave': ["admin_pusat", "admin_hrd", "admin_produksi"],

  '/admin/master': ["admin_pusat"],

  '/admin/mfa': ["admin_pusat"],

  '/admin/mill': ["admin_pusat", "admin_mill"],

  '/admin/mining': ["admin_pusat", "admin_mining"],

  '/admin/modules': ["admin_pusat"],

  '/admin/okr': ["admin_pusat", "admin_hrd"],

  '/admin/onboarding': ["admin_pusat", "admin_hrd"],

  '/admin/org': ["admin_pusat"],

  '/admin/org-subtree': ["admin_pusat"],

  '/admin/overtime': ["admin_pusat", "admin_finance", "admin_produksi"],

  '/admin/payroll': ["admin_pusat", "admin_finance"],

  '/admin/pipeline': ["admin_pusat", "admin_hrd"],

  '/admin/recruitment': ["admin_pusat", "admin_hrd"],

  '/admin/referral': ["admin_pusat", "admin_hrd"],

  '/admin/requests': ["admin_pusat", "admin_hrd", "admin_produksi"],

  '/admin/reset-password': ["admin_pusat", "admin_hrd"],

  '/admin/review-360': ["admin_pusat", "admin_hrd"],

  '/admin/roles': ["admin_pusat"],

  '/admin/screening': ["admin_pusat", "admin_hrd"],

  '/admin/settings': ["admin_pusat"],

  '/admin/shift-swap': ["admin_pusat", "admin_produksi"],

  '/admin/simulation': ["admin_pusat"],

  '/admin/surveys': ["admin_pusat", "admin_hrd"],

  '/admin/talent': ["admin_pusat", "admin_hrd"],

  '/admin/timesheet': ["admin_pusat", "admin_finance", "admin_produksi"],

  '/admin/turnover': ["admin_pusat"],

  '/admin/voice': ["admin_pusat", "admin_hrd"],

  '/admin/whistleblower': ["admin_pusat", "admin_hrd"],

  '/admin': ['admin_pusat','admin_hrd','admin_finance','admin_produksi','admin_mining','admin_mill','admin_estate'],

};


export default function AdminRouteGuard({ children }) {
  const navigate = useNavigate();
  const location = useLocation();
  const session = getSession();
  const role = session?.role || 'admin_pusat';

  useEffect(() => {
    const path = location.pathname;
    // Check exact match first, then try parent path
    const allowed = ROLE_ACCESS[path] || ROLE_ACCESS[path.replace(/\/[^/]+$/, '')] || ROLE_ACCESS['/admin'];
    if (allowed && !allowed.includes(role)) {
      console.warn(`[AdminRouteGuard] Role "${role}" not allowed at "${path}". Redirecting.`);
      navigate('/admin', { replace: true });
    }
  }, [location.pathname, role, navigate]);

  return children;
}
