import '@testing-library/jest-dom';
import { vi } from 'vitest';

/**
 * Env VITE_* untuk seluruh test.
 *
 * KENAPA INI PERLU
 *   `src/lib/supabase-browser.ts` memanggil `createClient(import.meta.env.VITE_SUPABASE_URL, …)`
 *   di TOP-LEVEL modul (baris 15). Begitu modul itu diimpor — termasuk oleh
 *   `await import(...)` di dalam test — `createClient` langsung dieksekusi. Kalau
 *   env-nya kosong, ia melempar `supabaseUrl is required` dan SELURUH test di
 *   berkas tersebut mati, bukan cuma satu test.
 *
 *   Locally `.env.local` (gitignored) menyediakan env itu, jadi suite hijau.
 *   Di runner CI tidak ada `.env.local` dan tidak ada yang menyetelnya, sehingga
 *   19 test di 3 berkas jsdom gagal. Stub di sini menutup celah itu: test jadi
 *   tidak bergantung pada mesin developer, hanya pada kode test-nya.
 *
 * CATATAN — jangan pakai nilai nyata di sini. Stub ini untuk membuat modul bisa
 * diimpor; tidak ada test yang memanggil jaringan ke Supabase sungguhan.
 *
 * Daftar variabel diambil dari pemakaian nyata `import.meta.env.VITE_*` di
 * `src/` + `tests/` (bukan dari `.env.example`, yang bisa lebih/kurang sinkron).
 */
vi.stubEnv('VITE_SUPABASE_URL', 'http://test.supabase.co');
vi.stubEnv('VITE_SUPABASE_ANON_KEY', 'test-anon-key');
vi.stubEnv('VITE_POSTHOG_KEY', 'test-posthog-key');
vi.stubEnv('VITE_POSTHOG_HOST', 'http://test.posthog.com');
