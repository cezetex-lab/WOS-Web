// Design System — Layout Components
import { useNavigate } from 'react-router-dom';

export function PageLayout({ title, subtitle, backTo, children, transparent, className = '' }) {
  return (
    <div className={`min-h-screen ${transparent ? '' : 'bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900'} ${className}`}>
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
      <div className={`max-w-7xl mx-auto px-4 py-4 pb-24`}>
        {children}
      </div>
    </div>
  );
}

function BackButton({ to }) {
  const navigate = useNavigate();
  return (
    <button onClick={() => navigate(to)} className="flex items-center justify-center w-8 h-8 rounded-xl bg-white/5 hover:bg-white/10 text-slate-400 hover:text-white transition-all active:scale-95">
      ←
    </button>
  );
}

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

export function Divider({ className = '' }) {
  return <div className={`border-t border-white/5 ${className}`} />;
}
