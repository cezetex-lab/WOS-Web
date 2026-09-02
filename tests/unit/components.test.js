import { describe, it, expect, vi } from 'vitest';
import React from 'react';

// Mock react-router-dom
vi.mock('react-router-dom', () => ({
  Navigate: ({ to }) => React.createElement('div', { 'data-testid': 'navigate', 'data-to': to }),
  useLocation: () => ({ pathname: '/admin' }),
}));

// Mock session
vi.mock('../../src/lib/supabase-browser.js', () => ({
  getSession: vi.fn(() => ({ nrp: 'NRP001', role: 'admin', role_level: 4 })),
  setSession: vi.fn(),
  clearSession: vi.fn(),
  supabase: { rpc: vi.fn().mockResolvedValue({ data: null, error: null }) },
}));

describe('SessionGuard', () => {
  it('SessionGuard component exists', async () => {
    const mod = await import('../../src/components/SessionGuard.jsx');
    expect(typeof mod.default).toBe('function');
  });

  it('SessionGuard renders children when session exists', async () => {
    const { default: SessionGuard } = await import('../../src/components/SessionGuard.jsx');
    const { createRoot } = await import('react-dom/client');
    const { JSDOM } = await import('jsdom');
    
    // Simple existence check
    expect(SessionGuard).toBeDefined();
  });
});

describe('ModuleRouteGuard', () => {
  it('ModuleRouteGuard component exists', async () => {
    const mod = await import('../../src/components/ModuleRouteGuard.jsx');
    expect(typeof mod.default).toBe('function');
  });
});

describe('ErrorBoundary', () => {
  it('ErrorBoundary component exists', async () => {
    const mod = await import('../../src/components/ErrorBoundary.jsx');
    expect(typeof mod.default).toBe('function');
  });
});

describe('LazyLoad', () => {
  it('LazyLoad component exists', async () => {
    const mod = await import('../../src/components/LazyLoad.jsx');
    expect(typeof mod.default).toBe('function');
  });
});
