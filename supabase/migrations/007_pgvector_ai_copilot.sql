-- ============================================================
-- 007: pgvector + AI Copilot Tables
-- Run this migration to enable RAG for the AI Copilot
-- ============================================================

-- Enable pgvector extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS vector;

-- ──────────────────────────────────────────────────────────────
-- Table: ai_documents
-- Stores knowledge base documents with embeddings
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  context TEXT NOT NULL DEFAULT 'general',  -- kpi, payroll, attendance, policy, general
  category TEXT,                             -- Optional grouping
  embedding VECTOR(1536),                   -- OpenAI text-embedding-3-small dimension
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast vector similarity search
CREATE INDEX IF NOT EXISTS ai_documents_embedding_idx 
  ON ai_documents USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 20);

-- Index for context filtering
CREATE INDEX IF NOT EXISTS ai_documents_context_idx 
  ON ai_documents (context);

-- ──────────────────────────────────────────────────────────────
-- Table: ai_conversations
-- Logs all AI Copilot conversations for analytics
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  user_message TEXT NOT NULL,
  assistant_message TEXT NOT NULL,
  context TEXT DEFAULT 'general',
  tokens_used INTEGER DEFAULT 0,
  documents_used INTEGER DEFAULT 0,
  feedback SMALLINT,                         -- -1 (bad), 0 (neutral), 1 (good)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ai_conversations_created_idx 
  ON ai_conversations (created_at DESC);

-- ──────────────────────────────────────────────────────────────
-- RPC: match_documents
-- Vector similarity search for RAG retrieval
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(1536),
  match_count INT DEFAULT 5,
  filter_context TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  context TEXT,
  similarity FLOAT,
  metadata JSONB
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.title,
    LEFT(d.content, 500) AS content,
    d.context,
    1 - (d.embedding <=> query_embedding) AS similarity,
    d.metadata
  FROM ai_documents d
  WHERE (filter_context IS NULL OR d.context = filter_context)
    AND d.embedding IS NOT NULL
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- RPC: upsert_document
-- Insert or update a document with its embedding
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION upsert_document(
  p_title TEXT,
  p_content TEXT,
  p_context TEXT DEFAULT 'general',
  p_embedding VECTOR(1536) DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  doc_id UUID;
BEGIN
  -- Check if document with same title+context exists
  SELECT id INTO doc_id 
  FROM ai_documents 
  WHERE title = p_title AND context = p_context;
  
  IF doc_id IS NOT NULL THEN
    -- Update existing
    UPDATE ai_documents SET
      content = p_content,
      embedding = COALESCE(p_embedding, embedding),
      metadata = p_metadata,
      updated_at = NOW()
    WHERE id = doc_id;
  ELSE
    -- Insert new
    INSERT INTO ai_documents (title, content, context, embedding, metadata)
    VALUES (p_title, p_content, p_context, p_embedding, p_metadata)
    RETURNING id INTO doc_id;
  END IF;
  
  RETURN doc_id;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- RPC: log_conversation
-- Save a conversation turn for analytics
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION log_conversation(
  p_user_id UUID,
  p_user_message TEXT,
  p_assistant_message TEXT,
  p_context TEXT DEFAULT 'general',
  p_tokens_used INT DEFAULT 0,
  p_documents_used INT DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  conv_id UUID;
BEGIN
  INSERT INTO ai_conversations (
    user_id, user_message, assistant_message, context, tokens_used, documents_used
  ) VALUES (
    p_user_id, p_user_message, p_assistant_message, p_context, p_tokens_used, p_documents_used
  ) RETURNING id INTO conv_id;
  
  RETURN conv_id;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- RPC: get_conversation_stats
-- Analytics for AI Copilot usage
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_conversation_stats()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_conversations', COUNT(*),
    'total_tokens', COALESCE(SUM(tokens_used), 0),
    'avg_tokens_per_query', COALESCE(ROUND(AVG(tokens_used)), 0),
    'context_breakdown', (
      SELECT jsonb_object_agg(context, cnt)
      FROM (
        SELECT context, COUNT(*) as cnt
        FROM ai_conversations
        GROUP BY context
      ) sub
    ),
    'feedback_summary', jsonb_build_object(
      'good', COUNT(*) FILTER (WHERE feedback = 1),
      'neutral', COUNT(*) FILTER (WHERE feedback = 0),
      'bad', COUNT(*) FILTER (WHERE feedback = -1)
    )
  ) INTO result
  FROM ai_conversations;
  
  RETURN result;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- Seed: Sample knowledge base documents
-- ──────────────────────────────────────────────────────────────
INSERT INTO ai_documents (title, content, context) VALUES
  ('Kebijakan Cuti Tahunan', 'Setiap karyawan berhak mendapatkan cuti tahunan sebanyak 12 hari per tahun untuk PKWTT. PKWT mendapatkan cuti proportional berdasarkan masa kerja. Cuti harus diajukan minimal 3 hari sebelumnya melalui sistem.', 'policy'),
  ('Kebijakan Lembur', 'Lembur harus disetujui oleh atasan langsung terlebih dahulu. Rate lembur: hari kerja 1.5x, hari libur 2x, hari besar nasional 3x. Maksimal lembur 3 jam per hari. Klaim leembur harus dilakukan dalam 7 hari setelah lembur.', 'policy'),
  ('Tata Cara Pengajuan KPI', 'KPI dihitung setiap akhir bulan oleh sistem otomatis. Komponen: Kehadiran (30%), Produktivitas (40%), Sikap Kerja (20%), Inisiatif (10%). Target KPI per divisi ditentukan oleh manager. Evaluasi dilakukan setiap kuartal.', 'kpi'),
  ('Struktur Gaji dan Potongan', 'Komponen gaji: Gaji Pokok + Tunjangan Tetap + Tunjangan Tidak Tetap. Potongan: BPJS Kesehatan (4%), BPJS Ketenagakerjaan (variasi), PPH21 (progressive), Pinjaman (jika ada). Slip gaji tersedia setiap tanggal 25.', 'payroll'),
  ('Sistem Kehadiran', 'Jam kerja: 08:00 - 17:00 WIB. Toleransi keterlambatan: 15 menit. Absensi menggunakan fingerprint/face recognition.WFH diizinkan maksimal 2 hari per minggu dengan approval atasan.', 'attendance'),
  ('Proses Onboarding Karyawan Baru', 'Onboarding berlangsung 3 hari: Hari 1 - Orientasi perusahaan dan kebijakan, Hari 2 - Training sistem dan tools, Hari 3 - Meet the team dan assigned buddy. Milestone penyelesaian dalam 30 hari.', 'general'),
  ('Kebijakan Remote Work', 'Remote work diizinkan untuk posisi tertentu dengan approval HR. Maksimal 2 hari per minggu. Harus tetap online di jam kerja (08:00-17:00). Pengajuan melalui sistem minimal 1 hari sebelumnya.', 'policy'),
  ('Career Path dan Promosi', 'Promosi berdasarkan: masa kerja minimal 1 tahun, KPI konsisten ≥80, rekomendasi atasan. jalur karir: Staff → Senior Staff → Supervisor → Manager → Senior Manager → Director. Setiap level punya salary range tersendiri.', 'general')
ON CONFLICT DO NOTHING;
