/**
 * CoreDataWrapper — Protect Core module pages
 * 
 * Jika tier kurang → tampilkan dummy/masked data.
 * Jika tier cukup → render children dengan data asli.
 */
import React from 'react';
import { useModuleAccess } from '@/hooks/useModuleAccess';

export default function CoreDataWrapper({ moduleCode, requiredRoleLevel = 1, children, fallbackTitle }) {
  const { data: hasAccess, isLoading } = useModuleAccess(moduleCode, requiredRoleLevel);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      </div>
    );
  }

  if (!hasAccess) {
    // Tier kurang → tampilkan dummy data
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6 text-center">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-semibold text-yellow-800 mb-2">
            {fallbackTitle || 'Fitur Premium'}
          </h3>
          <p className="text-yellow-700 text-sm mb-4">
            Modul ini memerlukan paket langganan yang lebih tinggi.
          </p>
          <div className="bg-white rounded-lg p-4 max-w-sm mx-auto">
            <p className="text-xs text-gray-500 mb-2">Data tidak tersedia</p>
            <div className="space-y-2">
              {[1, 2, 3].map(i => (
                <div key={i} className="h-4 bg-gray-100 rounded animate-pulse" />
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return children;
}
