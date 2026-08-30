// ============================================================
// OfflineIndicator.jsx — Shows banner when user is offline
// Auto-hides when connection is restored
// ============================================================

import React, { useState, useEffect } from 'react';

export default function OfflineIndicator() {
  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  const [showRestored, setShowRestored] = useState(false);

  useEffect(() => {
    const handleOnline = () => {
      setIsOffline(false);
      setShowRestored(true);
      // Show "back online" message for 3 seconds
      setTimeout(() => setShowRestored(false), 3000);
    };

    const handleOffline = () => {
      setIsOffline(true);
      setShowRestored(false);
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  if (!isOffline && !showRestored) return null;

  return (
    <div
      className={`fixed top-0 left-0 right-0 z-[100] px-4 py-2 text-center text-sm font-medium transition-all duration-300 ${
        isOffline
          ? 'bg-red-600 text-white'
          : 'bg-green-600 text-white'
      }`}
    >
      {isOffline ? (
        <span>📡 Anda sedang offline — data ditampilkan dari cache lokal</span>
      ) : (
        <span>✅ Kembali online — menyinkronkan data...</span>
      )}
    </div>
  );
}
