import { describe, it, expect, vi } from 'vitest';

vi.mock('../../src/lib/supabase-browser.js', () => ({
  getSession: vi.fn(() => ({ nrp: 'NRP001', role: 'worker', role_level: 3, business_unit: 'MINING' })),
  supabase: { 
    rpc: vi.fn().mockResolvedValue({ 
      data: { has_access: true, tier: 4, role_level: 3, is_enabled: true },
      error: null 
    })
  },
}));

describe('useModuleAccess', () => {
  it('module exports functions', async () => {
    const mod = await import('../../src/hooks/useModuleAccess.js');
    expect(mod).toBeDefined();
  });

  it('exports useCurrentUserContext', async () => {
    const { useCurrentUserContext } = await import('../../src/hooks/useModuleAccess.js');
    expect(typeof useCurrentUserContext).toBe('function');
  });

  it('exports useEnabledModules', async () => {
    const { useEnabledModules } = await import('../../src/hooks/useModuleAccess.js');
    expect(typeof useEnabledModules).toBe('function');
  });
});
