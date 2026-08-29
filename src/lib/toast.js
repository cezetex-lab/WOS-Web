'use client';

import { useState, useCallback, createContext, useContext, useEffect, useRef } from 'react';

const ToastContext = createContext(null);

let toastId = 0;
let listeners = new Set();
let toasts = [];

function notify(type, message, duration = 3000) {
  const id = ++toastId;
  const toast = { id, type, message, exiting: false };
  toasts = [...toasts, toast];
  listeners.forEach((fn) => fn([...toasts]));

  setTimeout(() => {
    toasts = toasts.map((t) => t.id === id ? { ...t, exiting: true } : t);
    listeners.forEach((fn) => fn([...toasts]));
    setTimeout(() => {
      toasts = toasts.filter((t) => t.id !== id);
      listeners.forEach((fn) => fn([...toasts]));
    }, 300);
  }, duration);
}

export const toast = {
  success: (msg, dur) => notify('success', msg, dur),
  error: (msg, dur) => notify('error', msg, dur),
  warning: (msg, dur) => notify('warning', msg, dur),
  info: (msg, dur) => notify('info', msg, dur),
};

export function useToast() {
  return toast;
}

export function ToastProvider({ children }) {
  const [items, setItems] = useState(toasts);

  useEffect(() => {
    listeners.add(setItems);
    return () => listeners.delete(setItems);
  }, []);

  const dismiss = useCallback((id) => {
    toasts = toasts.map((t) => t.id === id ? { ...t, exiting: true } : t);
    listeners.forEach((fn) => fn([...toasts]));
    setTimeout(() => {
      toasts = toasts.filter((t) => t.id !== id);
      listeners.forEach((fn) => fn([...toasts]));
    }, 300);
  }, []);

  return (
    <ToastContext.Provider value={toast}>
      {children}
      <div className="toast-container">
        {items.map((t) => (
          <div
            key={t.id}
            className={`toast ${t.type} ${t.exiting ? 'toast-exit' : ''}`}
            onClick={() => dismiss(t.id)}
          >
            <span>{t.type === 'success' ? 'Ã¢Å“â€¦' : t.type === 'error' ? 'Ã¢ÂÅ’' : t.type === 'warning' ? 'Ã¢Å¡Â Ã¯Â¸Â' : 'Ã¢â€žÂ¹Ã¯Â¸Â'}</span>
            <span>{t.message}</span>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}
