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

describe('pathInArea', () => {
  it('accepts exact area path in every area', async () => {
    const { pathInArea } = await import('../../src/lib/menu-builder.js');
    expect(pathInArea('/owner', 'owner')).toBe(true);
    expect(pathInArea('/admin', 'admin')).toBe(true);
    expect(pathInArea('/dashboard', 'dashboard')).toBe(true);
    expect(pathInArea('/worker', 'worker')).toBe(true);
  });

  it('accepts nested paths within the area', async () => {
    const { pathInArea } = await import('../../src/lib/menu-builder.js');
    expect(pathInArea('/owner/config', 'owner')).toBe(true);
    expect(pathInArea('/admin/payroll', 'admin')).toBe(true);
    expect(pathInArea('/dashboard/team', 'dashboard')).toBe(true);
    expect(pathInArea('/worker/leave', 'worker')).toBe(true);
  });

  it('rejects paths from other areas', async () => {
    const { pathInArea } = await import('../../src/lib/menu-builder.js');
    expect(pathInArea('/admin/kpi', 'worker')).toBe(false);
    expect(pathInArea('/worker/leave', 'admin')).toBe(false);
    expect(pathInArea('/admin/kpi', 'dashboard')).toBe(false);
    expect(pathInArea('/worker/leave', 'owner')).toBe(false);
  });

  it('rejects modules without a usable path', async () => {
    const { pathInArea } = await import('../../src/lib/menu-builder.js');
    expect(pathInArea('', 'worker')).toBe(false);
    expect(pathInArea(null, 'worker')).toBe(false);
    expect(pathInArea('#', 'worker')).toBe(false);
  });

  it('treats prefix collisions correctly (not startsWith bugs)', async () => {
    const { pathInArea } = await import('../../src/lib/menu-builder.js');
    // '/adminxyz' bukan area admin, '/workerfoo' bukan area worker
    expect(pathInArea('/adminxyz', 'admin')).toBe(false);
    expect(pathInArea('/workerfoo', 'worker')).toBe(false);
  });
});

describe('drawerPathInArea', () => {
  it('behaves identically to pathInArea outside the worker area', async () => {
    const { pathInArea, drawerPathInArea } = await import('../../src/lib/menu-builder.js');
    expect(drawerPathInArea('/admin/payroll', 'admin')).toBe(pathInArea('/admin/payroll', 'admin'));
    expect(drawerPathInArea('/worker/leave', 'admin')).toBe(pathInArea('/worker/leave', 'admin'));
    expect(drawerPathInArea('/dashboard', 'dashboard')).toBe(true);
  });

  it('worker area also shows dashboard links (manager browsing worker pages)', async () => {
    const { drawerPathInArea } = await import('../../src/lib/menu-builder.js');
    expect(drawerPathInArea('/dashboard', 'worker')).toBe(true);
    expect(drawerPathInArea('/dashboard/team', 'worker')).toBe(true);
    expect(drawerPathInArea('/worker/leave', 'worker')).toBe(true);
  });

  it('worker area still rejects admin and owner links', async () => {
    const { drawerPathInArea } = await import('../../src/lib/menu-builder.js');
    expect(drawerPathInArea('/admin/kpi', 'worker')).toBe(false);
    expect(drawerPathInArea('/owner', 'worker')).toBe(false);
  });
});

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
