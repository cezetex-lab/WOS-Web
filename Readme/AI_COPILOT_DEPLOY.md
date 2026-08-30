# 🤖 AI Copilot Deployment Guide

## Status

| Komponen | File | Status |
|----------|------|--------|
| Frontend Chat UI | `src/components/ChatCopilot.jsx` | ✅ Siap |
| Integrasi Layout | `src/components/Layout.jsx` | ✅ Sudah terpasang |
| Edge Function | `supabase/functions/ai-copilot/index.ts` | ✅ Siap |
| pgvector Migration | `supabase/migrations/007_pgvector_ai_copilot.sql` | ✅ Siap |

---

## Step 1: Run pgvector Migration

Buka **Supabase Dashboard** → **SQL Editor**, lalu paste & run seluruh isi:

```
supabase/migrations/007_pgvector_ai_copilot.sql
```

Ini akan membuat:
- Extension `vector` (pgvector)
- Table `ai_documents` (knowledge base dengan embeddings)
- Table `ai_conversations` (conversation logs)
- RPC `match_documents` (vector similarity search)
- RPC `upsert_document` (insert/update documents)
- RPC `log_conversation` (save chat logs)
- RPC `get_conversation_stats` (analytics)
- 8 seed documents (kebijakan cuti, lembur, KPI, gaji, dll)

**⚠️ Pastikan extension `vector` sudah ter-install di Supabase.**
Kalau belum, jalankan dulu:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

---

## Step 2: Set OpenAI API Key

Buka **Supabase Dashboard** → **Edge Functions** → **Secrets**

Tambahkan secret:
```
Name:  OPENAI_API_KEY
Value: sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ Gunakan OpenAI API key yang aktif.**
- Model yang dipakai: `text-embedding-3-small` (embeddings) + `gpt-4o-mini` (chat)
- Estimasi biaya: ~$0.01-0.05 per percakapan (tergantung panjang)

---

## Step 3: Deploy Edge Function

### Option A: Supabase CLI (Recommended)

```bash
# Install Supabase CLI jika belum ada
npm install -g supabase

# Login
supabase login

# Link ke project
supabase link --project-ref <your-project-ref>

# Deploy ai-copilot
supabase functions deploy ai-copilot
```

### Option B: Supabase Dashboard

1. Buka **Supabase Dashboard** → **Edge Functions**
2. Klik **"Create a new function"** atau **"Deploy"**
3. Upload `supabase/functions/ai-copilot/index.ts`
4. Function name: `ai-copilot`
5. Click **Deploy**

---

## Step 4: Test

### Quick Test via Browser Console

Buka https://insightwos.vercel.app, login, lalu buka browser console (F12):

```javascript
const res = await fetch('https://<your-project>.supabase.co/functions/v1/ai-copilot', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer <your-anon-key>',
  },
  body: JSON.stringify({
    message: 'Bagaimana ringkasan KPI karyawan?',
    context: 'kpi',
  }),
});
const data = await res.json();
console.log(data);
```

### Expected Response

```json
{
  "message": "Berdasarkan data yang tersedia, berikut ringkasan KPI...",
  "sources": [
    { "title": "Tata Cara Pengajuan KPI", "similarity": 0.85 }
  ],
  "usage": {
    "prompt_tokens": 500,
    "completion_tokens": 200,
    "total_tokens": 700
  }
}
```

### Test via Chat Widget

1. Login ke app
2. Klik tombol 🤖 (floating button di kanan bawah)
3. Ketik pertanyaan atau klik Quick Action
4. AI Copilot akan menjawab berdasarkan data & dokumen perusahaan

---

## Troubleshooting

### "Failed to generate embedding"
- Cek OPENAI_API_KEY sudah benar dan aktif
- Cek quota OpenAI masih ada

### "Failed to generate response"
- Cek OpenAI API key tidak expired
- Cek model `gpt-4o-mini` tersedia di akun

### "Vector search error"
- Pastikan migration 007 sudah di-run
- Pastikan extension `vector` ter-install
- Jalankan: `SELECT extname FROM pg_extension WHERE extname = 'vector';`

### Chat widget tidak muncul
- Cek Layout.jsx import ChatCopilot
- Cek VITE_SUPABASE_URL dan VITE_SUPABASE_ANON_KEY di .env

---

## Architecture

```
User → ChatCopilot.jsx (Frontend)
         ↓ POST /functions/v1/ai-copilot
       Edge Function (Deno)
         ↓
       1. OpenAI Embedding (text-embedding-3-small)
       2. Supabase Vector Search (match_documents)
       3. Fetch live data (admin_get_summary, etc)
       4. OpenAI Chat (gpt-4o-mini) with RAG context
         ↓
       Response → ChatCopilot.jsx
```

---

## Knowledge Base Management

### Add new document

```sql
-- Via Supabase SQL Editor
SELECT upsert_document(
  'Judul Dokumen',
  'Isi lengkap dokumen di sini...',
  'policy',  -- context: kpi, payroll, attendance, policy, general
  NULL,      -- embedding (akan di-generate manual atau via Edge Function)
  '{}'::jsonb
);
```

### List all documents

```sql
SELECT id, title, context, created_at 
FROM ai_documents 
ORDER BY created_at DESC;
```

### Delete document

```sql
DELETE FROM ai_documents WHERE id = '<uuid>';
```

---

## Cost Estimate

| Item | Estimasi |
|------|----------|
| Embedding (text-embedding-3-small) | ~$0.0001 / 1K tokens |
| Chat (gpt-4o-mini) | ~$0.00015 / 1K tokens |
| 1 percakapan (10 pesan) | ~$0.01 - $0.05 |
| 100 percakapan / bulan | ~$1 - $5 |
| Supabase Edge Function | Free tier: 500K invocations |

**Total: ~$1-5 / bulan untuk usage normal**

---

> **insightWOS AI Copilot** — RAG-powered assistant untuk data HR
