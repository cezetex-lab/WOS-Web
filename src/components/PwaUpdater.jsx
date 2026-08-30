// ============================================================
// PwaUpdater.jsx — PWA Update Notification
// Notifies users when a new version is available
// ============================================================

import { useState, useEffect } from 'react';

export default function PwaUpdater() {
  const [updateAvailable, setUpdateAvailable] = useState(false);
  const [registration, setRegistration] = useState(null);

  useEffect(() => {
    if (!('serviceWorker' in navigator)) return;

    navigator.serviceWorker.ready.then((reg) => {
      setRegistration(reg);

      // Check for updates every 60 minutes
      const checkUpdate = () => reg.update();
      checkUpdate();
      const interval = setInterval(checkUpdate, 60 * 60 * 1000);

      // Listen for new service worker waiting
      reg.addEventListener('updatefound', () => {
        const newWorker = reg.installing;
        if (!newWorker) return;

        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            setUpdateAvailable(true);
          }
        });
      });

      return () => clearInterval(interval);
    });

    // Listen for controlling service worker change
    let refreshing = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!refreshing) {
        refreshing = true;
        window.location.reload();
      }
    });
  }, []);

  const handleUpdate = () => {
    if (!registration?.waiting) return;
    // Tell the waiting SW to skip waiting
    registration.waiting.postMessage('skipWaiting');
  };

  if (!updateAvailable) return null;

  return (
    <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[100] animate-in slide-in-from-top duration-500">
      <div className="flex items-center gap-3 px-4 py-3 bg-slate-800/95 backdrop-blur-xl border border-sky-500/30 rounded-2xl shadow-lg shadow-sky-500/10 max-w-sm">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-sky-400 to-indigo-500 flex items-center justify-center text-xl flex-shrink-0">
          🔄
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-white">Update Tersedia!</p>
          <p className="text-xs text-slate-400 truncate">Versi baru insightWOS sudah siap.</p>
        </div>
        <button
          onClick={handleUpdate}
          className="px-4 py-2 bg-sky-600 hover:bg-sky-500 rounded-xl text-sm font-medium text-white transition-colors flex-shrink-0"
        >
          Update
        </button>
      </div>
    </div>
  );
}
