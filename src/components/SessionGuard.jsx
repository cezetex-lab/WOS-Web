/**
 * SessionGuard — Route-level authentication guard
 * Wraps all protected routes (admin/worker). Login page (/) is NOT protected.
 * Redirects to / if no valid session found.
 */
import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { getSession } from '@/lib/supabase-browser';

const PUBLIC_PATHS = ['/', '/mfa', '/health'];

export default function SessionGuard({ children }) {
  const location = useLocation();
  const session = getSession();

  // Public pages — always allow
  if (PUBLIC_PATHS.includes(location.pathname)) {
    return children;
  }

  // No session -> redirect to login
  if (!session || !session.nrp) {
    return <Navigate to="/" replace />;
  }

  return children;
}
