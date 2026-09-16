import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { rpc, isRpcError, supabase } from '../../src/lib/supabase-browser';

// Modul sesi menyentuh sessionStorage saat fungsinya dipanggil — sediakan stub.
const mockStorage: Record<string, string> = {};
Object.defineProperty(globalThis, 'sessionStorage', {
  value: {
    getItem: (k: string) => mockStorage[k] ?? null,
    setItem: (k: string, v: string) => { mockStorage[k] = v; },
    removeItem: (k: string) => { delete mockStorage[k]; },
    clear: () => { Object.keys(mockStorage).forEach((k) => delete mockStorage[k]); },
  },
});

type RpcResponse = Awaited<ReturnType<typeof supabase.rpc>>;

/**
 * Bentuk respons PostgREST minimal. Kolom teknis (count/status/hint/code/…) tidak
 * relevan untuk menguji kontrak `rpc()`, jadi cast-nya dikumpulkan DI SINI saja,
 * bukan disebar ke setiap assertion.
 */
const okRes = (data: unknown) =>
  ({ data, error: null, count: null, status: 200, statusText: 'OK' }) as unknown as RpcResponse;

const errRes = (message: string) =>
  ({
    data: null,
    error: { message, details: '', hint: '', code: 'MOCK', name: 'PostgrestError', toJSON: () => ({ message }) },
    count: null,
    status: 400,
    statusText: 'Bad Request',
  }) as unknown as RpcResponse;

/**
 * Kontrak `rpc()` (audit L1). Sebelumnya kegagalan dikembalikan sebagai
 * `{ ok:false, msg } as T`, sehingga pemanggil yang mengharap array/objek
 * menerima bentuk salah TANPA error tipe. Sekarang: berhasil = payload apa adanya,
 * gagal = `RpcError` dengan `kind` eksplisit.
 */
describe('Kontrak rpc() — hasil dan kegagalan dibedakan', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
    vi.restoreAllMocks();
  });

  it('sukses: payload dikembalikan apa adanya', async () => {
    vi.spyOn(supabase, 'rpc').mockResolvedValue(okRes({ nrp: 'NRP001' }));

    await expect(rpc('contract_ok')).resolves.toEqual({ nrp: 'NRP001' });
  });

  it('sukses dengan nilai falsy (`false`) TIDAK diubah menjadi error palsu', async () => {
    // Regresi: versi lama memakai `data || { ok:false, ... }`, jadi `false` yang sah
    // (mis. dari check_module_access) berubah menjadi error.
    vi.spyOn(supabase, 'rpc').mockResolvedValue(okRes(false));

    await expect(rpc('contract_false')).resolves.toBe(false);
  });

  it('gagal transport → RpcError kind "transport"', async () => {
    vi.spyOn(supabase, 'rpc').mockResolvedValue(errRes('boom'));

    const res = await rpc('contract_transport');

    expect(isRpcError(res)).toBe(true);
    expect(res).toMatchObject({ ok: false, msg: 'boom', kind: 'transport' });
  });

  it('tanpa data sama sekali → RpcError kind "no_response"', async () => {
    vi.spyOn(supabase, 'rpc').mockResolvedValue(okRes(null));

    const res = await rpc('contract_empty');

    expect(isRpcError(res)).toBe(true);
    expect(res).toMatchObject({ ok: false, kind: 'no_response' });
  });

  it('rate limit → RpcError kind "rate_limited" dan panggilan TIDAK menembus network', async () => {
    const spy = vi.spyOn(supabase, 'rpc').mockResolvedValue(okRes('x'));
    const fn = `contract_ratelimit_${Date.now()}`;

    for (let i = 0; i < 30; i++) await rpc(fn); // habiskan limit default (30)
    const res = await rpc(fn);

    expect(isRpcError(res)).toBe(true);
    expect(res).toMatchObject({ ok: false, kind: 'rate_limited' });
    expect(spy).toHaveBeenCalledTimes(30);
  });

  it('isRpcError TIDAK salah menandai kegagalan domain `{ ok:false, msg }` dari DB', () => {
    // Payload domain (kredensial salah, dsb) = SUKSES dari sudut pandang transport.
    expect(isRpcError({ ok: false, msg: 'Kredensial tidak valid.' })).toBe(false);
    expect(isRpcError({ ok: true, data: [] })).toBe(false);
    expect(isRpcError([])).toBe(false);
    expect(isRpcError(null)).toBe(false);
    expect(isRpcError(undefined)).toBe(false);
    expect(isRpcError('teks')).toBe(false);

    // Kegagalan transport dikenali.
    expect(isRpcError({ ok: false, msg: 'x', kind: 'transport' })).toBe(true);
    expect(isRpcError({ ok: false, msg: 'y', kind: 'rate_limited' })).toBe(true);
  });
});
