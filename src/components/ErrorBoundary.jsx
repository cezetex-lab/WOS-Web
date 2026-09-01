import { Component } from 'react';

// Per-domain ErrorBoundary — catches errors within a domain module
// without crashing the entire app
export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary caught:', error, errorInfo);
    this.setState({ errorInfo });
    // Report to PostHog if available
    try {
      if (window.posthog) {
        window.posthog.capture('error_boundary', {
          message: error.message,
          stack: error.stack?.substring(0, 500),
          component: this.props.fallbackName || 'unknown',
        });
      }
    } catch (_) {}
  }

  render() {
    if (this.state.hasError) {
      const name = this.props.fallbackName || 'Module';
      return (
        <div className="min-h-[200px] flex items-center justify-center bg-slate-900/50 rounded-2xl border border-slate-700/50 p-6 m-2">
          <div className="max-w-sm w-full text-center">
            <div className="text-4xl mb-3">⚠️</div>
            <h2 className="text-lg font-bold text-white mb-1">{name} Error</h2>
            <p className="text-slate-400 text-xs mb-4">
              {this.state.error?.message || 'Module error'}
            </p>
            <div className="flex gap-2 justify-center">
              <button
                onClick={() => this.setState({ hasError: false, error: null })}
                className="px-4 py-2 bg-sky-600 hover:bg-sky-500 text-white text-sm rounded-xl transition-colors"
              >
                🔄 Retry
              </button>
              <button
                onClick={() => window.location.reload()}
                className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white text-sm rounded-xl transition-colors"
              >
                Reload Page
              </button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

// HOC: wraps any component with ErrorBoundary
export function withErrorBoundary(WrappedComponent, name) {
  return function ErrorBoundaryWrapper(props) {
    return (
      <ErrorBoundary fallbackName={name || WrappedComponent.displayName || WrappedComponent.name}>
        <WrappedComponent {...props} />
      </ErrorBoundary>
    );
  };
}
