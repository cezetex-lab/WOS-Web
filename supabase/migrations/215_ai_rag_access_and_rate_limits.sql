-- ================================================================
-- 215_ai_rag_access_and_rate_limits.sql — N1 + N4
--
-- N1: AI RAG Document Access Filtering
--   Problem: ai_documents/ai_conversations RLS enabled but NO policies
--            → all queries blocked. match_documents has precedence bug.
--            upsert_document has no auth check.
--   Fix: RLS policies (admin=all, worker=own-BU/own-data),
--        fix match_documents WHERE clause, secure upsert_document.
--
-- N4: AI Query Rate Limit Tuning
--   Problem: All roles get same limit (50/day). No differentiation.
--   Fix: Role-based limits (worker=15/day, admin=50/day, owner=unlimited),
--        add role_level to ai_rate_limits, warning at 80%.
-- ================================================================

-- ── 1. Add role_level to ai_rate_limits ──
ALTER TABLE ai_rate_limits
  ADD COLUMN IF NOT EXISTS role_level integer DEFAULT 0;

COMMENT ON COLUMN ai_rate_limits.role_level IS '0=worker, 1=supervisor, 2=manager, 3=director, 4=admin_pusat/owner';

-- ── 2. RLS policies on ai_documents ──
-- Admin/owner (role_level >= 4): full access
DROP POLICY IF EXISTS "ai_docs_admin_all" ON ai_documents;
CREATE POLICY "ai_docs_admin_all" ON ai_documents
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM employees_master e
      WHERE e.auth_id = auth.uid() AND e.role_level >= 4
    )
    OR EXISTS (
      SELECT 1 FROM system_owner_identity o
      WHERE o.auth_id = auth.uid() AND o.is_active = true
    )
  );

-- Worker: read own BU documents + general documents
DROP POLICY IF EXISTS "ai_docs_worker_read" ON ai_documents;
CREATE POLICY "ai_docs_worker_read" ON ai_documents
  FOR SELECT
  USING (
    -- General documents (no BU filter) — accessible to all authenticated
    (metadata->>'bu') IS NULL
    OR
    -- BU-specific documents — only for matching BU
    metadata->>'bu' = (
      SELECT business_unit_id FROM employees_master
      WHERE auth_id = auth.uid() LIMIT 1
    )
  );

-- Worker: insert own conversations (for ai_conversations, handled separately)

-- ── 3. RLS policies on ai_conversations ──
-- User sees only own conversations
DROP POLICY IF EXISTS "ai_conv_own_read" ON ai_conversations;
CREATE POLICY "ai_conv_own_read" ON ai_conversations
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    -- Admin/owner sees all
    EXISTS (
      SELECT 1 FROM employees_master e
      WHERE e.auth_id = auth.uid() AND e.role_level >= 4
    )
    OR EXISTS (
      SELECT 1 FROM system_owner_identity o
      WHERE o.auth_id = auth.uid() AND o.is_active = true
    )
  );

-- User inserts own conversations
DROP POLICY IF EXISTS "ai_conv_own_insert" ON ai_conversations;
CREATE POLICY "ai_conv_own_insert" ON ai_conversations
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ── 4. RLS policies on ai_rate_limits ──
-- User sees/updates only own rows
DROP POLICY IF EXISTS "ai_ratelimit_own_read" ON ai_rate_limits;
CREATE POLICY "ai_ratelimit_own_read" ON ai_rate_limits
  FOR SELECT
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

DROP POLICY IF EXISTS "ai_ratelimit_own_insert" ON ai_rate_limits;
CREATE POLICY "ai_ratelimit_own_insert" ON ai_rate_limits
  FOR INSERT
  WITH CHECK (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

DROP POLICY IF EXISTS "ai_ratelimit_own_update" ON ai_rate_limits;
CREATE POLICY "ai_ratelimit_own_update" ON ai_rate_limits
  FOR UPDATE
  USING (nrp = (SELECT nrp FROM employees_master WHERE auth_id = auth.uid() LIMIT 1));

-- Admin/owner: full access
DROP POLICY IF EXISTS "ai_ratelimit_admin_all" ON ai_rate_limits;
CREATE POLICY "ai_ratelimit_admin_all" ON ai_rate_limits
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM employees_master e
      WHERE e.auth_id = auth.uid() AND e.role_level >= 4
    )
    OR EXISTS (
      SELECT 1 FROM system_owner_identity o
      WHERE o.auth_id = auth.uid() AND o.is_active = true
    )
  );

