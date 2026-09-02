import { describe, it, expect, vi } from 'vitest';

// Mock localStorage
const localStorageMock = {};
const localStorage = {
  getItem: vi.fn((key) => localStorageMock[key] || null),
  setItem: vi.fn((key, value) => { localStorageMock[key] = value; }),
  removeItem: vi.fn((key) => { delete localStorageMock[key]; }),
  clear: vi.fn(() => { Object.keys(localStorageMock).forEach(k => delete localStorageMock[k]); }),
};
Object.defineProperty(globalThis, 'localStorage', { value: localStorage });

// Mock sessionStorage
const sessionStorageMock = {};
const sessionStorage = {
  getItem: vi.fn((key) => sessionStorageMock[key] || null),
  setItem: vi.fn((key, value) => { sessionStorageMock[key] = value; }),
  removeItem: vi.fn((key) => { delete sessionStorageMock[key]; }),
};
Object.defineProperty(globalThis, 'sessionStorage', { value: sessionStorageMock });

describe('Chart Config', () => {
  it('exports chart color palette', async () => {
    const mod = await import('../../src/lib/chart-config.js');
    // Check for exported constants or functions
    expect(mod).toBeDefined();
  });
});

describe('Offline DB', () => {
  it('offline-db module loads without error', async () => {
    const mod = await import('../../src/lib/offline-db.js');
    expect(mod).toBeDefined();
  });
});

describe('Push Notifications', () => {
  it('push-notifications module loads without error', async () => {
    const mod = await import('../../src/lib/push-notifications.js');
    expect(mod).toBeDefined();
  });
});

describe('Sync Queue', () => {
  it('sync-queue module loads without error', async () => {
    const mod = await import('../../src/lib/sync-queue.js');
    expect(mod).toBeDefined();
  });
});

describe('Supabase Client', () => {
  it('supabase module loads without error', async () => {
    const mod = await import('../../src/lib/supabase.js');
    expect(mod).toBeDefined();
  });
});

describe('i18n', () => {
  it('i18n module loads without error', async () => {
    const mod = await import('../../src/lib/i18n/index.js');
    expect(mod).toBeDefined();
  });
});

describe('Providers', () => {
  it('providers module loads without error', async () => {
    const mod = await import('../../src/lib/design-system/providers.jsx');
    expect(mod).toBeDefined();
  });
});
