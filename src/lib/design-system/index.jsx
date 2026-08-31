// Design System — Barrel Export (backward compatible)
// All 90+ files import from '@/lib/design-system'
// This re-exports everything from domain modules

export { ThemeProvider, useTheme, ToastProvider, useToast, Providers } from './providers';
export { PageLayout, SectionHeader, Divider } from './layout';
export { MetricCard, GlassCard, QuickTile } from './cards';
export { Badge, ActionItem, EmptyState, DataTable, StatItem, Avatar } from './data';
export { Button, Input, Toggle, Tabs } from './forms';
export { LoadingSpinner } from './feedback';

// CSS Variables
export function applyDesignTokens() {
  if (typeof document !== 'undefined') {
    document.documentElement.classList.add('wos-theme');
  }
}
