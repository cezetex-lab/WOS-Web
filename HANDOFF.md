# 📋 HANDOFF — insightWOS v3.0

> **Untuk developer berikutnya** — Dokumen ini berisi status lengkap, akses, backlog, dan catatan penting.
> Dibuat: 29 Agustus 2026 | Branch: `migrasi-vite`

---

## 🎯 RINGKASAN EKSEKUTIF

**insightWOS** adalah platform Workforce Intelligence untuk manajemen SDM. Saat ini dalam kondisi:

| Aspek | Status |
|-------|--------|
| **Frontend** | ✅ Selesai — Vite + React + Tailwind, 52 routes, 53 fitur aktif |
| **Backend** | ✅ Selesai — 57 tabel, 200+ RPC, pgvector AI |
| **Design System** | ✅ Selesai — 22 komponen reusable, Tailwind + CSS variables |
| **AI Copilot** | ✅ Code selesai, ⚠️ perlu deploy Edge Function + pgvector |
| **PWA** | ✅ Code selesai, ⚠️ perlu icon asli (placeholder saat ini) |
| **Database Seed** | ⚠️ 38/57 tables sudah di-seed, 17 tables masih kosong |
| **Deploy** | ✅ Live di https://insightwos.vercel.app |

**Bottom line:** Frontend siap 100%. Yang kurang: **seed data** untuk 17 tables + **deploy AI Copilot** + **icon PWA**.

---

## 🔑 AKSES & CREDENTIALS

### Supabase
| Item | Nilai |
|------|-------|
| URL | `https://xxxxx.supabase.co` (lihat .env) |
| Anon Key | `eyJhbGci...` (lihat .env) |
| Dashboard | https://supabase.com/dashboard |

### Vercel
| Item | Nilai |
|------|-------|
| Project | `insightWOS` |
| URL | https://insightwos.vercel.app |
| Branch | `migrasi-vite` |

### Default Login
| Role | NRP | Password |
|------|-----|----------|
| Admin | `admin` | `Admin123` |
| Worker | `NRP001` | `Password123` |
| Worker | `NRP002` - `NRP030` | `Password123` |

### OpenAI (untuk AI Copilot)
| Item | Nilai |
|------|-------|
| API Key | Belum di-set — perlu daftar di https://platform.openai.com |
| Model | GPT-4o-mini (chat) + text-embedding-3-small (embeddings) |

---

## 📊 STATUS DETAIL PER KOMPONEN

### ✅ Wave 1-4: Foundation (SELESAI)
- Migrasi Next.js → Vite
- Design System (22 komponen)
- Route Registration (52 routes)
- Core Pages (Admin, Worker, Dashboard, Employees, Payroll, KPI)

### ✅ Wave 5: Detail Pages (SELESAI)
- 32 halaman admin via `DetailPageFactory` (auto-generated)
- 10 halaman worker via `DetailPageFactory`
- **Catatan:** Semua pakai factory pattern — auto-detect columns dari data

### ✅ Wave 6: Backend Optimization (SELESAI)
- `cache.js` — client-side cache (localStorage + TTL)
- Edge Functions — `cache-service`, `cron-handler`, `gas-migration`
- pg_cron SQL — 8 schedules
- `.env` security fix

### ✅ Wave 7: AI Copilot + PWA (SELESAI)
- `ChatCopilot.jsx` — floating chat widget
- `ai-copilot/index.ts` — RAG pipeline (pgvector + OpenAI)
- `sw.js` — Service Worker (cache-first + network-first)
- `manifest.json` — PWA manifest
- `PwaUpdater.jsx` — update notification
- **Belum deploy:** Edge Function + pgvector migration

### ✅ Logout Buttons (SELESAI)
- Admin: header (🚪 + "Keluar")
- Worker: header (🚪 + "Keluar")
- Dashboard: header (🚪 icon)

---

## ⚠️ YANG PERLU DIPERHATIKAN

### 1. 17 Tables Belum Di-seed
Ini **prioritas utama**. Tanpa data, banyak halaman tampil kosong.

**Tables yang belum ada data:**

| Table | Kebutuhan Data | Priority |
|-------|---------------|----------|
| `hr_finance_kpi` | Revenue, profit, opex per divisi | P1 |
| `hr_kpi_config` | KPI indicators & targets | P1 |
| `hr_skills` | Skill levels per karyawan | P1 |
| `hr_position_skills` | Required skills per posisi | P1 |
| `hr_tasks` | Tasks untuk karyawan | P1 |
| `hr_ai_tasks` | AI auto-healing tasks | P1 |
| `announcements` | Pengumuman perusahaan | P2 |
| `hr_training_catalog` | Daftar training | P2 |
| `hr_succession` | Succession planning | P2 |
| `hr_critical` | Critical positions | P2 |
| `hr_overtime` | Data lembur | P2 |
| `hr_exit_clearance` | Exit clearance | P2 |
| `hr_medical_checkup` | Medical checkup | P3 |
| `hr_capability` | Competency gap | P3 |
| `hr_relations` | Employee relations | P3 |
| `hr_monthly_snapshot` | Monthly metrics | P3 |
| `hr_plantation_harvest` | Harvest data | P3 |

