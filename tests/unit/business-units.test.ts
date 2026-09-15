import { describe, it, expect, vi } from 'vitest';

vi.mock('../../src/lib/supabase-browser.js', () => ({
  getSession: vi.fn(() => ({ nrp: 'NRP001', role: 'worker', business_unit: 'MINING', role_level: 3 })),
  supabase: { rpc: vi.fn() },
}));

describe('Business Units', () => {
  it('MINING_MODULES has correct structure', async () => {
    const { MINING_MODULES } = await import('../../src/lib/business-units.js');
    expect(typeof MINING_MODULES).toBe('object');
    expect(Object.keys(MINING_MODULES).length).toBeGreaterThan(0);
  });

  it('ESTATE_MODULES has correct structure', async () => {
    const { ESTATE_MODULES } = await import('../../src/lib/business-units.js');
    expect(typeof ESTATE_MODULES).toBe('object');
    expect(Object.keys(ESTATE_MODULES).length).toBeGreaterThan(0);
  });

  it('MILL_MODULES has correct structure', async () => {
    const { MILL_MODULES } = await import('../../src/lib/business-units.js');
    expect(typeof MILL_MODULES).toBe('object');
    expect(Object.keys(MILL_MODULES).length).toBeGreaterThan(0);
  });

  it('BU_MODULES contains all business units', async () => {
    const { BU_MODULES } = await import('../../src/lib/business-units.js');
    expect(typeof BU_MODULES).toBe('object');
    expect(BU_MODULES).toHaveProperty('MINING');
    expect(BU_MODULES).toHaveProperty('ESTATE');
    expect(BU_MODULES).toHaveProperty('MILL');
  });

  it('getBusinessUnit returns session BU', async () => {
    const { getBusinessUnit } = await import('../../src/lib/business-units.js');
    const bu = getBusinessUnit();
    expect(typeof bu).toBe('string');
  });

  it('getRoleLevel returns session role level', async () => {
    const { getRoleLevel } = await import('../../src/lib/business-units.js');
    const level = getRoleLevel();
    expect(typeof level).toBe('number');
    expect(level).toBeGreaterThan(0);
  });
});
