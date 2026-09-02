// Design System — Form Components
import { useState } from 'react';

export function Badge({ status, type = 'default', className = '' }) {
  const types = { default: 'bg-slate-500/20 text-slate-300 border-slate-500/30', success: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30', warning: 'bg-amber-500/20 text-amber-300 border-amber-500/30', danger: 'bg-red-500/20 text-red-300 border-red-500/30', info: 'bg-blue-500/20 text-blue-300 border-blue-500/30' };
  return <span className={`inline-flex items-center text-[11px] font-bold px-2 py-0.5 rounded-full border ${types[type]} ${className}`}>{status}</span>;
}

export function Button({ children, color = 'teal', variant = 'solid', size = 'md', onClick, disabled, className = '', type = 'button', ariaLabel }) {
  const colors = { teal: 'bg-teal-500 hover:bg-teal-400 text-white', blue: 'bg-blue-500 hover:bg-blue-400 text-white', red: 'bg-red-500 hover:bg-red-400 text-white', orange: 'bg-orange-500 hover:bg-orange-400 text-white', purple: 'bg-purple-500 hover:bg-purple-400 text-white', slate: 'bg-slate-600 hover:bg-slate-500 text-white', ghost: 'bg-transparent hover:bg-white/10 text-slate-300' };
  const outlineColors = { teal: 'border-teal-500/50 text-teal-400 hover:bg-teal-500/10', blue: 'border-blue-500/50 text-blue-400 hover:bg-blue-500/10', red: 'border-red-500/50 text-red-400 hover:bg-red-500/10', orange: 'border-orange-500/50 text-orange-400 hover:bg-orange-500/10', slate: 'border-slate-500/50 text-slate-400 hover:bg-slate-500/10', ghost: 'border-transparent text-slate-400 hover:bg-white/10' };
  const sizes = { sm: 'px-3 py-1.5 text-xs rounded-lg', md: 'px-4 py-2.5 text-sm rounded-xl', lg: 'px-6 py-3 text-base rounded-xl' };
  return <button type={type} onClick={onClick} disabled={disabled} aria-label={ariaLabel} className={`font-semibold transition-all duration-200 active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-400/50 focus:ring-offset-2 focus:ring-offset-slate-900 ${variant === 'outline' ? `border ${outlineColors[color]}` : colors[color]} ${sizes[size]} ${disabled ? 'opacity-40 pointer-events-none' : ''} ${className}`}>{children}</button>;
}

export function Input({ label, placeholder, value, onChange, type = 'text', icon, error, className = '', id }) {
  const inputId = id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);
  const errorId = inputId ? `${inputId}-error` : undefined;
  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      {label && <label htmlFor={inputId} className="text-xs font-semibold text-slate-300">{label}</label>}
      <div className={`flex items-center gap-2 px-3 py-2.5 rounded-xl bg-slate-800/50 border transition-all ${error ? 'border-red-500/50' : 'border-white/5 focus-within:border-teal-500/50'}`}>
        {icon && <span className="text-base flex-shrink-0" aria-hidden="true">{icon}</span>}
        <input id={inputId} type={type} placeholder={placeholder} value={value} onChange={onChange} aria-invalid={!!error} aria-describedby={error ? errorId : undefined} className="flex-1 bg-transparent text-sm text-white placeholder-slate-500 outline-none focus:outline-none" />
      </div>
      {error && <span id={errorId} className="text-[11px] text-red-400" role="alert">{error}</span>}
    </div>
  );
}

export function Toggle({ checked, onChange, label }) {
  return (
    <label className="flex items-center gap-3 cursor-pointer">
      <div role="switch" aria-checked={checked} aria-label={label || 'Toggle'} tabIndex={0} onClick={() => onChange?.(!checked)} onKeyDown={(e) => { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); onChange?.(!checked); } }} className={`relative w-10 h-5 rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-teal-400/50 ${checked ? 'bg-teal-500' : 'bg-slate-600'}`}>
        <div className={`absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200 ${checked ? 'translate-x-5' : 'translate-x-0'}`} />
      </div>
      {label && <span className="text-sm text-slate-300">{label}</span>}
    </label>
  );
}

export function Tabs({ tabs = [], active, onChange, className = '' }) {
  return (
    <div role="tablist" className={`flex gap-1 p-1 bg-slate-800/50 rounded-xl border border-white/5 ${className}`}>
      {tabs.map(tab => (
        <button key={tab.id} role="tab" aria-selected={active === tab.id} tabIndex={active === tab.id ? 0 : -1} onClick={() => onChange(tab.id)} onKeyDown={(e) => { const idx = tabs.findIndex(t => t.id === active); if (e.key === 'ArrowRight') { e.preventDefault(); onChange(tabs[(idx + 1) % tabs.length].id); } else if (e.key === 'ArrowLeft') { e.preventDefault(); onChange(tabs[(idx - 1 + tabs.length) % tabs.length].id); } }} className={`flex-1 px-3 py-2 rounded-lg text-xs font-semibold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-teal-400/50 ${active === tab.id ? 'bg-teal-500/20 text-teal-400 shadow-sm' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>
          {tab.label}
          {tab.count !== undefined && <span className="ml-1 text-[11px] opacity-60">({tab.count})</span>}
        </button>
      ))}
    </div>
  );
}
