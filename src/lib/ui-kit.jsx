// src/lib/ui-kit.jsx
// ============================================================
// MASTER UI KIT - Mobile First, Glassmorphism, Professional
// ============================================================
import React from 'react';

// Ikon SVG Minimalis (Tidak perlu install library tambahan)
const Icons = {
  Users: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>,
  Chart: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>,
  Alert: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>,
  Home: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>,
  Briefcase: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>,
  User: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>,
  Menu: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" /></svg>,
  X: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>,
  ArrowRight: (p) => <svg {...p} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
};

// === 1. METRIC CARD ===
export function MetricCard({ icon, value, label, trend, color = 'blue', loading }) {
  const colors = {
    blue: 'from-blue-500/20 to-blue-600/10 border-blue-500/30',
    teal: 'from-teal-500/20 to-teal-600/10 border-teal-500/30',
    orange: 'from-orange-500/20 to-orange-600/10 border-orange-500/30',
    red: 'from-red-500/20 to-red-600/10 border-red-500/30',
    purple: 'from-purple-500/20 to-purple-600/10 border-purple-500/30'
  };
  if (loading) return <div className="animate-pulse bg-slate-700/50 h-24 rounded-2xl"></div>;
  return (
    <div className={`bg-gradient-to-br ${colors[color]} backdrop-blur-sm border ${colors[color]} rounded-2xl p-4 shadow-lg hover:scale-[1.02] transition-all duration-200`}>
      <div className="flex items-start justify-between">
        <div className="text-2xl opacity-80">{icon}</div>
        <span className="text-xs font-medium text-emerald-400 bg-emerald-400/20 px-2 py-0.5 rounded-full">{trend}</span>
      </div>
      <div className="mt-2">
        <div className="text-2xl font-bold text-white tracking-tight">{value}</div>
        <div className="text-xs text-slate-400 font-medium uppercase tracking-wider">{label}</div>
      </div>
    </div>
  );
}

// === 2. QUICK ACCESS TILE ===
export function QuickTile({ icon, label, onClick, color = 'slate' }) {
  const bgColors = {
    slate: 'bg-slate-700/50 hover:bg-slate-600/50',
    blue: 'bg-blue-600/20 hover:bg-blue-500/30',
    teal: 'bg-teal-600/20 hover:bg-teal-500/30',
    orange: 'bg-orange-600/20 hover:bg-orange-500/30',
    purple: 'bg-purple-600/20 hover:bg-purple-500/30'
  };
  return (
    <button onClick={onClick} className={`flex flex-col items-center justify-center p-3 rounded-2xl ${bgColors[color]} backdrop-blur-sm border border-white/5 transition-all duration-200 hover:border-white/20 active:scale-95`}>
      <span className="text-2xl mb-1">{icon}</span>
      <span className="text-[10px] font-medium text-slate-300 text-center leading-tight">{label}</span>
    </button>
  );
}

// === 3. GLASS CARD (Untuk Insight / Narasi) ===
export function GlassCard({ title, children, icon, className, accent = 'teal' }) {
  const accentColors = {
    teal: 'border-l-4 border-teal-400',
    blue: 'border-l-4 border-blue-400',
    orange: 'border-l-4 border-orange-400',
    red: 'border-l-4 border-red-400'
  };
  return (
    <div className={`bg-slate-800/40 backdrop-blur-md rounded-2xl p-5 border border-white/5 shadow-xl ${accentColors[accent]} ${className}`}>
      {title && (
        <div className="flex items-center gap-2 mb-3">
          <span className="text-lg">{icon}</span>
          <h3 className="text-sm font-bold text-white/90 tracking-wide">{title}</h3>
        </div>
      )}
      <div className="text-slate-200 text-sm leading-relaxed">{children}</div>
    </div>
  );
}

// === 4. BADGE STATUS ===
export function Badge({ status, type = 'warning' }) {
  const types = {
    warning: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30',
    danger: 'bg-red-500/20 text-red-300 border-red-500/30',
    success: 'bg-green-500/20 text-green-300 border-green-500/30',
    info: 'bg-blue-500/20 text-blue-300 border-blue-500/30'
  };
  return <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${types[type]}`}>{status}</span>;
}

// === 5. ACTION LIST ITEM (Untuk Perlu Tindakan) ===
export function ActionItem({ title, subtitle, date, status, onClick }) {
  return (
    <div className="flex items-center justify-between p-3 bg-slate-900/50 rounded-xl border border-white/5 hover:border-white/10 transition-all cursor-pointer" onClick={onClick}>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-white truncate">{title}</span>
          <Badge status={status} type={status === 'HIGH' ? 'danger' : 'warning'} />
        </div>
        <p className="text-xs text-slate-400 truncate">{subtitle}</p>
        <p className="text-[10px] text-slate-500 mt-0.5">{new Date(date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}</p>
      </div>
      <Icons.ArrowRight className="w-4 h-4 text-slate-500 flex-shrink-0" />
    </div>
  );
}