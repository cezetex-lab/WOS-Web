// Design System — Card Components

export function MetricCard({ icon, value, label, trend, color = 'blue', loading, onClick }) {
  const colors = { blue: 'from-blue-500/20 to-blue-600/5 border-blue-500/20', teal: 'from-teal-500/20 to-teal-600/5 border-teal-500/20', orange: 'from-orange-500/20 to-orange-600/5 border-orange-500/20', red: 'from-red-500/20 to-red-600/5 border-red-500/20', purple: 'from-purple-500/20 to-purple-600/5 border-purple-500/20', green: 'from-emerald-500/20 to-emerald-600/5 border-emerald-500/20', slate: 'from-slate-500/20 to-slate-600/5 border-slate-500/20' };
  const trendColors = { blue: 'text-blue-400 bg-blue-400/15', teal: 'text-teal-400 bg-teal-400/15', orange: 'text-orange-400 bg-orange-400/15', red: 'text-red-400 bg-red-400/15', purple: 'text-purple-400 bg-purple-400/15', green: 'text-emerald-400 bg-emerald-400/15', slate: 'text-slate-400 bg-slate-400/15' };
  if (loading) return <div className="animate-pulse bg-slate-700/30 rounded-2xl h-28 border border-white/5" />;
  return (
    <div onClick={onClick} className={`bg-gradient-to-br ${colors[color]} backdrop-blur-sm border rounded-2xl p-4 shadow-lg transition-all duration-200 ${onClick ? 'cursor-pointer hover:scale-[1.02] hover:shadow-xl active:scale-[0.98]' : ''}`}>
      <div className="flex items-start justify-between">
        <span className="text-2xl">{icon}</span>
        {trend && <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${trendColors[color]}`}>{trend}</span>}
      </div>
      <div className="mt-2">
        <div className="text-2xl font-bold text-white tracking-tight">{value}</div>
        <div className="text-[10px] text-slate-400 font-semibold uppercase tracking-wider mt-0.5">{label}</div>
      </div>
    </div>
  );
}

export function GlassCard({ title, icon, accent = 'teal', children, className = '', actions }) {
  const accents = { teal: 'border-l-teal-400', blue: 'border-l-blue-400', orange: 'border-l-orange-400', red: 'border-l-red-400', purple: 'border-l-purple-400', green: 'border-l-emerald-400', slate: 'border-l-slate-400' };
  return (
    <div className={`bg-slate-800/40 backdrop-blur-md rounded-2xl p-5 border border-white/5 border-l-4 ${accents[accent]} shadow-xl transition-all duration-200 hover:bg-slate-800/50 ${className}`}>
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

export function QuickTile({ icon, label, color = 'slate', onClick, badge }) {
  const bgColors = { slate: 'bg-slate-700/40 hover:bg-slate-600/50', blue: 'bg-blue-500/15 hover:bg-blue-500/25', teal: 'bg-teal-500/15 hover:bg-teal-500/25', orange: 'bg-orange-500/15 hover:bg-orange-500/25', purple: 'bg-purple-500/15 hover:bg-purple-500/25', green: 'bg-emerald-500/15 hover:bg-emerald-500/25', red: 'bg-red-500/15 hover:bg-red-500/25' };
  return (
    <button onClick={onClick} className={`relative flex flex-col items-center justify-center p-3 rounded-2xl ${bgColors[color]} backdrop-blur-sm border border-white/5 transition-all duration-200 hover:border-white/15 active:scale-95`}>
      <span className="text-2xl mb-1">{icon}</span>
      <span className="text-[10px] font-medium text-slate-300 text-center leading-tight">{label}</span>
      {badge > 0 && <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] flex items-center justify-center bg-red-500 text-white text-[9px] font-bold rounded-full px-1">{badge > 99 ? '99+' : badge}</span>}
    </button>
  );
}