**Cara fix:** Buat file `supabase/migrations/027_seed_remaining_tables.sql` dengan INSERT statements untuk 17 tables di atas.

### 2. AI Copilot Belum Deploy
Code sudah lengkap, tapi perlu:
1. Run migration `007_pgvector_ai_copilot.sql` di Supabase SQL Editor
2. Set `OPENAI_API_KEY` di Supabase Dashboard → Edge Functions → Secrets
3. Deploy: `supabase functions deploy ai-copilot`

### 3. PWA Icons Masih Placeholder
Icons di `public/icons/` masih 1px PNG placeholder. Perlu diganti dengan icon asli insightWOS.

**Ukuran yang dibutuhkan:** 72, 96, 128, 144, 152, 192, 384, 512 px

### 4. File Legacy Masih Ada
File-file ini masih ada untuk backward compatibility, bisa dihapus setelah yakin tidak dipakai:
- `src/lib/ui-kit.jsx`
- `src/lib/ui-components.jsx`
- `src/lib/app-shell.jsx`
- `src/lib/theme.js`
- `src/lib/toast.js`
- `src/lib/components.jsx`
- `src/layout.js`
- `src/middleware.js`

### 5. DetailPageFactory Pages
33 halaman admin + 10 halaman worker masih pakai `DetailPageFactory` (auto-generated). Beberapa perlu custom:
- `/admin/org` — Org chart (perlu tree visualization)
- `/admin/analytics` — Charts & graphs
- `/admin/audit` — Audit log viewer
- `/admin/settings` — Settings form

---

## 🏗️ BACKLOG (Prioritas)

### P1 — Harus Selesai
| # | Task | Estimasi | File |
|---|------|----------|------|
| 1 | Seed 17 tables yang belum ada | 1-2 jam | `supabase/migrations/027_seed_remaining.sql` |
| 2 | Test & fix RPC functions yang error | 1-2 jam | Cek semua RPC di Supabase SQL Editor |
| 3 | Deploy AI Copilot | 30 menit | `supabase functions deploy ai-copilot` |
| 4 | Smoke test semua halaman | 1 jam | Buka setiap route, cek data tampil |

### P2 — Sebaiknya Selesai
| # | Task | Estimasi | File |
|---|------|----------|------|
| 5 | Ganti placeholder PWA icons | 30 menit | `public/icons/*.png` |
| 6 | Custom Org Chart page | 2-3 jam | `src/pages/admin/OrgChart.jsx` |
| 7 | Custom Analytics page | 2-3 jam | `src/pages/admin/Analytics.jsx` |
| 8 | Offline indicator | 1 jam | `src/components/OfflineIndicator.jsx` |
| 9 | Push notifications (FCM) | 2-3 jam | Firebase setup |

### P3 — Nice to Have
| # | Task | Estimasi | File |
|---|------|----------|------|
| 10 | Cleanup legacy files | 15 menit | Hapus `app-shell.jsx`, `ui-kit.jsx`, dll |
| 11 | Upstash Redis integration | 1-2 jam | Update `cachedRpc()` ke Redis |
| 12 | Deploy pg_cron schedules | 30 menit | Run `006_cron_setup.sql` |
| 13 | Deploy Edge Functions | 30 menit | `cache-service`, `cron-handler` |
| 14 | Analytics dashboard charts | 3-4 jam | Chart.js di halaman analytics |
| 15 | Export to Excel/CSV | 1-2 jam | xlsx library |

---

## 📁 FILE YANG SERING DI-EDIT

| File | Fungsi | Kapan Edit |
|------|--------|-----------|
| `src/App.jsx` | Router & routes | Tambah/hapus route |
| `src/lib/design-system.jsx` | 22 UI components | Ubah tampilan global |
| `src/pages/admin/DetailPageFactory.jsx` | Auto-generated pages | Tambah config untuk halaman baru |
| `src/components/ChatCopilot.jsx` | AI chat widget | Ubah chat behavior |
| `src/lib/supabase-browser.js` | RPC & session | Tambah RPC wrapper |
| `src/lib/cache.js` | Client cache | Ubah TTL atau caching strategy |
| `src/globals.css` | CSS variables | Ubah theme colors |
| `vercel.json` | Deploy config | Ubah caching rules |

---

## 🧪 TESTING CHECKLIST

### Login
- [ ] Worker login dengan NRP + Password
- [ ] Admin login
- [ ] OTP flow (jika diaktifkan)
- [ ] Logout button funciona di semua 3 halaman

### Halaman Admin
- [ ] `/admin` — Dashboard tampil, QuickTile navigate
- [ ] `/admin/employees` — DataTable, search, pagination, modal
- [ ] `/admin/payroll` — Period filter, export CSV
- [ ] `/admin/kpi` — Chart.js tampil (doughnut, line, bar)
- [ ] `/admin/org` — Data tampil dari factory
- [ ] `/admin/requests` — Pending requests tampil
- [ ] 33 halaman factory lainnya — minimal tampil data

### Halaman Worker
- [ ] `/worker` — Dashboard, narrative, announcements
- [ ] 10 halaman factory — minimal tampil data

