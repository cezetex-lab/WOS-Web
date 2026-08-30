import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { Providers } from './lib/design-system';
import PwaUpdater from './components/PwaUpdater';
import './globals.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <Providers>
      <App />
      <PwaUpdater />
    </Providers>
  </React.StrictMode>
);
