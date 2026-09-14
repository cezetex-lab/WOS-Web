/**
 * ModuleRouteGuard — Protect Industry routes
 * 
 * Jika modul tidak aktif (Lock OFF atau akses ditolak),
 * redirect ke dashboard. UI hilang total.
 */
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useModuleAccess } from '@/hooks/useModuleAccess';

export default function ModuleRouteGuard({ moduleCode, requiredRoleLevel = 1, children }) {
  const { data: hasAccess, isLoading } = useModuleAccess(moduleCode, requiredRoleLevel);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      </div>
    );
  }

  if (!hasAccess) {
    // Industry module LOCKED → redirect silently
    return <Navigate to="/admin" replace />;
  }

  return children;
}
