import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './globals.css'; // <-- Pastikan file globals.css sudah dipindah ke sini

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);