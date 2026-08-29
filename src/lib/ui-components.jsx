'use client';
import { useState, useEffect, createContext, useContext, useCallback } from 'react';

// ============================================================
// TOAST CONTEXT
// ============================================================
const ToastContext = createContext(null);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const addToast = useCallback((msg, type = 'info') => {
    const id = Date.now();
    setToasts(prev => [...prev, { id, msg, type }]);
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 3000);
  }, []);
  const toast = {
    success: (m) => addToast(m, 'success'),
    error: (m) => addToast(m, 'error'),
    info: (m) => addToast(m, 'info'),
    warning: (m) => addToast(m, 'warning'),
  };
  return (
    <ToastContext.Provider value={toast}>
      {children}
      <div style={{ position: 'fixed', top: 16, right: 16, zIndex: 9999, display: 'flex', flexDirection: 'column', gap: 8, maxWidth: 320 }}>
        {toasts.map(t => (
          <div key={t.id} style={{
            padding: '12px 16px', borderRadius: 8, fontSize: 13, fontWeight: 600, color: '#fff',
            background: t.type === 'success' ? '#059669' : t.type === 'error' ? '#dc2626' : t.type === 'warning' ? '#d97706' : '#2563eb',
            boxShadow: '0 4px 12px rgba(0,0,0,0.3)', animation: 'slideIn 0.3s ease',
          }}>{t.type === 'success' ? 'Ã¢Å“â€¦' : t.type === 'error' ? 'Ã¢ÂÅ’' : t.type === 'warning' ? 'Ã¢Å¡Â Ã¯Â¸Â' : 'Ã¢â€žÂ¹Ã¯Â¸Â'} {t.msg}</div>
        ))}
      </div>
      <style>{`@keyframes slideIn { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }`}</style>
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}

// ============================================================
// DARK MODE CONTEXT
// ============================================================
const ThemeContext = createContext(null);

export function ThemeProvider({ children }) {
  const [dark, setDark] = useState(true);
  const toggle = () => setDark(d => !d);
  return (
    <ThemeContext.Provider value={{ dark, toggle }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeContext);
}

// ============================================================
// DARK MODE TOGGLE BUTTON
// ============================================================
export function DarkModeToggle() {
  const { dark, toggle } = useTheme();
  return (
    <button onClick={toggle} style={{
      background: 'none', border: '1px solid #334155', borderRadius: 8,
      padding: '6px 10px', fontSize: 16, cursor: 'pointer', color: '#e2e8f0',
    }} title={dark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}>
      {dark ? 'Ã¢Ëœâ‚¬Ã¯Â¸Â' : 'Ã°Å¸Å’â„¢'}
    </button>
  );
}

// ============================================================
// CHART COMPONENTS (Chart.js wrapper)
// ============================================================

// Simple Bar Chart (horizontal)
export function BarChart({ data, labels, colors, height = 200 }) {
  const max = Math.max(...data, 1);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, height }}>
      {data.map((val, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ minWidth: 60, fontSize: 11, color: '#94a3b8', textAlign: 'right', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{labels[i]}</div>
          <div style={{ flex: 1, background: '#0f172a', borderRadius: 4, height: 16, overflow: 'hidden' }}>
            <div style={{ width: `${(val / max) * 100}%`, height: '100%', background: colors?.[i] || '#38bdf8', borderRadius: 4, transition: 'width 0.5s ease' }} />
          </div>
          <div style={{ minWidth: 40, fontSize: 12, fontWeight: 700, color: colors?.[i] || '#38bdf8' }}>{val}</div>
        </div>
      ))}
    </div>
  );
}

// Simple Stat Card
export function StatCard({ label, value, color = '#38bdf8', icon, subtitle }) {
  return (
    <div style={{ background: '#0f172a', borderRadius: 8, padding: 12, textAlign: 'center', border: '1px solid #334155' }}>
      {icon && <div style={{ fontSize: 20, marginBottom: 4 }}>{icon}</div>}
      <div style={{ fontSize: 24, fontWeight: 700, color }}>{value}</div>
      <div style={{ fontSize: 11, color: '#94a3b8', marginTop: 2 }}>{label}</div>
      {subtitle && <div style={{ fontSize: 10, color: '#64748b', marginTop: 2 }}>{subtitle}</div>}
    </div>
  );
}

// Simple Progress Bar
export function ProgressBar({ value, max = 100, color = '#38bdf8', height = 8 }) {
  const pct = Math.min((value / Math.max(max, 1)) * 100, 100);
  return (
    <div style={{ background: '#0f172a', borderRadius: height / 2, height, overflow: 'hidden' }}>
      <div style={{ width: `${pct}%`, height: '100%', background: color, borderRadius: height / 2, transition: 'width 0.5s ease' }} />
    </div>
  );
}

// Simple Line Sparkline (SVG)
export function Sparkline({ data, color = '#38bdf8', width = 120, height = 40 }) {
  if (!data || data.length < 2) return null;
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const points = data.map((v, i) => `${(i / (data.length - 1)) * width},${height - ((v - min) / range) * height}`).join(' ');
  return (
    <svg width={width} height={height} style={{ display: 'block' }}>
      <polyline points={points} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// Donut / Pie Chart (CSS-based)
export function DonutChart({ segments, size = 120 }) {
  // segments: [{ label, value, color }]
  const total = segments.reduce((s, seg) => s + seg.value, 0) || 1;
  let cumPct = 0;
  const gradients = segments.map(seg => {
    const start = cumPct;
    cumPct += (seg.value / total) * 100;
    return `${seg.color} ${start}% ${cumPct}%`;
  }).join(', ');
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <div style={{ width: size, height: size, borderRadius: '50%', background: `conic-gradient(${gradients})`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: size * 0.6, height: size * 0.6, borderRadius: '50%', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column' }}>
          <div style={{ fontSize: 16, fontWeight: 700, color: '#e2e8f0' }}>{total}</div>
          <div style={{ fontSize: 9, color: '#94a3b8' }}>Total</div>
        </div>
      </div>
    </div>
  );
}
