// Design System — Data Display Components
import { useState, useEffect } from 'react';

export function Badge({ status, type = 'default', className = '' }) {
  const types = { default: 'bg-slate-500/20 text-slate-300 border-slate-500/30', success: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30', warning: 'bg-amber-500/20 text-amber-300 border-amber-500/30', danger: 'bg-red-500/20 text-red-300 border-red-500/30', info: 'bg-blue-500/20 text-blue-300 border-blue-500/30' };
  return <span className={`inline-flex items-center text-[11px] font-bold px-2 py-0.5 rounded-full border ${types[type]} ${className}`}>{status}</span>;
}

export function ActionItem({ title, subtitle, date, badge, badgeType = 'warning', onClick }) {
  return (
    <div onClick={onClick} className={`flex items-center justify-between p-3 bg-slate-900/40 rounded-xl border border-white/5 transition-all duration-200 ${onClick ? 'hover:border-white/10 hover:bg-slate-800/40 cursor-pointer active:scale-[0.99]' : ''}`}>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-white truncate">{title}</span>
          {badge && <Badge status={badge} type={badgeType} />}
        </div>
        {subtitle && <p className="text-xs text-slate-400 truncate mt-0.5">{subtitle}</p>}
        {date && <p className="text-[11px] text-slate-500 mt-0.5">{new Date(date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}</p>}
      </div>
      <svg className="w-4 h-4 text-slate-500 flex-shrink-0 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
    </div>
  );
}

export function EmptyState({ icon = '📭', title = 'Tidak ada data', subtitle }) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <span className="text-4xl mb-3">{icon}</span>
      <p className="text-sm font-semibold text-slate-300">{title}</p>
      {subtitle && <p className="text-xs text-slate-500 mt-1">{subtitle}</p>}
    </div>
  );
}

export function DataTable({ columns = [], data = [], searchPlaceholder = 'Cari...', onRowClick, emptyMessage = 'Tidak ada data', loading }) {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const perPage = 10;
  const filtered = data.filter(row => { if (!search) return true; const q = search.toLowerCase(); return columns.some(col => String(row[col.key] || '').toLowerCase().includes(q)); });
  const totalPages = Math.ceil(filtered.length / perPage);
  const paged = filtered.slice(page * perPage, (page + 1) * perPage);
  useEffect(() => { setPage(0); }, [search]);
  if (loading) return <div className="space-y-2">{[1, 2, 3].map(i => <div key={i} className="animate-pulse bg-slate-700/30 h-12 rounded-xl" />)}</div>;
  return (
    <div>
      <div className="flex items-center gap-2 bg-slate-800/50 rounded-xl px-3 py-2.5 border border-white/5 mb-3">
        <svg className="w-4 h-4 text-slate-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
        <input type="text" placeholder={searchPlaceholder} value={search} onChange={e => setSearch(e.target.value)} className="flex-1 bg-transparent text-sm text-white placeholder-slate-500 outline-none" />
        {search && <button onClick={() => setSearch('')} className="text-slate-500 hover:text-white text-xs">✕</button>}
      </div>
      <div className="overflow-x-auto -mx-4 px-4">
        <table className="w-full text-sm">
          <thead><tr className="border-b border-white/5">{columns.map(col => <th key={col.key} className="text-left text-[11px] font-bold text-slate-400 uppercase tracking-wider py-2 px-2">{col.label}</th>)}</tr></thead>
          <tbody>{paged.length === 0 ? <tr><td colSpan={columns.length} className="text-center py-8 text-slate-500 text-xs">{emptyMessage}</td></tr> : paged.map((row, i) => <tr key={row.id || i} onClick={() => onRowClick?.(row)} className={`border-b border-white/3 transition-colors ${onRowClick ? 'cursor-pointer hover:bg-white/3 active:bg-white/5' : ''}`}>{columns.map(col => <td key={col.key} className="py-2.5 px-2 text-slate-300 text-xs">{col.render ? col.render(row[col.key], row) : row[col.key]}</td>)}</tr>)}</tbody>
        </table>
      </div>
      {totalPages > 1 && <div className="flex items-center justify-between mt-3 pt-3 border-t border-white/5"><span className="text-[11px] text-slate-500">{filtered.length} data • Hal {page + 1}/{totalPages}</span><div className="flex gap-1"><button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0} className="px-2 py-1 rounded-lg text-[11px] font-bold bg-white/5 text-slate-400 disabled:opacity-30 hover:bg-white/10 transition-all">←</button><button onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))} disabled={page >= totalPages - 1} className="px-2 py-1 rounded-lg text-[11px] font-bold bg-white/5 text-slate-400 disabled:opacity-30 hover:bg-white/10 transition-all">→</button></div></div>}
    </div>
  );
}

export function StatItem({ label, value, max = 100, color = '#38bdf8', suffix = '' }) {
  const pct = Math.min((value / Math.max(max, 1)) * 100, 100);
  return (
    <div className="p-3 bg-slate-900/40 rounded-xl border border-white/5">
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-xs text-slate-400">{label}</span>
        <span className="text-sm font-bold text-white">{value}{suffix}</span>
      </div>
      <div className="h-1.5 bg-slate-700/50 rounded-full overflow-hidden">
        <div className="h-full rounded-full transition-all duration-700 ease-out" style={{ width: `${pct}%`, background: color }} />
      </div>
    </div>
  );
}

export function Avatar({ name = '', size = 'md', src, className = '' }) {
  const sizes = { sm: 'w-8 h-8 text-xs', md: 'w-10 h-10 text-sm', lg: 'w-14 h-14 text-lg' };
  const initial = (name || '?')[0].toUpperCase();
  return <div className={`${sizes[size]} rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center font-bold text-white border-2 border-teal-400/50 flex-shrink-0 ${className}`}>{src ? <img src={src} alt={name} className="w-full h-full rounded-full object-cover" /> : initial}</div>;
}
