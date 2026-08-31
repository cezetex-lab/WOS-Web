import React from 'react';
import ReactDOM from 'react-dom/client';
import * as Sentry from '@sentry/react';
import App from './App';
import { Providers } from './lib/design-system';
import PwaUpdater from './components/PwaUpdater';
import ErrorBoundary from './components/ErrorBoundary';
import './globals.css';

// Sentry — hanya aktif di production dengan DSN yang valid
if (import.meta.env.PROD && import.meta.env.VITE_SENTRY_DSN) {
  Sentry.init({
    dsn: import.meta.env.VITE_SENTRY_DSN,
    environment: import.meta.env.MODE || 'production',
    tracesSampleRate: 0.1, // 10% performance traces (free tier safe)
    replaysSessionSampleRate: 0, // disable session replay (save quota)
    replaysOnErrorSampleRate: 0.5, // 50% replay on error
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({ maskAllText: true, blockAllMedia: true }),
    ],
    enabled: !!import.meta.env.VITE_SENTRY_DSN,
  });
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <Sentry.ErrorBoundary fallback={<div className="min-h-screen bg-slate-900 flex items-center justify-center text-white"><p>Terjadi kesalahan. Silakan refresh halaman.</p></div>}>
      <ErrorBoundary>
        <Providers>
          <App />
          <PwaUpdater />
        </Providers>
      </ErrorBoundary>
    </Sentry.ErrorBoundary>
  </React.StrictMode>
);
