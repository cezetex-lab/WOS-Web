import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock sessionStorage
const mockStorage: Record<string, string> = {};
const sessionStorageMock = {
  getItem: vi.fn((key: string) => mockStorage[key] || null),
  setItem: vi.fn((key: string, value: string) => { mockStorage[key] = value; }),
  removeItem: vi.fn((key: string) => { delete mockStorage[key]; }),
  clear: vi.fn(() => { Object.keys(mockStorage).forEach(k => delete mockStorage[k]); }),
};

Object.defineProperty(globalThis, 'sessionStorage', { value: sessionStorageMock });
Object.defineProperty(globalThis, 'window', { value: { sessionStorage: sessionStorageMock } });

// Kontrak sesi v2 (audit S6/S7/S9): key baru, wajib `expires_at`, tanpa `token`,
// dan `entry` selalu terisi. Sesi skema lama (`wos_user`) diabaikan & dibersihkan.
const KEY = 'wos_user_v2';
const LEGACY_KEY = 'wos_user';
const FUTURE = new Date(Date.now() + 3_600_000).toISOString();
const PAST = new Date(Date.now() - 3_600_000).toISOString();

describe('Session Management', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.keys(mockStorage).forEach(k => delete mockStorage[k]);
  });

  it('setSession menyimpan sesi v2 dengan entry + expires_at yang distempel', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');

    setSession({ nrp: 'NRP001', nama: 'Test User', role: 'worker', role_level: 1, business_unit_id: 'BU-HQ' });

    const stored = JSON.parse(mockStorage[KEY]);
    expect(stored).toMatchObject({ nrp: 'NRP001', nama: 'Test User', role: 'worker' });
    expect(stored.entry).toBe('worker'); // diturunkan dari role (satu choke point)
    expect(new Date(stored.expires_at).getTime()).toBeGreaterThan(Date.now());
    expect(mockStorage[LEGACY_KEY]).toBeUndefined(); // skema lama tidak ditulis lagi
    expect(stored.token).toBeUndefined(); // token app-level tidak dipersist lagi
  });

  it('setSession mempertahankan entry eksplisit dan expires_at dari server', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');

    setSession({
      nrp: 'NRP001', nama: 'Admin', role: 'admin_pusat', role_level: 4,
      business_unit_id: 'BU-HQ', entry: 'admin', expires_at: FUTURE,
    });

    const stored = JSON.parse(mockStorage[KEY]);
    expect(stored.entry).toBe('admin');
    expect(stored.expires_at).toBe(FUTURE);
  });

  it('entry diturunkan dari role saat pemanggil tidak menyetelnya', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');

    const cases: Array<[Record<string, unknown>, string]> = [
      [{ role: 'admin_hrd' }, 'admin'],
      [{ role: 'manager' }, 'dashboard'],
      [{ role: 'owner' }, 'owner'],
      [{ role: 'worker' }, 'worker'],
      [{ role: 'worker', is_owner: true }, 'owner'],
    ];
    for (const [partial, expected] of cases) {
      setSession({ nrp: 'NRP001', nama: 'X', role_level: 0, business_unit_id: 'BU-HQ', ...partial } as never);
      expect(JSON.parse(mockStorage[KEY]).entry).toBe(expected);
    }
  });

  it('getSession mengembalikan sesi valid apa adanya', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    const user = { nrp: 'NRP001', nama: 'Test User', role: 'worker', entry: 'worker', expires_at: FUTURE };

    mockStorage[KEY] = JSON.stringify(user);

    expect(getSession()).toEqual(user);
  });

  it('FAIL-CLOSED: getSession menolak sesi tanpa expires_at', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = JSON.stringify({ nrp: 'NRP001', nama: 'Test User' });

    expect(getSession()).toBeNull();
    expect(mockStorage[KEY]).toBeUndefined(); // sesi tanpa batas umur langsung dibuang
  });

  it('getSession menolak sesi yang sudah kedaluwarsa', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = JSON.stringify({ nrp: 'NRP001', nama: 'Test User', entry: 'worker', expires_at: PAST });

    expect(getSession()).toBeNull();
    expect(mockStorage[KEY]).toBeUndefined();
  });

  it('getSession menolak expires_at yang tidak bisa diparse', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = JSON.stringify({ nrp: 'NRP001', expires_at: 'bukan-tanggal', entry: 'worker' });

    expect(getSession()).toBeNull();
  });

  it('getSession mengabaikan + membersihkan sesi skema lama (wos_user)', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[LEGACY_KEY] = JSON.stringify({ nrp: 'NRP001', token: 'legacy-token' });

    expect(getSession()).toBeNull();
    expect(mockStorage[LEGACY_KEY]).toBeUndefined();
  });

  it('getSession mengembalikan null saat tidak ada sesi', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');

    expect(getSession()).toBeNull();
  });

  it('clearSession menghapus sesi v2 (dan membersihkan kunci lama)', async () => {
    const { clearSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = JSON.stringify({ nrp: 'NRP001', entry: 'worker', expires_at: FUTURE });
    mockStorage[LEGACY_KEY] = JSON.stringify({ nrp: 'NRP001' });

    clearSession();

    expect(sessionStorageMock.removeItem).toHaveBeenCalledWith(KEY);
    expect(mockStorage[KEY]).toBeUndefined();
    expect(mockStorage[LEGACY_KEY]).toBeUndefined();
  });

  it('getSession menangani JSON rusak tanpa throw', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = 'NOT VALID JSON';

    expect(() => getSession()).not.toThrow();
    expect(getSession()).toBeNull();
  });
});
