// ============================================================
// insightWOS Design System v1.0
// Professional • Clean • Smart • Beautiful
// ============================================================
// Single source of truth untuk SEMUA UI components.
// Semua page import dari sini. Tidak ada duplicate.
// ============================================================

import React, { useState, useEffect, useCallback, createContext, useContext, useRef } from 'react';
import { useNavigate } from 'react-router-dom';

// ──────────────────────────────────────────────────────────────
// 0. CSS VARIABLES CLASS (apply ke root)
// ──────────────────────────────────────────────────────────────
export function applyDesignTokens() {
  if (typeof document !== 'undefined') {
    document.documentElement.classList.add('wos-theme');
  }
}

// ──────────────────────────────────────────────────────────────
// 1. THEME PROVIDER (Single source of truth)
// ──────────────────────────────────────────────────────────────
const ThemeCtx = createContext({ isDark: true, toggle: () => {} });

export function ThemeProvider({ children }) {
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

// ──────────────────────────────────────────────────────────────
// 2. TOAST SYSTEM (Single source of truth)
// ──────────────────────────────────────────────────────────────
const ToastCtx = createContext({ toast: { success: () => {}, error: () => {}, info: () => {}, warning: () => {} } });

let _toastId = 0;
let _listeners = new Set();
let _toasts = [];

function _notify(type, message, duration = 3000) {
  const id = ++_toastId;
  const t = { id, type, message, exiting: false };
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

const _toast = {
  success: (m, d) => _notify('success', m, d),
  error: (m, d) => _notify('error', m, d),
  warning: (m, d) => _notify('warning', m, d),
  info: (m, d) => _notify('info', m, d),
};

export function useToast() {
  return useContext(ToastCtx).toast;
}

export function ToastProvider({ children }) {
  const [items, setItems] = useState(_toasts);

  useEffect(() => {
    _listeners.add(setItems);
    return () => _listeners.delete(setItems);
  }, []);

  return (
    <ToastCtx.Provider value={{ toast: _toast }}>
      {children}
      <div className="fixed top-4 right-4 z-[9999] flex flex-col gap-2 max-w-xs pointer-events-none">
        {items.map(t => (
          <div
            key={t.id}
            className={`
              pointer-events-auto px-4 py-3 rounded-xl text-sm font-semibold
              backdrop-blur-xl shadow-lg border
              flex items-center gap-2 transition-all duration-300
              ${t.exiting ? 'opacity-0 translate-x-8 scale-95' : 'opacity-100 translate-x-0 scale-100'}
              ${t.type === 'success' ? 'bg-emerald-500/90 text-white border-emerald-400/50' : ''}
              ${t.type === 'error' ? 'bg-red-500/90 text-white border-red-400/50' : ''}
              ${t.type === 'warning' ? 'bg-amber-500/90 text-white border-amber-400/50' : ''}
              ${t.type === 'info' ? 'bg-blue-500/90 text-white border-blue-400/50' : ''}
            `}
          >
            <span className="text-base">
              {t.type === 'success' ? '✓' : t.type === 'error' ? '✕' : t.type === 'warning' ? '⚠' : 'ℹ'}
            </span>
            <span>{t.message}</span>
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

// ──────────────────────────────────────────────────────────────
// 3. UNIFIED PROVIDER (Theme + Toast)
// ──────────────────────────────────────────────────────────────
export function Providers({ children }) {
  return (
    <ThemeProvider>
      <ToastProvider>
        {children}
      </ToastProvider>
    </ThemeProvider>
  );
}

// ──────────────────────────────────────────────────────────────
// 4. PAGE LAYOUT
// ──────────────────────────────────────────────────────────────

/**
 * <PageLayout title="..." subtitle="..." backTo="/admin" transparent>
 *   {children}
 * </PageLayout>
 */
export function PageLayout({ title, subtitle, backTo, children, transparent, className = '' }) {
  return (
    <div className={`min-h-screen ${transparent ? '' : 'bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900'} ${className}`}>
      {/* Header */}
      {(title || backTo) && (
        <div className="sticky top-0 z-30 backdrop-blur-xl bg-slate-900/80 border-b border-white/5">
          <div className="max-w-7xl mx-auto px-4 py-3 flex items-center gap-3">
            {backTo && <BackButton to={backTo} />}
            <div className="flex-1 min-w-0">
              {title && <h1 className="text-lg font-bold text-white truncate">{title}</h1>}
              {subtitle && <p className="text-xs text-slate-400 truncate">{subtitle}</p>}
            </div>
          </div>
        </div>
      )}
      {/* Content */}
      <div className={`max-w-7xl mx-auto px-4 py-4 pb-24 ${transparent ? '' : ''}`}>
        {children}
      </div>
    </div>
  );
}

function BackButton({ to }) {
  const navigate = useNavigate();
  return (
    <button
      onClick={() => navigate(to)}
      className="flex items-center justify-center w-8 h-8 rounded-xl bg-white/5 hover:bg-white/10 text-slate-400 hover:text-white transition-all active:scale-95"
    >
      ←
    </button>
  );
}

// ──────────────────────────────────────────────────────────────
// 5. METRIC CARD
// ──────────────────────────────────────────────────────────────

/**
 * <MetricCard icon="👤" value={120} label="Karyawan" trend="Aktif" color="blue" loading={false} onClick={fn} />
 */
export function MetricCard({ icon, value, label, trend, color = 'blue', loading, onClick }) {
  const colors = {
    blue:   'from-blue-500/20 to-blue-600/5 border-blue-500/20',
    teal:   'from-teal-500/20 to-teal-600/5 border-teal-500/20',
    orange: 'from-orange-500/20 to-orange-600/5 border-orange-500/20',
    red:    'from-red-500/20 to-red-600/5 border-red-500/20',
    purple: 'from-purple-500/20 to-purple-600/5 border-purple-500/20',
    green:  'from-emerald-500/20 to-emerald-600/5 border-emerald-500/20',
    slate:  'from-slate-500/20 to-slate-600/5 border-slate-500/20',
  };

  const trendColors = {
    blue: 'text-blue-400 bg-blue-400/15',
    teal: 'text-teal-400 bg-teal-400/15',
    orange: 'text-orange-400 bg-orange-400/15',
    red: 'text-red-400 bg-red-400/15',
    purple: 'text-purple-400 bg-purple-400/15',
    green: 'text-emerald-400 bg-emerald-400/15',
    slate: 'text-slate-400 bg-slate-400/15',
  };

  if (loading) {
    return (
      <div className="animate-pulse bg-slate-700/30 rounded-2xl h-28 border border-white/5" />
    );
  }

  return (
    <div
      onClick={onClick}
      className={`
        bg-gradient-to-br ${colors[color]} backdrop-blur-sm
        border rounded-2xl p-4 shadow-lg
        transition-all duration-200
        ${onClick ? 'cursor-pointer hover:scale-[1.02] hover:shadow-xl active:scale-[0.98]' : ''}
      `}
    >
      <div className="flex items-start justify-between">
        <span className="text-2xl">{icon}</span>
        {trend && (
          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${trendColors[color]}`}>
            {trend}
          </span>
        )}
      </div>
      <div className="mt-2">
        <div className="text-2xl font-bold text-white tracking-tight">{value}</div>
        <div className="text-[10px] text-slate-400 font-semibold uppercase tracking-wider mt-0.5">{label}</div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 6. GLASS CARD
// ──────────────────────────────────────────────────────────────

/**
 * <GlassCard title="Insight" icon="💡" accent="blue">
 *   {children}
 * </GlassCard>
 */
export function GlassCard({ title, icon, accent = 'teal', children, className = '', actions }) {
  const accents = {
    teal:   'border-l-teal-400',
    blue:   'border-l-blue-400',
    orange: 'border-l-orange-400',
    red:    'border-l-red-400',
    purple: 'border-l-purple-400',
    green:  'border-l-emerald-400',
    slate:  'border-l-slate-400',
  };

  return (
    <div className={`
      bg-slate-800/40 backdrop-blur-md rounded-2xl p-5
      border border-white/5 border-l-4 ${accents[accent]}
      shadow-xl transition-all duration-200
      hover:bg-slate-800/50
      ${className}
    `}>
      {(title || actions) && (
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            {icon && <span className="text-lg">{icon}</span>}
            {title && <h3 className="text-sm font-bold text-white/90 tracking-wide">{title}</h3>}
          </div>
          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </div>
      )}
      <div className="text-slate-200 text-sm leading-relaxed">{children}</div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 7. QUICK TILE
// ──────────────────────────────────────────────────────────────

/**
 * <QuickTile icon="📝" label="Pengajuan" color="blue" onClick={fn} badge={3} />
 */
export function QuickTile({ icon, label, color = 'slate', onClick, badge }) {
  const bgColors = {
    slate:  'bg-slate-700/40 hover:bg-slate-600/50',
    blue:   'bg-blue-500/15 hover:bg-blue-500/25',
    teal:   'bg-teal-500/15 hover:bg-teal-500/25',
    orange: 'bg-orange-500/15 hover:bg-orange-500/25',
    purple: 'bg-purple-500/15 hover:bg-purple-500/25',
    green:  'bg-emerald-500/15 hover:bg-emerald-500/25',
    red:    'bg-red-500/15 hover:bg-red-500/25',
  };

  return (
    <button
      onClick={onClick}
      className={`
        relative flex flex-col items-center justify-center
        p-3 rounded-2xl ${bgColors[color]}
        backdrop-blur-sm border border-white/5
        transition-all duration-200 hover:border-white/15
        active:scale-95
      `}
    >
      <span className="text-2xl mb-1">{icon}</span>
      <span className="text-[10px] font-medium text-slate-300 text-center leading-tight">{label}</span>
      {badge > 0 && (
        <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] flex items-center justify-center bg-red-500 text-white text-[9px] font-bold rounded-full px-1">
          {badge > 99 ? '99+' : badge}
        </span>
      )}
    </button>
  );
}

// ──────────────────────────────────────────────────────────────
// 8. BADGE
// ──────────────────────────────────────────────────────────────

/**
 * <Badge status="Pending" type="warning" />
 */
export function Badge({ status, type = 'default', className = '' }) {
  const types = {
    default: 'bg-slate-500/20 text-slate-300 border-slate-500/30',
    success: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
    warning: 'bg-amber-500/20 text-amber-300 border-amber-500/30',
    danger:  'bg-red-500/20 text-red-300 border-red-500/30',
    info:    'bg-blue-500/20 text-blue-300 border-blue-500/30',
  };

  return (
    <span className={`inline-flex items-center text-[10px] font-bold px-2 py-0.5 rounded-full border ${types[type]} ${className}`}>
      {status}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────
// 9. ACTION ITEM (List row with optional badge + arrow)
// ──────────────────────────────────────────────────────────────

/**
 * <ActionItem title="Request Cuti" subtitle="Budi - PKWT" date="2026-08-29" badge="HIGH" badgeType="danger" onClick={fn} />
 */
export function ActionItem({ title, subtitle, date, badge, badgeType = 'warning', onClick }) {
  return (
    <div
      onClick={onClick}
      className={`
        flex items-center justify-between p-3
        bg-slate-900/40 rounded-xl border border-white/5
        transition-all duration-200
        ${onClick ? 'hover:border-white/10 hover:bg-slate-800/40 cursor-pointer active:scale-[0.99]' : ''}
      `}
    >
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-white truncate">{title}</span>
          {badge && <Badge status={badge} type={badgeType} />}
        </div>
        {subtitle && <p className="text-xs text-slate-400 truncate mt-0.5">{subtitle}</p>}
        {date && (
          <p className="text-[10px] text-slate-500 mt-0.5">
            {new Date(date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}
          </p>
        )}
      </div>
      <svg className="w-4 h-4 text-slate-500 flex-shrink-0 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" />
      </svg>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 10. EMPTY STATE
// ──────────────────────────────────────────────────────────────

/**
 * <EmptyState icon="📭" title="Tidak ada data" subtitle="Belum ada pengajuan" />
 */
export function EmptyState({ icon = '📭', title = 'Tidak ada data', subtitle }) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <span className="text-4xl mb-3">{icon}</span>
      <p className="text-sm font-semibold text-slate-300">{title}</p>
      {subtitle && <p className="text-xs text-slate-500 mt-1">{subtitle}</p>}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 11. DATA TABLE
// ──────────────────────────────────────────────────────────────

/**
 * <DataTable
 *   columns={[{ key: 'name', label: 'Nama' }, { key: 'nrp', label: 'NRP' }]}
 *   data={[{ name: 'Budi', nrp: 'NRP001' }]}
 *   searchPlaceholder="Cari karyawan..."
 *   onRowClick={fn}
 * />
 */
export function DataTable({ columns = [], data = [], searchPlaceholder = 'Cari...', onRowClick, emptyMessage = 'Tidak ada data', loading }) {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const perPage = 10;

  const filtered = data.filter(row => {
    if (!search) return true;
    const q = search.toLowerCase();
    return columns.some(col => String(row[col.key] || '').toLowerCase().includes(q));
  });

  const totalPages = Math.ceil(filtered.length / perPage);
  const paged = filtered.slice(page * perPage, (page + 1) * perPage);

  useEffect(() => { setPage(0); }, [search]);

  if (loading) {
    return (
      <div className="space-y-2">
        {[1, 2, 3].map(i => (
          <div key={i} className="animate-pulse bg-slate-700/30 h-12 rounded-xl" />
        ))}
      </div>
    );
  }

  return (
    <div>
      {/* Search */}
      <div className="flex items-center gap-2 bg-slate-800/50 rounded-xl px-3 py-2.5 border border-white/5 mb-3">
        <svg className="w-4 h-4 text-slate-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          type="text"
          placeholder={searchPlaceholder}
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="flex-1 bg-transparent text-sm text-white placeholder-slate-500 outline-none"
        />
        {search && (
          <button onClick={() => setSearch('')} className="text-slate-500 hover:text-white text-xs">✕</button>
        )}
      </div>

      {/* Table */}
      <div className="overflow-x-auto -mx-4 px-4">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/5">
              {columns.map(col => (
                <th key={col.key} className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider py-2 px-2">
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {paged.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="text-center py-8 text-slate-500 text-xs">
                  {emptyMessage}
                </td>
              </tr>
            ) : paged.map((row, i) => (
              <tr
                key={row.id || i}
                onClick={() => onRowClick?.(row)}
                className={`
                  border-b border-white/3 transition-colors
                  ${onRowClick ? 'cursor-pointer hover:bg-white/3 active:bg-white/5' : ''}
                `}
              >
                {columns.map(col => (
                  <td key={col.key} className="py-2.5 px-2 text-slate-300 text-xs">
                    {col.render ? col.render(row[col.key], row) : row[col.key]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-3 pt-3 border-t border-white/5">
          <span className="text-[10px] text-slate-500">
            {filtered.length} data • Hal {page + 1}/{totalPages}
          </span>
          <div className="flex gap-1">
            <button
              onClick={() => setPage(p => Math.max(0, p - 1))}
              disabled={page === 0}
              className="px-2 py-1 rounded-lg text-[10px] font-bold bg-white/5 text-slate-400 disabled:opacity-30 hover:bg-white/10 transition-all"
            >
              ←
            </button>
            <button
              onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
              disabled={page >= totalPages - 1}
              className="px-2 py-1 rounded-lg text-[10px] font-bold bg-white/5 text-slate-400 disabled:opacity-30 hover:bg-white/10 transition-all"
            >
              →
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 12. STAT ITEM (single stat with bar)
// ──────────────────────────────────────────────────────────────

/**
 * <StatItem label="KPI Score" value={85} max={100} color="#38bdf8" />
 */
export function StatItem({ label, value, max = 100, color = '#38bdf8', suffix = '' }) {
  const pct = Math.min((value / Math.max(max, 1)) * 100, 100);
  return (
    <div className="p-3 bg-slate-900/40 rounded-xl border border-white/5">
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-xs text-slate-400">{label}</span>
        <span className="text-sm font-bold text-white">{value}{suffix}</span>
      </div>
      <div className="h-1.5 bg-slate-700/50 rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-700 ease-out"
          style={{ width: `${pct}%`, background: color }}
        />
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 13. SECTION HEADER
// ──────────────────────────────────────────────────────────────

/**
 * <SectionHeader title="Menu Utama" action={<button>See All</button>} />
 */
export function SectionHeader({ title, action, icon }) {
  return (
    <div className="flex items-center justify-between mb-3">
      <div className="flex items-center gap-2">
        {icon && <span className="text-base">{icon}</span>}
        <h2 className="text-sm font-bold text-white tracking-wide">{title}</h2>
      </div>
      {action}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 14. DIVIDER
// ──────────────────────────────────────────────────────────────
export function Divider({ className = '' }) {
  return <div className={`border-t border-white/5 ${className}`} />;
}

// ──────────────────────────────────────────────────────────────
// 15. LOADING SPINNER
// ──────────────────────────────────────────────────────────────

/**
 * <LoadingSpinner />
 * <LoadingSpinner size="lg" text="Memuat data..." />
 */
export function LoadingSpinner({ size = 'md', text, className = '' }) {
  const sizes = { sm: 'h-5 w-5', md: 'h-8 w-8', lg: 'h-12 w-12' };
  return (
    <div className={`flex flex-col items-center justify-center py-12 ${className}`}>
      <div className={`${sizes[size]} border-2 border-slate-600 border-t-teal-400 rounded-full animate-spin`} />
      {text && <p className="text-xs text-slate-400 mt-3">{text}</p>}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 16. BUTTON
// ──────────────────────────────────────────────────────────────

/**
 * <Button color="teal" size="md" onClick={fn}>Submit</Button>
 * <Button color="red" variant="outline" size="sm">Delete</Button>
 */
export function Button({ children, color = 'teal', variant = 'solid', size = 'md', onClick, disabled, className = '', type = 'button', ariaLabel }) {
  const colors = {
    teal:   'bg-teal-500 hover:bg-teal-400 text-white',
    blue:   'bg-blue-500 hover:bg-blue-400 text-white',
    red:    'bg-red-500 hover:bg-red-400 text-white',
    orange: 'bg-orange-500 hover:bg-orange-400 text-white',
    slate:  'bg-slate-600 hover:bg-slate-500 text-white',
    ghost:  'bg-transparent hover:bg-white/10 text-slate-300',
  };
  const outlineColors = {
    teal:   'border-teal-500/50 text-teal-400 hover:bg-teal-500/10',
    blue:   'border-blue-500/50 text-blue-400 hover:bg-blue-500/10',
    red:    'border-red-500/50 text-red-400 hover:bg-red-500/10',
    orange: 'border-orange-500/50 text-orange-400 hover:bg-orange-500/10',
    slate:  'border-slate-500/50 text-slate-400 hover:bg-slate-500/10',
    ghost:  'border-transparent text-slate-400 hover:bg-white/10',
  };
  const sizes = {
    sm: 'px-3 py-1.5 text-xs rounded-lg',
    md: 'px-4 py-2.5 text-sm rounded-xl',
    lg: 'px-6 py-3 text-base rounded-xl',
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      aria-label={ariaLabel}
      className={`
        font-semibold transition-all duration-200 active:scale-95
        focus:outline-none focus:ring-2 focus:ring-teal-400/50 focus:ring-offset-2 focus:ring-offset-slate-900
        ${variant === 'outline' ? `border ${outlineColors[color]}` : colors[color]}
        ${sizes[size]}
        ${disabled ? 'opacity-40 pointer-events-none' : ''}
        ${className}
      `}
    >
      {children}
    </button>
  );
}

// ──────────────────────────────────────────────────────────────
// 17. INPUT FIELD
// ──────────────────────────────────────────────────────────────

/**
 * <Input label="Email" placeholder="email@..." value={v} onChange={fn} icon="📧" />
 */
export function Input({ label, placeholder, value, onChange, type = 'text', icon, error, className = '', id }) {
  const inputId = id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);
  const errorId = inputId ? `${inputId}-error` : undefined;

  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      {label && <label htmlFor={inputId} className="text-xs font-semibold text-slate-300">{label}</label>}
      <div className={`
        flex items-center gap-2 px-3 py-2.5 rounded-xl
        bg-slate-800/50 border transition-all
        ${error ? 'border-red-500/50' : 'border-white/5 focus-within:border-teal-500/50'}
      `}>
        {icon && <span className="text-base flex-shrink-0" aria-hidden="true">{icon}</span>}
        <input
          id={inputId}
          type={type}
          placeholder={placeholder}
          value={value}
          onChange={onChange}
          aria-invalid={!!error}
          aria-describedby={error ? errorId : undefined}
          className="flex-1 bg-transparent text-sm text-white placeholder-slate-500 outline-none focus:outline-none"
        />
      </div>
      {error && <span id={errorId} className="text-[10px] text-red-400" role="alert">{error}</span>}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 18. AVATAR
// ──────────────────────────────────────────────────────────────

/**
 * <Avatar name="Budi" size="md" />
 */
export function Avatar({ name = '', size = 'md', src, className = '' }) {
  const sizes = {
    sm: 'w-8 h-8 text-xs',
    md: 'w-10 h-10 text-sm',
    lg: 'w-14 h-14 text-lg',
  };
  const initial = (name || '?')[0].toUpperCase();

  return (
    <div className={`
      ${sizes[size]} rounded-full
      bg-gradient-to-br from-teal-400 to-blue-500
      flex items-center justify-center
      font-bold text-white border-2 border-teal-400/50
      flex-shrink-0
      ${className}
    `}>
      {src ? (
        <img src={src} alt={name} className="w-full h-full rounded-full object-cover" />
      ) : (
        initial
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 19. TABS
// ──────────────────────────────────────────────────────────────

/**
 * <Tabs tabs={[{ id: 'all', label: 'Semua' }, { id: 'pending', label: 'Pending' }]} active={tab} onChange={setTab} />
 */
export function Tabs({ tabs = [], active, onChange, className = '' }) {
  return (
    <div role="tablist" className={`flex gap-1 p-1 bg-slate-800/50 rounded-xl border border-white/5 ${className}`}>
      {tabs.map(tab => (
        <button
          key={tab.id}
          role="tab"
          aria-selected={active === tab.id}
          tabIndex={active === tab.id ? 0 : -1}
          onClick={() => onChange(tab.id)}
          onKeyDown={(e) => {
            const idx = tabs.findIndex(t => t.id === active);
            if (e.key === 'ArrowRight') {
              e.preventDefault();
              const next = tabs[(idx + 1) % tabs.length];
              onChange(next.id);
            } else if (e.key === 'ArrowLeft') {
              e.preventDefault();
              const prev = tabs[(idx - 1 + tabs.length) % tabs.length];
              onChange(prev.id);
            }
          }}
          className={`
            flex-1 px-3 py-2 rounded-lg text-xs font-semibold transition-all duration-200
            focus:outline-none focus:ring-2 focus:ring-teal-400/50
            ${active === tab.id
              ? 'bg-teal-500/20 text-teal-400 shadow-sm'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
            }
          `}
        >
          {tab.label}
          {tab.count !== undefined && (
            <span className="ml-1 text-[10px] opacity-60">({tab.count})</span>
          )}
        </button>
      ))}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// 20. TOGGLE / SWITCH
// ──────────────────────────────────────────────────────────────

export function Toggle({ checked, onChange, label }) {
  return (
    <label className="flex items-center gap-3 cursor-pointer">
      <div
        role="switch"
        aria-checked={checked}
        aria-label={label || 'Toggle'}
        tabIndex={0}
        onClick={() => onChange?.(!checked)}
        onKeyDown={(e) => { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); onChange?.(!checked); } }}
        className={`
          relative w-10 h-5 rounded-full transition-colors duration-200
          focus:outline-none focus:ring-2 focus:ring-teal-400/50
          ${checked ? 'bg-teal-500' : 'bg-slate-600'}
        `}
      >
        <div className={`
          absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200
          ${checked ? 'translate-x-5' : 'translate-x-0'}
        `} />
      </div>
      {label && <span className="text-sm text-slate-300">{label}</span>}
    </label>
  );
}
