// Design System — Layout Components
import { type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';

interface PageLayoutProps {
  title?: string;
  subtitle?: string;
  backTo?: string;
  children: ReactNode;
  transparent?: boolean;
  className?: string;
}

export function PageLayout({ title, subtitle, backTo, children, transparent, className = '' }: PageLayoutProps) {
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

interface BackButtonProps {
  to: string;
}

function BackButton({ to }: BackButtonProps) {
  const navigate = useNavigate();
  return (
    <button onClick={() => navigate(to)} className="flex items-center justify-center w-8 h-8 rounded-xl bg-white/5 hover:bg-white/10 text-slate-400 hover:text-white transition-all active:scale-95">
      ←
    </button>
  );
}

interface SectionHeaderProps {
  title: string;
  action?: ReactNode;
  icon?: string;
}

export function SectionHeader({ title, action, icon }: SectionHeaderProps) {
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

interface DividerProps {
  className?: string;
}

export function Divider({ className = '' }: DividerProps) {
  return <div className={`border-t border-white/5 ${className}`} />;
}
