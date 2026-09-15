// Design System — Barrel Export (backward compatible)
// All 90+ files import from '@/lib/design-system'
// This re-exports everything from domain modules

export { ThemeProvider, useTheme, ToastProvider, useToast, Providers } from './providers';
export { PageLayout, SectionHeader, Divider } from './layout';
export { MetricCard, GlassCard, QuickTile } from './cards';

/** Allowed accent / color names for card components (see ./cards). */
export type { CardColor } from './cards';
export { Badge, ActionItem, EmptyState, DataTable, StatItem, Avatar } from './data';
export type { Column, ColumnRender, DataTableProps } from './data';
export { Button, Input, Toggle, Tabs } from './forms';
export { LoadingSpinner } from './feedback';

// CSS Variables
export function applyDesignTokens() {
  if (typeof document !== 'undefined') {
    document.documentElement.classList.add('wos-theme');
  }
}
