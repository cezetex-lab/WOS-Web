-- ================================================================
-- 008_restore_missing_objects.sql — pulihkan objek yang sumber migrasinya hilang
--
-- KENAPA ADA: repo bukan histori utuh (79 nomor versi tak punya berkas; §5.8 SQL-10),
-- jadi 25 tabel yang dipakai live tidak pernah dibuat berkas mana pun → instalasi
-- dari awal GAGAL (kasus: 047 INSERT INTO hr_shift_swaps / webhook_logs / safety_incidents
-- relation "hr_shift_swaps" does not exist).
--
-- Berkas ini kembalikan 25 tabel dengan DDL dari DB live (baseline/000), jadi hasilnya
-- identik live: PK/UNIQUE/CHECK, index, RLS enable+force (policy dipindah ke 229).
-- Nomor 008 dipakai karena 8-26 kosong dan berkas ini harus jalan SEBELUM 011/018/027/047.
--
-- SIFAT: idempoten (CREATE IF NOT EXISTS + guard pg_constraint) → no-op di live.
--   POLICY (DROP IF EXISTS+CREATE) DITOLAK ke 229 karena:
--   - ai_rate_limits policy mereferensi employees_master.auth_id (kolom baru di 071);
--   - hr_okr_results/hr_survey_responses policy mereferensi hr_okrs/hr_surveys (141).
--   FK ke hr_okrs/hr_surveys TIDAK dipasang (type mismatch: okr_id/survey_id INTEGER
--   vs id TEXT; tidak ada referential constraint di live).
--   `_legacy_*` TIDAK dibuat: ada di live karena RENAME manual, tak perlu di instalasi
--   baru (REVOKE diberi guard to_regprocedure di 210).
--   TIDAK ada BEGIN/COMMIT: wrapper npm run db:migrate sudah bungkus SQL+schema_migrations
--   dalam SATU transaksi.
-- ================================================================

-- ── ai_rate_limits 
CREATE SEQUENCE IF NOT EXISTS public.ai_rate_limits_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.ai_rate_limits (
  id integer DEFAULT nextval('ai_rate_limits_id_seq'::regclass) NOT NULL,
  nrp text NOT NULL,
  query_date date DEFAULT CURRENT_DATE,
  query_count integer DEFAULT 1,
  tokens_used bigint DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  role_level integer DEFAULT 0
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ai_rate_limits_pkey' AND conrelid = 'public.ai_rate_limits'::regclass) THEN ALTER TABLE public.ai_rate_limits ADD CONSTRAINT ai_rate_limits_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ai_rate_limits_nrp_query_date_key' AND conrelid = 'public.ai_rate_limits'::regclass) THEN ALTER TABLE public.ai_rate_limits ADD CONSTRAINT ai_rate_limits_nrp_query_date_key UNIQUE (nrp, query_date); END IF; END $$;
ALTER SEQUENCE public.ai_rate_limits_id_seq OWNED BY public.ai_rate_limits.id;
ALTER TABLE public.ai_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_rate_limits FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ai_rate_limits FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.ai_rate_limits TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.ai_rate_limits TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.ai_rate_limits TO service_role;

-- ── api_keys 
CREATE SEQUENCE IF NOT EXISTS public.api_keys_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.api_keys (
  id integer DEFAULT nextval('api_keys_id_seq'::regclass) NOT NULL,
  key_name text NOT NULL,
  key_hash text NOT NULL,
  owner_nrp text,
  scope text DEFAULT 'read'::text,
  is_active boolean DEFAULT true,
  rate_limit_per_minute integer DEFAULT 60,
  rate_limit_per_hour integer DEFAULT 1000,
  created_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'api_keys_pkey' AND conrelid = 'public.api_keys'::regclass) THEN ALTER TABLE public.api_keys ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'api_keys_key_name_key' AND conrelid = 'public.api_keys'::regclass) THEN ALTER TABLE public.api_keys ADD CONSTRAINT api_keys_key_name_key UNIQUE (key_name); END IF; END $$;
ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_keys FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.api_keys FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.api_keys TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.api_keys TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.api_keys TO service_role;

