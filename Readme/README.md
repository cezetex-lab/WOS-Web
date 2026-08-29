# WOS-Web — Panduan Setup untuk Newbie

## Apa yang Kita Bangun?

```
Browser HP → Vercel (website) → Supabase (database + backend) → Upstash (cache cepat)
```

---

## LANGKAH 1: Buat Akun Supabase (10 menit)

1. Buka **https://supabase.com**
2. Klik **"Start your project"** → Login pakai GitHub
3. Klik **"New project"**
4. Isi:
   - **Organization**: pilih atau buat baru
   - **Project name**: `wos-production`
   - **Database password**: isi password (INGAT! simpan)
   - **Region**: `Southeast Asia (Singapore)` ← paling dekat
5. Klik **"Create new project"** → tunggu 2 menit
6. Selesai! Simpan 3 hal ini:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon key**: `eyJhbGciOi...` (klik Project Settings → API)
   - **service_role key**: `eyJhbGciOi...` (jangan share!)

---

## LANGKAH 2: Buat Database di Supabase (15 menit)

1. Di Supabase dashboard, klik menu **"SQL Editor"** (kiri)
2. Klik **"New query"**
3. Copy-paste isi file `supabase/migrations/001_init.sql` (yang akan saya buat)
4. Klik **"Run"** → tunggu selesai
5. Klik menu **"Table Editor"** → cek 58 tabel sudah ada

---

## LANGKAH 3: Buat Akun Upstash (5 menit)

1. Buka **https://upstash.com**
2. Klik **"Sign in with GitHub"**
3. Klik **"Create Database"**
4. Isi:
   - **Name**: `wos-cache`
   - **Region**: `ap-southeast-1` (Singapore)
5. Klik **"Create"**
6. Klik tab **"REST API"**
7. Simpan 2 hal ini:
   - **UPSTASH_REDIS_REST_URL**: `https://xxxx.upstash.io`
   - **UPSTASH_REDIS_REST_TOKEN**: `AXxx...`

---

## LANGKAH 4: Buat Akun Vercel (5 menit)

1. Buka **https://vercel.com**
2. Klik **"Sign up"** → Login pakai GitHub
3. Selesai! (Deploy nanti setelah kode siap)

---

## LANGKAH 5: Setup di Komputer Anda (10 menit)

Buka Terminal/Command Prompt, ketik:

```bash
# 1. Install Node.js (kalau belum) — download dari https://nodejs.org
#    Pilih LTS version → install → restart terminal

# 2. Install Vercel CLI
npm install -g vercel

# 3. Login Vercel
vercel login

# 4. Masuk ke folder project
cd "C:\Users\indic\Desktop\Final 1\WOS-Web"

# 5. Install dependencies
npm install
```

---

## LANGKAH 6: Isi File .env (5 menit)

Buat file `.env` di folder `WOS-Web`:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
SUPABASE_SERVICE_KEY=eyJhbGciOi...

UPSTASH_REDIS_REST_URL=https://xxxx.upstash.io
UPSTASH_REDIS_REST_TOKEN=AXxx...

NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOi...
```

---

## LANGKAH 7: Deploy ke Vercel (2 menit)

```bash
# Dari folder WOS-Web:
vercel

# Ikuti pertanyaan:
# > Set up and deploy? → Y
# > Which scope? → pilih akun Anda
# > Link to existing project? → N
# > Project name? → wos-production
# > Directory? → ./
# > Override settings? → N

# Selesai! Dapat URL: https://wos-production.vercel.app
```

---

## RINGKASAN — 7 LANGKAH

| Langkah | Apa | Waktu |
|---|---|---|
| 1 | Buat akun Supabase | 10 min |
| 2 | Buat database (SQL) | 15 min |
| 3 | Buat akun Upstash | 5 min |
| 4 | Buat akun Vercel | 5 min |
| 5 | Install Node + dependencies | 10 min |
| 6 | Isi file .env | 5 min |
| 7 | Deploy ke Vercel | 2 min |
| **Total** | | **~50 min** |

---

## YANG SAYA HANDLE (Coding)

Saya akan buat semua kode:
- `supabase/migrations/001_init.sql` — 58 tabel
- `src/lib/supabase.js` — koneksi ke Supabase
- `src/lib/redis.js` — koneksi ke Upstash
- `src/lib/auth.js` — sistem login baru
- `src/pages/` — 4 halaman (index, worker, admin, dashboard)
- `src/services/` — port dari 40+ GS files

**Anda hanya perlu:** Buat 3 akun + isi .env + deploy.
