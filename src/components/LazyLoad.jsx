import React, { Suspense } from 'react';

function LoadingSkeleton() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center">
      <div className="text-center">
        <div className="relative w-16 h-16 mx-auto mb-4">
          <div className="absolute inset-0 rounded-full border-4 border-slate-700" />
          <div className="absolute inset-0 rounded-full border-4 border-teal-400 border-t-transparent animate-spin" />
        </div>
        <p className="text-slate-400 text-sm animate-pulse">Memuat halaman...</p>
      </div>
    </div>
  );
}

export default function LazyLoad({ children }) {
  return (
    <Suspense fallback={<LoadingSkeleton />}>
      {children}
    </Suspense>
  );
}
