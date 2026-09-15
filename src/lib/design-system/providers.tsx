// Design System — Providers (Theme + Toast)
import { useState, useEffect, useCallback, createContext, useContext, type ReactNode } from 'react';

interface ThemeContextType {
  isDark: boolean;
  toggle: () => void;
}

const ThemeCtx = createContext<ThemeContextType>({ isDark: true, toggle: () => {} });

interface ThemeProviderProps {
  children: ReactNode;
}

export function ThemeProvider({ children }: ThemeProviderProps) {
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('wos_theme');
      if (saved) return saved === 'dark';
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    return true;
  });

  const toggle = useCallback(() => {
    setIsDark(prev => {
      const next = !prev;
      localStorage.setItem('wos_theme', next ? 'dark' : 'light');
      document.documentElement.setAttribute('data-theme', next ? 'dark' : 'light');
      return next;
    });
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
  }, [isDark]);

  return (
    <ThemeCtx.Provider value={{ isDark, toggle }}>
      {children}
    </ThemeCtx.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeCtx);
}

interface ToastType {
  success: (message: string, duration?: number) => void;
  error: (message: string, duration?: number) => void;
  info: (message: string, duration?: number) => void;
  warning: (message: string, duration?: number) => void;
}

interface ToastContextType {
  toast: ToastType;
}

const ToastCtx = createContext<ToastContextType>({ toast: { success: () => {}, error: () => {}, info: () => {}, warning: () => {} } });

interface ToastItem {
  id: number;
  type: string;
  message: string;
  exiting: boolean;
}

let _toastId = 0;
let _listeners = new Set<(toasts: ToastItem[]) => void>();
let _toasts: ToastItem[] = [];

function _notify(type: string, message: string, duration = 3000) {
  const id = ++_toastId;
  const t: ToastItem = { id, type, message, exiting: false };
  _toasts = [..._toasts, t];
  _listeners.forEach(fn => fn([..._toasts]));
  setTimeout(() => {
    _toasts = _toasts.map(x => x.id === id ? { ...x, exiting: true } : x);
    _listeners.forEach(fn => fn([..._toasts]));
    setTimeout(() => {
      _toasts = _toasts.filter(x => x.id !== id);
      _listeners.forEach(fn => fn([..._toasts]));
    }, 300);
  }, duration);
}

const _toast: ToastType = {
  success: (m, d) => _notify('success', m, d),
  error: (m, d) => _notify('error', m, d),
  warning: (m, d) => _notify('warning', m, d),
  info: (m, d) => _notify('info', m, d),
};

export function useToast() {
  return useContext(ToastCtx).toast;
}

interface ToastProviderProps {
  children: ReactNode;
}

export function ToastProvider({ children }: ToastProviderProps) {
  const [items, setItems] = useState(_toasts);
  useEffect(() => {
    _listeners.add(setItems);
    return () => { _listeners.delete(setItems); };
  }, []);
  return (
    <ToastCtx.Provider value={{ toast: _toast }}>
      {children}
      <div className="fixed top-4 right-4 z-[9999] flex flex-col gap-2 max-w-xs pointer-events-none">
        {items.map(t => (
          <div key={t.id} className={`pointer-events-auto px-4 py-3 rounded-xl text-sm font-semibold backdrop-blur-xl shadow-lg border flex items-center gap-2 transition-all duration-300 ${t.exiting ? 'opacity-0 translate-x-8 scale-95' : 'opacity-100 translate-x-0 scale-100'} ${t.type === 'success' ? 'bg-emerald-500/90 text-white border-emerald-400/50' : ''} ${t.type === 'error' ? 'bg-red-500/90 text-white border-red-400/50' : ''} ${t.type === 'warning' ? 'bg-amber-500/90 text-white border-amber-400/50' : ''} ${t.type === 'info' ? 'bg-blue-500/90 text-white border-blue-400/50' : ''}`}>
            <span className="text-base">{t.type === 'success' ? '✓' : t.type === 'error' ? '✕' : t.type === 'warning' ? '⚠' : 'ℹ'}</span>
            <span>{t.message}</span>
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

interface ProvidersProps {
  children: ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <ThemeProvider>
      <ToastProvider>
        {children}
      </ToastProvider>
    </ThemeProvider>
  );
}