-- ── api_rate_limits 
CREATE SEQUENCE IF NOT EXISTS public.api_rate_limits_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
  id integer DEFAULT nextval('api_rate_limits_id_seq'::regclass) NOT NULL,
  api_key_id integer,
  window_start timestamp with time zone DEFAULT date_trunc('minute'::text, now()) NOT NULL,
  request_count integer DEFAULT 1
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'api_rate_limits_pkey' AND conrelid = 'public.api_rate_limits'::regclass) THEN ALTER TABLE public.api_rate_limits ADD CONSTRAINT api_rate_limits_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'api_rate_limits_api_key_id_window_start_key' AND conrelid = 'public.api_rate_limits'::regclass) THEN ALTER TABLE public.api_rate_limits ADD CONSTRAINT api_rate_limits_api_key_id_window_start_key UNIQUE (api_key_id, window_start); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'api_rate_limits_api_key_id_fkey' AND conrelid = 'public.api_rate_limits'::regclass) THEN ALTER TABLE public.api_rate_limits ADD CONSTRAINT api_rate_limits_api_key_id_fkey FOREIGN KEY (api_key_id) REFERENCES api_keys(id) ON DELETE CASCADE; END IF; END $$;
ALTER SEQUENCE public.api_rate_limits_id_seq OWNED BY public.api_rate_limits.id;
ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_rate_limits FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.api_rate_limits FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.api_rate_limits TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.api_rate_limits TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.api_rate_limits TO service_role;

-- ── dashboard_cache 
CREATE SEQUENCE IF NOT EXISTS public.dashboard_cache_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.dashboard_cache (
  id integer DEFAULT nextval('dashboard_cache_id_seq'::regclass) NOT NULL,
  cache_key text NOT NULL,
  cache_data jsonb NOT NULL,
  cached_at timestamp with time zone DEFAULT now(),
  ttl_seconds integer DEFAULT 300,
  hit_count integer DEFAULT 0
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dashboard_cache_pkey' AND conrelid = 'public.dashboard_cache'::regclass) THEN ALTER TABLE public.dashboard_cache ADD CONSTRAINT dashboard_cache_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dashboard_cache_cache_key_key' AND conrelid = 'public.dashboard_cache'::regclass) THEN ALTER TABLE public.dashboard_cache ADD CONSTRAINT dashboard_cache_cache_key_key UNIQUE (cache_key); END IF; END $$;
ALTER SEQUENCE public.dashboard_cache_id_seq OWNED BY public.dashboard_cache.id;
ALTER TABLE public.dashboard_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_cache FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dashboard_cache FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dashboard_cache TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dashboard_cache TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dashboard_cache TO service_role;

-- ── estate_field 
CREATE TABLE IF NOT EXISTS public.estate_field (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  activity_type text,
  block_name text,
  worker_count integer DEFAULT 0,
  description text,
  supervisor_nama text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'estate_field_pkey' AND conrelid = 'public.estate_field'::regclass) THEN ALTER TABLE public.estate_field ADD CONSTRAINT estate_field_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.estate_field ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_field FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_field FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_field TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_field TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_field TO service_role;

-- ── estate_irrigation 
CREATE TABLE IF NOT EXISTS public.estate_irrigation (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  block_name text,
  water_level numeric DEFAULT 0,
  ph_level numeric DEFAULT 7,
  status text DEFAULT 'NORMAL'::text,
  operator_nama text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'estate_irrigation_pkey' AND conrelid = 'public.estate_irrigation'::regclass) THEN ALTER TABLE public.estate_irrigation ADD CONSTRAINT estate_irrigation_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.estate_irrigation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_irrigation FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_irrigation FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_irrigation TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_irrigation TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_irrigation TO service_role;