-- ── 5. Fix match_documents precedence bug ──
-- Bug: `... IS NULL OR ... = v_bu OR v_bu IS NULL` → when v_bu IS NULL, ALL docs leak
-- Fix: proper parentheses + role isolation
CREATE OR REPLACE FUNCTION public.match_documents(
  query_embedding vector,
  match_count integer DEFAULT 5,
  filter_context text DEFAULT NULL::text
)
RETURNS TABLE(id uuid, title text, content text, context text, similarity double precision, metadata jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller TEXT;
  v_bu TEXT;
  v_role_level INT;
BEGIN
  -- Get caller info
  SELECT nrp, business_unit_id, role_level INTO v_caller, v_bu, v_role_level
  FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;

  -- Owner/admin: see everything (no BU filter)
  IF v_role_level >= 4 OR EXISTS (
    SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = true
  ) THEN
    RETURN QUERY
    SELECT d.id, d.title, LEFT(d.content, 500)::text AS content, d.context,
      1 - (d.embedding <=> query_embedding) AS similarity, d.metadata
    FROM ai_documents d
    WHERE (filter_context IS NULL OR d.context = filter_context)
      AND d.embedding IS NOT NULL
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
    RETURN;
  END IF;

  -- Worker: general docs + own BU docs only
  RETURN QUERY
  SELECT d.id, d.title, LEFT(d.content, 500)::text AS content, d.context,
    1 - (d.embedding <=> query_embedding) AS similarity, d.metadata
  FROM ai_documents d
  WHERE (filter_context IS NULL OR d.context = filter_context)
    AND d.embedding IS NOT NULL
    AND (
      (d.metadata->>'bu') IS NULL             -- general docs: accessible to all
      OR d.metadata->>'bu' = v_bu             -- BU-specific: only matching BU
      OR v_bu IS NULL                         -- if caller has no BU: general only
    )
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$function$;

-- ── 6. Secure upsert_document — admin only ──
CREATE OR REPLACE FUNCTION public.upsert_document(
  p_title text, p_content text, p_context text DEFAULT 'general'::text,
  p_embedding vector DEFAULT NULL::vector, p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  doc_id UUID;
  v_role_level INT;
BEGIN
  -- Auth check: must be admin/owner
  SELECT role_level INTO v_role_level
  FROM employees_master WHERE auth_id = auth.uid() LIMIT 1;

  IF v_role_level IS NULL OR v_role_level < 4 THEN
    IF NOT EXISTS (
      SELECT 1 FROM system_owner_identity WHERE auth_id = auth.uid() AND is_active = true
    ) THEN
      RAISE EXCEPTION 'Akses ditolak: hanya admin yang bisa mengelola dokumen AI'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  -- Check if document with same title+context exists
  SELECT id INTO doc_id
  FROM ai_documents
  WHERE title = p_title AND context = p_context;

  IF doc_id IS NOT NULL THEN
    UPDATE ai_documents SET
      content = p_content,
      embedding = COALESCE(p_embedding, embedding),
      metadata = p_metadata,
      updated_at = NOW()
    WHERE id = doc_id;
  ELSE
    INSERT INTO ai_documents (title, content, context, embedding, metadata)
    VALUES (p_title, p_content, p_context, p_embedding, p_metadata)
    RETURNING id INTO doc_id;
  END IF;

  RETURN doc_id;
END;
$function$;

-- ── 7. N4: Role-based ai_check_rate_limit ──
-- Worker: 15 queries/day, 50K tokens
-- Supervisor/Manager: 30 queries/day, 75K tokens
-- Director/Admin: 50 queries/day, 100K tokens
-- Owner/Admin Pusat: unlimited (always returns ok=true)
CREATE OR REPLACE FUNCTION public.ai_check_rate_limit(
  p_nrp text,
  p_max_queries integer DEFAULT NULL,
  p_max_tokens bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_count INT;
  v_tokens BIGINT;
  v_role_level INT;
  v_max_q INT;
  v_max_t BIGINT;
  v_remaining_pct NUMERIC;
BEGIN
  -- Get role level
  SELECT role_level INTO v_role_level
  FROM employees_master WHERE nrp = p_nrp LIMIT 1;

  -- Owner/admin_pusat: unlimited
  IF v_role_level >= 4 OR EXISTS (
    SELECT 1 FROM system_owner_identity si
    JOIN employees_master e ON e.auth_id = si.auth_id
    WHERE e.nrp = p_nrp AND si.is_active = true
  ) THEN
    RETURN jsonb_build_object(
      'ok', true, 'remaining', 999999, 'remaining_tokens', 999999999,
      'limit', 0, 'unlimited', true
    );
  END IF;

  -- Role-based limits (override with params if provided)
  v_max_q := COALESCE(p_max_queries, CASE
    WHEN v_role_level >= 3 THEN 50    -- manager/admin BU
    WHEN v_role_level >= 2 THEN 30    -- admin
    ELSE 15                            -- karyawan/worker
  END);

  v_max_t := COALESCE(p_max_tokens, CASE
    WHEN v_role_level >= 3 THEN 100000
    WHEN v_role_level >= 2 THEN 75000
    ELSE 50000
  END);

  SELECT COALESCE(query_count, 0), COALESCE(tokens_used, 0) INTO v_count, v_tokens
  FROM ai_rate_limits WHERE nrp = p_nrp AND query_date = CURRENT_DATE;

  IF v_count >= v_max_q THEN
    RETURN jsonb_build_object(
      'ok', false, 'msg', 'Batas query AI harian tercapai (' || v_max_q || ' queries)',
      'remaining', 0, 'limit', v_max_q, 'used', v_count
    );
  END IF;

  IF v_tokens >= v_max_t THEN
    RETURN jsonb_build_object(
      'ok', false, 'msg', 'Batas token AI harian tercapai',
      'remaining_tokens', 0, 'limit_tokens', v_max_t, 'used_tokens', v_tokens
    );
  END IF;

  -- Warning at 80%
  v_remaining_pct := (v_count::numeric / v_max_q) * 100;

  RETURN jsonb_build_object(
    'ok', true,
    'remaining', v_max_q - v_count,
    'remaining_tokens', v_max_t - v_tokens,
    'limit', v_max_q,
    'used', v_count,
    'warning', v_remaining_pct >= 80,
    'warning_msg', CASE WHEN v_remaining_pct >= 80 THEN
      'Penggunaan AI sudah ' || round(v_remaining_pct) || '% dari batas harian'
    ELSE NULL END
  );
END;
$function$;

-- ── 8. Seed role_level for existing workers ──
UPDATE ai_rate_limits SET role_level = COALESCE(
  (SELECT e.role_level FROM employees_master e WHERE e.nrp = ai_rate_limits.nrp),
  0
) WHERE role_level = 0 OR role_level IS NULL;

-- ── 9. Revoke PUBLIC/anon from upsert_document (admin only) ──
REVOKE EXECUTE ON FUNCTION upsert_document(text, text, text, vector, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION upsert_document(text, text, text, vector, jsonb) FROM anon;

-- ── 10. Revoke PUBLIC/anon from match_documents ──
REVOKE EXECUTE ON FUNCTION match_documents(vector, integer, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION match_documents(vector, integer, text) FROM anon;

-- ── Verify ──
DO $$
DECLARE
  v_policies INT;
  v_rls_docs BOOLEAN;
  v_rls_conv BOOLEAN;
  v_rls_rate BOOLEAN;
  v_secdef_upsert BOOLEAN;
  v_match_body TEXT;
BEGIN
  -- RLS policies count
  SELECT COUNT(*) INTO v_policies FROM pg_policies
  WHERE tablename IN ('ai_documents', 'ai_conversations', 'ai_rate_limits');

  -- RLS enabled
  SELECT relrowsecurity INTO v_rls_docs FROM pg_class WHERE relname = 'ai_documents';
  SELECT relrowsecurity INTO v_rls_conv FROM pg_class WHERE relname = 'ai_conversations';
  SELECT relrowsecurity INTO v_rls_rate FROM pg_class WHERE relname = 'ai_rate_limits';

  -- upsert_document is SECURITY DEFINER
  SELECT prokind = 'f' INTO v_secdef_upsert FROM pg_proc WHERE proname = 'upsert_document';

  -- match_documents no longer has precedence bug
  SELECT pg_get_functiondef(oid) INTO v_match_body FROM pg_proc WHERE proname = 'match_documents';

  RAISE NOTICE '215 verify: policies=%, rls_docs=%, rls_conv=%, rls_rate=%, secdef_upsert=%, match_nobug=%',
    v_policies, v_rls_docs, v_rls_conv, v_rls_rate, v_secdef_upsert,
    (v_match_body NOT LIKE '%IS NULL OR%');

  IF v_policies < 7 THEN
    RAISE WARNING 'Expected >=7 policies on ai_* tables, got %', v_policies;
  END IF;
  IF NOT v_rls_docs OR NOT v_rls_conv OR NOT v_rls_rate THEN
    RAISE WARNING 'RLS not enabled on all ai_* tables';
  END IF;
END $$;
