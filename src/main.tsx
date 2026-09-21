import React from 'react';
import ReactDOM from 'react-dom/client';
import './lib/error-suppressor'; // paling awal — pasang handler sebelum app render
import './lib/register-sw'; // PWA: registrasi Service Worker (ex-inline script index.html)
import './lib/posthog'; // PostHog init DEFERRED (OPS-03b) — dijadwalkan setelah idle, lihat lib/posthog.ts
import App from './App';
import { Providers } from './lib/design-system';
import PwaUpdater from './components/PwaUpdater';
import ErrorBoundary from './components/ErrorBoundary';
import './globals.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <Providers>
        <App />
        <PwaUpdater />
      </Providers>
    </ErrorBoundary>
  </React.StrictMode>
);