-- ── estate_nursery 
CREATE TABLE IF NOT EXISTS public.estate_nursery (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  nursery_name text,
  seedling_type text,
  quantity integer DEFAULT 0,
  age_weeks integer DEFAULT 0,
  health_status text DEFAULT 'GOOD'::text,
  target_date date,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'estate_nursery_pkey' AND conrelid = 'public.estate_nursery'::regclass) THEN ALTER TABLE public.estate_nursery ADD CONSTRAINT estate_nursery_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.estate_nursery ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_nursery FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_nursery FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_nursery TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_nursery TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_nursery TO service_role;

-- ── estate_transport 
CREATE TABLE IF NOT EXISTS public.estate_transport (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  vehicle_code text,
  driver_nama text,
  tonnage numeric DEFAULT 0,
  origin text,
  destination text,
  status text DEFAULT 'IN_TRANSIT'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'estate_transport_pkey' AND conrelid = 'public.estate_transport'::regclass) THEN ALTER TABLE public.estate_transport ADD CONSTRAINT estate_transport_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.estate_transport ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_transport FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_transport FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_transport TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_transport TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_transport TO service_role;

-- ── estate_yield 
CREATE TABLE IF NOT EXISTS public.estate_yield (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  month text,
  block_name text,
  actual_tonnage numeric DEFAULT 0,
  target_tonnage numeric DEFAULT 0,
  achievement_pct numeric DEFAULT 0,
  status text DEFAULT 'ON_TRACK'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'estate_yield_pkey' AND conrelid = 'public.estate_yield'::regclass) THEN ALTER TABLE public.estate_yield ADD CONSTRAINT estate_yield_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.estate_yield ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_yield FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_yield FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_yield TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_yield TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.estate_yield TO service_role;

-- ── hr_audit_chain 
CREATE SEQUENCE IF NOT EXISTS public.hr_audit_chain_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.hr_audit_chain (
  id integer DEFAULT nextval('hr_audit_chain_id_seq'::regclass) NOT NULL,
  action text NOT NULL,
  actor_nrp text,
  details jsonb,
  prev_hash text,
  chain_hash text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_audit_chain_pkey' AND conrelid = 'public.hr_audit_chain'::regclass) THEN ALTER TABLE public.hr_audit_chain ADD CONSTRAINT hr_audit_chain_pkey PRIMARY KEY (id); END IF; END $$;
ALTER SEQUENCE public.hr_audit_chain_id_seq OWNED BY public.hr_audit_chain.id;
ALTER TABLE public.hr_audit_chain ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_audit_chain FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.hr_audit_chain FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_audit_chain TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_audit_chain TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_audit_chain TO service_role;

-- ── hr_okr_results 
CREATE SEQUENCE IF NOT EXISTS public.hr_okr_results_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.hr_okr_results (
  id integer DEFAULT nextval('hr_okr_results_id_seq'::regclass) NOT NULL,
  okr_id integer,
  key_result text NOT NULL,
  target_val numeric DEFAULT 100,
  actual_val numeric DEFAULT 0,
  unit text DEFAULT '%'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_okr_results_pkey' AND conrelid = 'public.hr_okr_results'::regclass) THEN ALTER TABLE public.hr_okr_results ADD CONSTRAINT hr_okr_results_pkey PRIMARY KEY (id); END IF; END $$;
ALTER SEQUENCE public.hr_okr_results_id_seq OWNED BY public.hr_okr_results.id;
ALTER TABLE public.hr_okr_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_okr_results FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.hr_okr_results FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_okr_results TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_okr_results TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_okr_results TO service_role;

-- ── hr_shift_swaps 
CREATE SEQUENCE IF NOT EXISTS public.hr_shift_swaps_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.hr_shift_swaps (
  id integer DEFAULT nextval('hr_shift_swaps_id_seq'::regclass) NOT NULL,
  requester_nrp text NOT NULL,
  target_nrp text,
  request_date date NOT NULL,
  target_date date,
  status text DEFAULT 'pending'::text,
  approver_nrp text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_shift_swaps_pkey' AND conrelid = 'public.hr_shift_swaps'::regclass) THEN ALTER TABLE public.hr_shift_swaps ADD CONSTRAINT hr_shift_swaps_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_shift_swaps_status_check' AND conrelid = 'public.hr_shift_swaps'::regclass) THEN ALTER TABLE public.hr_shift_swaps ADD CONSTRAINT hr_shift_swaps_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))); END IF; END $$;
