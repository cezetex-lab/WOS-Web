// Design System — Feedback Components

export function LoadingSpinner({ size = 'md', text, className = '' }) {
  const sizes = { sm: 'h-5 w-5', md: 'h-8 w-8', lg: 'h-12 w-12' };
  return (
    <div className={`flex flex-col items-center justify-center py-12 ${className}`}>
      <div className={`${sizes[size]} border-2 border-slate-600 border-t-teal-400 rounded-full animate-spin`} />
      {text && <p className="text-xs text-slate-400 mt-3">{text}</p>}
    </div>
  );
}
