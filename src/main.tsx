import React from 'react';
import ReactDOM from 'react-dom/client';
import './lib/posthog'; // PostHog init — page views, errors, clicks auto-captured
import App from './App';
import { Providers } from './lib/design-system';
import PwaUpdater from './components/PwaUpdater';
import ErrorBoundary from './components/ErrorBoundary';
import './globals.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ErrorBoundary>
      <Providers>
        <App />
        <PwaUpdater />
      </Providers>
    </ErrorBoundary>
  </React.StrictMode>
);
