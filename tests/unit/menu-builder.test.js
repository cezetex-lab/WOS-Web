import { describe, it, expect, vi } from 'vitest';

vi.mock('../../src/lib/supabase-browser.js', () => ({
  getSession: vi.fn(() => ({ nrp: 'NRP001', role: 'worker', role_level: 3 })),
  supabase: { 
    rpc: vi.fn().mockResolvedValue({ data: [
      { module_code: 'mining_simper', module_name: 'SIMPER', module_group: 'MINING', menu_icon: '⛏️', is_industry_module: true, menu_order: 1 },
      { module_code: 'attendance', module_name: 'Attendance', module_group: 'HR', menu_icon: '📅', is_industry_module: false, menu_order: 2 },
    ], error: null })
  },
}));

describe('Menu Builder', () => {
  it('buildMenu returns array of menu items', async () => {
    const { buildMenu } = await import('../../src/lib/menu-builder.js');
    const menu = await buildMenu();
    expect(Array.isArray(menu)).toBe(true);
    expect(menu.length).toBeGreaterThan(0);
  });

  it('buildMenu items have required fields', async () => {
    const { buildMenu } = await import('../../src/lib/menu-builder.js');
    const menu = await buildMenu();
    const item = menu[0];
    expect(item).toHaveProperty('code');
    expect(item).toHaveProperty('name');
    expect(item).toHaveProperty('group');
    expect(item).toHaveProperty('icon');
    expect(item).toHaveProperty('path');
  });

  it('buildMenu returns empty array on error', async () => {
    const { supabase } = await import('../../src/lib/supabase-browser.js');
    supabase.rpc.mockResolvedValueOnce({ data: null, error: { message: 'fail' } });
    const { buildMenu } = await import('../../src/lib/menu-builder.js');
    const menu = await buildMenu();
    expect(menu).toEqual([]);
  });
});
