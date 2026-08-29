import { createClient } from '@supabase/supabase-js';

// Ganti dengan import.meta.env dan prefix VITE_
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Fungsi service client (untuk keperluan server-side) – di Vite tidak digunakan, bisa dinonaktifkan
// export function createServiceClient() {
//   return createClient(
//     import.meta.env.VITE_SUPABASE_URL,  // atau gunakan service key jika ada
//     import.meta.env.VITE_SUPABASE_SERVICE_KEY
//   );
// }