ALTER SEQUENCE public.hr_shift_swaps_id_seq OWNED BY public.hr_shift_swaps.id;
ALTER TABLE public.hr_shift_swaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_shift_swaps FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.hr_shift_swaps FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_shift_swaps TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_shift_swaps TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_shift_swaps TO service_role;

-- ── hr_survey_responses 
CREATE SEQUENCE IF NOT EXISTS public.hr_survey_responses_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.hr_survey_responses (
  id integer DEFAULT nextval('hr_survey_responses_id_seq'::regclass) NOT NULL,
  survey_id integer,
  nrp text NOT NULL,
  answers jsonb DEFAULT '{}'::jsonb,
  score integer,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_survey_responses_pkey' AND conrelid = 'public.hr_survey_responses'::regclass) THEN ALTER TABLE public.hr_survey_responses ADD CONSTRAINT hr_survey_responses_pkey PRIMARY KEY (id); END IF; END $$;
ALTER SEQUENCE public.hr_survey_responses_id_seq OWNED BY public.hr_survey_responses.id;
ALTER TABLE public.hr_survey_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_survey_responses FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.hr_survey_responses FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_survey_responses TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_survey_responses TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_survey_responses TO service_role;

-- ── hr_task_board 
CREATE SEQUENCE IF NOT EXISTS public.hr_task_board_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.hr_task_board (
  id integer DEFAULT nextval('hr_task_board_id_seq'::regclass) NOT NULL,
  nrp text NOT NULL,
  assigner_nrp text,
  title text NOT NULL,
  description text,
  status text DEFAULT 'todo'::text,
  priority text DEFAULT 'medium'::text,
  due_date date,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_task_board_pkey' AND conrelid = 'public.hr_task_board'::regclass) THEN ALTER TABLE public.hr_task_board ADD CONSTRAINT hr_task_board_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_task_board_priority_check' AND conrelid = 'public.hr_task_board'::regclass) THEN ALTER TABLE public.hr_task_board ADD CONSTRAINT hr_task_board_priority_check CHECK ((priority = ANY (ARRAY['high'::text, 'medium'::text, 'low'::text]))); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hr_task_board_status_check' AND conrelid = 'public.hr_task_board'::regclass) THEN ALTER TABLE public.hr_task_board ADD CONSTRAINT hr_task_board_status_check CHECK ((status = ANY (ARRAY['todo'::text, 'doing'::text, 'done'::text]))); END IF; END $$;
ALTER SEQUENCE public.hr_task_board_id_seq OWNED BY public.hr_task_board.id;
ALTER TABLE public.hr_task_board ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_task_board FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.hr_task_board FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_task_board TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_task_board TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hr_task_board TO service_role;

-- ── mill_breakdown 
CREATE TABLE IF NOT EXISTS public.mill_breakdown (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  equipment_id text,
  equipment_name text,
  breakdown_type text,
  severity text,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  status text DEFAULT 'OPEN'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mill_breakdown_pkey' AND conrelid = 'public.mill_breakdown'::regclass) THEN ALTER TABLE public.mill_breakdown ADD CONSTRAINT mill_breakdown_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mill_breakdown ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mill_breakdown FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mill_breakdown FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_breakdown TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_breakdown TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_breakdown TO service_role;

-- ── mill_qc 
CREATE TABLE IF NOT EXISTS public.mill_qc (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  batch_id text,
  ffa_pct numeric DEFAULT 0,
  moisture_pct numeric DEFAULT 0,
  dobii numeric DEFAULT 0,
  grade text,
  status text DEFAULT 'PASSED'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mill_qc_pkey' AND conrelid = 'public.mill_qc'::regclass) THEN ALTER TABLE public.mill_qc ADD CONSTRAINT mill_qc_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mill_qc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mill_qc FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mill_qc FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_qc TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_qc TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_qc TO service_role;

-- ── mill_shift 
CREATE TABLE IF NOT EXISTS public.mill_shift (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  shift_name text,
  start_time time without time zone,
  end_time time without time zone,
  headcount integer DEFAULT 0,
  supervisor_nama text,
  status text DEFAULT 'ACTIVE'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mill_shift_pkey' AND conrelid = 'public.mill_shift'::regclass) THEN ALTER TABLE public.mill_shift ADD CONSTRAINT mill_shift_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mill_shift ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mill_shift FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mill_shift FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_shift TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_shift TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mill_shift TO service_role;

-- ── mining_fatigue 
CREATE TABLE IF NOT EXISTS public.mining_fatigue (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  nrp text,
  nama text,
  shift text,
  fatigue_level integer DEFAULT 0,
  hours_worked numeric DEFAULT 0,
  rest_hours numeric DEFAULT 0,
  status text DEFAULT 'NORMAL'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mining_fatigue_pkey' AND conrelid = 'public.mining_fatigue'::regclass) THEN ALTER TABLE public.mining_fatigue ADD CONSTRAINT mining_fatigue_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mining_fatigue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mining_fatigue FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mining_fatigue FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_fatigue TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_fatigue TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_fatigue TO service_role;

-- ── mining_fuel 
CREATE TABLE IF NOT EXISTS public.mining_fuel (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  equipment_code text,
  fuel_type text,
  liters numeric DEFAULT 0,
  driver_nrp text,
  driver_nama text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mining_fuel_pkey' AND conrelid = 'public.mining_fuel'::regclass) THEN ALTER TABLE public.mining_fuel ADD CONSTRAINT mining_fuel_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mining_fuel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mining_fuel FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mining_fuel FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_fuel TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_fuel TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_fuel TO service_role;

-- ── mining_jsa 
CREATE TABLE IF NOT EXISTS public.mining_jsa (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  job_name text,
  hazard text,
  risk_level text,
  control_measure text,
  prepared_by text,
  approved_by text,
  status text DEFAULT 'DRAFT'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mining_jsa_pkey' AND conrelid = 'public.mining_jsa'::regclass) THEN ALTER TABLE public.mining_jsa ADD CONSTRAINT mining_jsa_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mining_jsa ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mining_jsa FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mining_jsa FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_jsa TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_jsa TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_jsa TO service_role;

-- ── mining_production 
CREATE TABLE IF NOT EXISTS public.mining_production (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  pit_name text,
  tonnage numeric DEFAULT 0,
  truck_count integer DEFAULT 0,
  fuel_used numeric DEFAULT 0,
  status text DEFAULT 'COMPLETED'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mining_production_pkey' AND conrelid = 'public.mining_production'::regclass) THEN ALTER TABLE public.mining_production ADD CONSTRAINT mining_production_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mining_production ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mining_production FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mining_production FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_production TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_production TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_production TO service_role;

-- ── mining_safety 
CREATE TABLE IF NOT EXISTS public.mining_safety (
  id text DEFAULT (gen_random_uuid())::text NOT NULL,
  business_unit_id text,
  date date DEFAULT CURRENT_DATE,
  incident_type text,
  severity text,
  location text,
  description text,
  reported_by text,
  status text DEFAULT 'OPEN'::text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mining_safety_pkey' AND conrelid = 'public.mining_safety'::regclass) THEN ALTER TABLE public.mining_safety ADD CONSTRAINT mining_safety_pkey PRIMARY KEY (id); END IF; END $$;
ALTER TABLE public.mining_safety ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mining_safety FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.mining_safety FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_safety TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_safety TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.mining_safety TO service_role;

-- ── safety_incidents 
CREATE TABLE IF NOT EXISTS public.safety_incidents (
  id text NOT NULL,
  incident_date date DEFAULT CURRENT_DATE NOT NULL,
  zone text NOT NULL,
  incident_type text DEFAULT 'INCIDENT'::text NOT NULL,
  severity text DEFAULT 'MEDIUM'::text NOT NULL,
  description text NOT NULL,
  reporter_nrp text NOT NULL,
  status text DEFAULT 'OPEN'::text NOT NULL,
  action_taken text,
  business_unit_id text,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'safety_incidents_pkey' AND conrelid = 'public.safety_incidents'::regclass) THEN ALTER TABLE public.safety_incidents ADD CONSTRAINT safety_incidents_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'safety_incidents_severity_chk' AND conrelid = 'public.safety_incidents'::regclass) THEN ALTER TABLE public.safety_incidents ADD CONSTRAINT safety_incidents_severity_chk CHECK ((severity = ANY (ARRAY['LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text]))); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'safety_incidents_status_chk' AND conrelid = 'public.safety_incidents'::regclass) THEN ALTER TABLE public.safety_incidents ADD CONSTRAINT safety_incidents_status_chk CHECK ((status = ANY (ARRAY['OPEN'::text, 'INVESTIGATING'::text, 'CLOSED'::text]))); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'safety_incidents_type_chk' AND conrelid = 'public.safety_incidents'::regclass) THEN ALTER TABLE public.safety_incidents ADD CONSTRAINT safety_incidents_type_chk CHECK ((incident_type = ANY (ARRAY['NEAR_MISS'::text, 'INCIDENT'::text, 'OBSERVATION'::text]))); END IF; END $$;
ALTER TABLE public.safety_incidents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.safety_incidents FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.safety_incidents TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.safety_incidents TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.safety_incidents TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.safety_incidents TO service_role;

-- ── user_consents 
CREATE SEQUENCE IF NOT EXISTS public.user_consents_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.user_consents (
  id integer DEFAULT nextval('user_consents_id_seq'::regclass) NOT NULL,
  nrp text NOT NULL,
  consent_type text NOT NULL,
  consent_given boolean DEFAULT false NOT NULL,
  consent_version text DEFAULT '1.0'::text,
  ip_address inet,
  user_agent text,
  revoked_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_consents_pkey' AND conrelid = 'public.user_consents'::regclass) THEN ALTER TABLE public.user_consents ADD CONSTRAINT user_consents_pkey PRIMARY KEY (id); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_consents_nrp_consent_type_key' AND conrelid = 'public.user_consents'::regclass) THEN ALTER TABLE public.user_consents ADD CONSTRAINT user_consents_nrp_consent_type_key UNIQUE (nrp, consent_type); END IF; END $$;
ALTER SEQUENCE public.user_consents_id_seq OWNED BY public.user_consents.id;
ALTER TABLE public.user_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_consents FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_consents FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_consents TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_consents TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_consents TO service_role;

-- ── webhook_logs 
CREATE SEQUENCE IF NOT EXISTS public.webhook_logs_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 NO CYCLE;
CREATE TABLE IF NOT EXISTS public.webhook_logs (
  id integer DEFAULT nextval('webhook_logs_id_seq'::regclass) NOT NULL,
  event_type text,
  payload text,
  target_url text,
  status text DEFAULT 'PENDING'::text,
  response_code integer,
  created_at timestamp with time zone DEFAULT now()
);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'webhook_logs_pkey' AND conrelid = 'public.webhook_logs'::regclass) THEN ALTER TABLE public.webhook_logs ADD CONSTRAINT webhook_logs_pkey PRIMARY KEY (id); END IF; END $$;
ALTER SEQUENCE public.webhook_logs_id_seq OWNED BY public.webhook_logs.id;
ALTER TABLE public.webhook_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_logs FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.webhook_logs FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.webhook_logs TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.webhook_logs TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.webhook_logs TO service_role;

