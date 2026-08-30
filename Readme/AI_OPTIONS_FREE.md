# 🆓 Free AI Options untuk insightWOS

## Perbandingan

| Provider | Model | Free Limit | Kecepatan | Cocok? |
|----------|-------|-----------|-----------|--------|
| **Google Gemini** | Gemini 1.5 Flash | 15 RPM, 1M tokens/day | ⚡⚡⚡ | ✅ **BEST** |
| **Groq** | Llama 3.1 8B | 30 RPM, 14K tokens/min | ⚡⚡⚡⚡ | ✅ GREAT |
| **Cerebras** | Llama 3.1 8B | 30 RPM | ⚡⚡⚡⚡⚡ | ✅ GREAT |
| **Qwen (Alibaba)** | Qwen-Turbo | 1M tokens/month | ⚡⚡ | ⚠️ Limited |
| **HuggingFace** | Various | 1K requests/day | ⚡ | ⚠️ Slow |
| **OpenAI** | GPT-4o-mini | ❌ Bayar | ⚡⚡⚡ | ❌ |

## Rekomendasi: Google Gemini 1.5 Flash

**Alasan:**
- ✅ **Gratis total** (15 requests/menit, 1 juta tokens/hari)
- ✅ Cukup untuk 2000+ karyawan
- ✅ Bahasa Indonesia bagus
- ✅ Tidak perlu kartu kredit
- ✅ Mudah setup (hanya ganti API key)

**Setup:**
1. Buka https://aistudio.google.com/apikey
2. Login Google → Create API Key
3. Copy key → paste ke Supabase Secrets

## Alternatif: Groq (Llama 3.1)

**Alasan:**
- ✅ **Gratis total** (30 requests/menit)
- ✅ Sangat cepat (< 1 detik)
- ✅ Open source (Llama 3.1)
- ✅ Tidak perlu kartu kredit

**Setup:**
1. Buka https://console.groq.com/keys
2. Create API Key
3. Copy key → paste ke Supabase Secrets

## Yang Perlu Diubah di Kode

### Ubah 1 file saja: `supabase/functions/ai-copilot/index.ts`

Ganti OpenAI API calls ke Google Gemini atau Groq.

**Sebelum (OpenAI):**
```typescript
// Embedding
const embeddingRes = await fetch("https://api.openai.com/v1/embeddings", { ... });
// Chat
const chatRes = await fetch("https://api.openai.com/v1/chat/completions", { ... });
```

**Sesudah (Google Gemini):**
```typescript
// Chat (tanpa embedding — pakai keyword search saja)
const chatRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`, { ... });
```

**Atau (Groq):**
```typescript
// Chat (OpenAI-compatible API)
const chatRes = await fetch("https://api.groq.com/openai/v1/chat/completions", { ... });
```

## Strategi: AI Bodoh + Database Query

Karena semua data sudah ada di database, AI hanya perlu:

1. **Terima pertanyaan user** → "Bagaimana KPI divisi Mining?"
2. **Query database** via RPC → `admin_get_kpi_by_division()`
3. **Format hasilnya** → "Divisi Mining: Avg KPI 78.5, 12 high performers..."
4. **Kirim ke AI** → "Jawab dengan data ini: [format result]"
5. **AI return** → Response yang sudah diformat

**Tidak perlu embeddings, tidak perlu RAG, tidak perlu vector search.**

Cukup:
- User message + database result → AI format → Response

Ini jauh lebih murah dan lebih cepat.