### Manager Dashboard
- [ ] `/dashboard` — Stats, team, requests, approve/reject

### PWA
- [ ] Manifest terdeteksi (Chrome DevTools → Application)
- [ ] Service Worker registered
- [ ] Bisa install ke home screen
- [ ] Offline mode (static assets cached)

### AI Copilot
- [ ] Chat widget muncul di semua halaman
- [ ] Quick actions funciona
- [ ] Response dari OpenAI tampil

---

## 🔧 TROUBLESHOOTING

### Masalah: Halaman tampil kosong/putih
**Penyebab:** Data belum di-seed atau RPC error
**Fix:** Cek Supabase SQL Editor → jalankan `SELECT * FROM [table]` untuk cek data

### Masalah: Tailwind classes tidak jalan
**Penyebab:** Build belum dijalankan atau Tailwind config salah
**Fix:** `npm run build` → cek `dist/assets/index.css` ada utility classes

### Masalah: RPC returns error
**Penyebab:** Column mismatch atau function belum dibuat
**Fix:** Cek Supabase SQL Editor → jalankan function langsung → cek error message

### Masalah: AI Copilot tidak jalan
**Penyebab:** Edge Function belum deploy atau OpenAI key belum di-set
**Fix:**
1. Cek `supabase secrets list`
2. `supabase functions deploy ai-copilot`
3. Test: `curl -X POST [SUPABASE_URL]/functions/v1/ai-copilot -H "Authorization: Bearer [ANON_KEY]" -d '{"message":"test"}'`

### Masalah: Build error
**Penyebab:** Import path salah atau component tidak ada
**Fix:** Cek error message → pastikan import pakai `@/lib/...` alias

---

## 📐 CODE CONVENTIONS

### Import Aliases
```javascript
import { something } from '@/lib/design-system';  // ✅ Gunakan alias @/
import { something } from '../lib/design-system';  // ❌ Hindari relative paths
```

### Component Pattern
```jsx
// Functional component dengan hooks
export default function PageName() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState([]);
  
  useEffect(() => { fetchData(); }, []);
  
  async function fetchData() {
    const { data } = await rpc('function_name');
    setData(data || []);
    setLoading(false);
  }
  
  if (loading) return <LoadingSpinner />;
  return <div>...</div>;
}
```

### RPC Pattern
```javascript
// Selalu handle error
const { data, error } = await supabase.rpc('function_name', { param: value });
if (error) console.error(error);
setData(data || []);

// Atau pakai wrapper
const result = await rpc('function_name', { param: value });
if (result?.ok) setData(result.data);
```

### Tailwind Pattern
```jsx
// Glassmorphism card
<GlassCard title="Title" icon="📊" accent="teal">
  <div className="p-4 bg-white/5 rounded-xl">
    <p className="text-sm text-slate-300">Content</p>
  </div>
</GlassCard>

// Metric card
<MetricCard icon="📈" value={42} label="Label" trend="+12%" color="blue" />
```

---

## 🚀 DEPLOYMENT STEPS

### Update Code
```bash
# 1. Make changes
# 2. Test locally
npm run dev

# 3. Build
npm run build

# 4. Push to GitHub
git add -A
git commit -m "Description of changes"
git push origin migrasi-vite

# 5. Vercel auto-deploys from branch
```

### Run Database Migration
```bash
# Via Supabase Dashboard:
# 1. Go to SQL Editor
# 2. Paste migration SQL
# 3. Click "Run"
# 4. Verify with SELECT queries
```

### Deploy Edge Functions
```bash
# Install Supabase CLI if needed
npm install -g supabase

# Login
supabase login

# Link to project
supabase link --project-ref [PROJECT_REF]

# Deploy functions
supabase functions deploy ai-copilot
supabase functions deploy cache-service
```

---

## 📞 KONTAK & RESOURCES

| Resource | URL |
|----------|-----|
| Live App | https://insightwos.vercel.app |
| Vercel Dashboard | https://vercel.com/dashboard |
| Supabase Dashboard | https://supabase.com/dashboard |
| GitHub Repo | https://github.com/[repo]/WOS-Web |
| Tailwind Docs | https://tailwindcss.com/docs |
| React Router | https://reactrouter.com |
| Chart.js | https://www.chartjs.org |

---

## 📝 CATATAN KHUSUS

1. **Branch `migrasi-vite`** adalah branch utama. Semua perubahan ke sini.
2. **Vercel auto-deploy** dari branch ini. Push = deploy.
3. **Supabase RLS aktif** — pastikan policy benar sebelum ubah.
4. **OpenAI API** berbayar (~$0.001/1K tokens). Gunakan GPT-4o-mini untuk hemat.
5. **100% CSR** — tidak ada SEO, tidak ada server-side rendering. OK untuk dashboard internal.
6. **Chart.js lazy-loaded** — chunk terpisah (~200KB), tidak membebani initial load.

---

> **Semoga dokumentasi ini membantu!** 🤖
> Jika ada pertanyaan, cek README.md atau file source code langsung.
> 
> — Buffy (Codebuff AI), 29 Agustus 2026
