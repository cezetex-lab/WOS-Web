-- ============================================================================
-- 277 — P2-F14-BS: restore mill_boiler (Opsi A keputusan user) + fix 3 RPC
--        42803 (pola AZ) + gate breakdown/packing (pola 274).
--
-- KENAPA 277 INI ADA (temuan BS, audit P1-F14-AA / triage BN)
--   1. get_boiler_status -> 42P01 `relation "public.mill_boiler" does not exist`
--      (probe runtime 2026-10-15, `.agents/logs/bq-prosrc.log`): tabel HILANG dari
--      semua schema padahal definisinya ada di 052_mill_modules.sql:70. Keputusan
--      user 2026-10-17: **Opsi A — restore tabel** (bukan drop fungsi).
--   2. get_breakdown_log / get_packing_log / get_qc_results -> 42803: pola AZ —
--      `SELECT jsonb_build_object(... jsonb_agg(...)) FROM t ORDER BY ... LIMIT n`
--      berada di query AGREGAT tanpa GROUP BY, sehingga kolom non-agregat di
--      ORDER BY/LIMIT level luar ditolak (harus muncul di GROUP BY).
--      Fix: bungkus baris sumber ke subquery ber-ORDER/LIMIT, agregasi di luar
--      (pola terbukti 275: `FROM (SELECT ... ORDER BY id) w`).
--   3. Gate: keputusan BQ — get_breakdown_log & get_packing_log = kelas A
--      (gate in-body) setelah difix. get_qc_results tetap TERBUKA (bucket C,
--      brief eksplisit: tanpa gate). get_boiler_status juga tanpa gate.
--
-- RED PROOF PRA-277 (probe ROLLBACK, nol perubahan persisten; m277-red.log)
--   get_boiler_status()            -> 42P01 mill_boiler does not exist
--   get_breakdown_log()            -> 42803 column bd.breakdown_time must appear...
--   get_packing_log()              -> 42803 (pola sama)
--   get_qc_results()               -> 42803 (pola sama)
--   konsumen TSX tanpa argumen      -> 42883 (get_succession/get_career_path
--                                     tanpa p_nrp; keduanya TANPA DEFAULT)
--
-- YANG SENGAJA TIDAK BERUBAH
--   - get_boiler_status: prosrc TIDAK disentuh — pemulihan tabel membuatnya
--     sembuh sendiri (oid 298291 + md5 8682b9f431785e5c5e474abc20340f68 preserved
--     byte-exact; diverifikasi pasca-apply).
--   - Signature/attrs 3 fungsi fix: (p_limit integer DEFAULT 50), plpgsql,
--     VOLATILE, SECURITY DEFINER, SET search_path TO 'public', 'extensions',
--     oid 298294/298423/298434 preserved (CREATE OR REPLACE, signature sama).
--   - ACL 3 fungsi fix: tidak disentuh ({postgres,authenticated,service_role}).
--   - Return shape per fungsi: kunci jsonb identik pre-image; urutan baris
--     identik (ORDER BY pindah ke subquery — input terurut ke jsonb_agg,
--     teknik sama dengan 275 yang sudah GREEN).
--   - Skema mill_boiler: disalin VERBATIM dari 052_mill_modules.sql:70-86
--     (kolom + CHECK status + UNIQUE boiler_code); data TIDAK di-seed (tabel
--     kosong = GREEN `data:[]` sesuai brief).
--   - RLS/GRANT: mengikuti pola seragam 6 tabel mill live (pola 137):
--     select `auth.uid() IS NOT NULL`, write `authz_check_admin('employee.view_all')`,
--     GRANT ALL (arwdDxtm) ke authenticated + service_role.
--
-- DAMPAK YANG DIAKUI (dicatat jujur, bukan kejutan)
--   Halaman mill DUAL-MOUNT (/admin/mill/* + /worker/*) tanpa guard lokal
--   (module_definitions live). Pasca-gate, worker di /worker/breakdown dan
--   /worker/packing menerima 42501 → BreakdownLog.tsx/PackingLog.tsx menampilkan
--   daftar KOSONG (mereka memakai `data?.data || []` — tidak crash). /worker/qc
--   dan /worker/boiler tetap jalan (tanpa gate). Itu konsekuensi langsung
--   keputusan user: "breakdown & packing butuh gate admin setelah difix".
--
-- REFERENSI
--   Gate: supabase/migrations/274_gate_admin_get_three_rpcs.sql (kondisi 269 X1)
--   Fix subquery: supabase/migrations/275_fix_admin_get_six_broken.sql
--   Skema tabel: supabase/migrations/052_mill_modules.sql:70
--   Rollback: supabase/scripts/rollback/277_rollback.sql
--   Pre-image md5 prosrc: breakdown a4cb6866642f42920311eee0d3e4f2d1 (729) ·
--     packing 27d9b7999d7d9057e54db46aa2bd387d (605) ·
--     qc 71386dc1ac04cb4863397b5d8300a254 (575)
--
-- P4: file ini TIDAK punya baris BEGIN/COMMIT — wrapper apply-migration.mjs
-- yang memegang transaksi.
-- ============================================================================

-- ============================================================================
-- BAGIAN A — Restore mill_boiler (Opsi A, keputusan user 2026-10-17)
-- Skema VERBATIM dari 052_mill_modules.sql:70 (migrasi sumber tabel ini).
-- ============================================================================
CREATE TABLE IF NOT EXISTS mill_boiler (
  id SERIAL PRIMARY KEY,
  boiler_code TEXT NOT NULL UNIQUE,
  boiler_name TEXT NOT NULL,
  capacity_kg_hr NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'OFFLINE' CHECK (status IN ('RUNNING','STANDBY','MAINTENANCE','OFFLINE')),
  temperature_c NUMERIC DEFAULT 0,
  pressure_bar NUMERIC DEFAULT 0,
  steam_flow_kg_hr NUMERIC DEFAULT 0,
  fuel_type TEXT DEFAULT 'BIOMASS',
  fuel_consumption_kg_hr NUMERIC DEFAULT 0,
  efficiency_pct NUMERIC DEFAULT 0,
  last_maintenance DATE,
  next_maintenance DATE,
  site_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE mill_boiler ENABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE mill_boiler TO authenticated, service_role;

DO $$ BEGIN
  CREATE POLICY rls_mill_boiler_select ON mill_boiler FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY rls_mill_boiler_write ON mill_boiler FOR ALL
    USING (authz_check_admin('employee.view_all'::text))
    WITH CHECK (authz_check_admin('employee.view_all'::text));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- BAGIAN B — Fix 42803 + gate (keputusan BQ: breakdown/packing = kelas A)
-- ============================================================================

-- B1. get_breakdown_log — gate pola 274 + subquery pola 275
CREATE OR REPLACE FUNCTION public.get_breakdown_log(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
    FROM (
      SELECT jsonb_build_object(
        'id', bd.id, 'equipment', bd.equipment_code, 'equipment_name', bd.equipment_name,
        'time', bd.breakdown_time, 'resolved', bd.resolved_time,
        'severity', bd.severity, 'category', bd.category,
        'description', bd.description, 'root_cause', bd.root_cause,
        'action', bd.action_taken, 'status', bd.status,
        'downtime', bd.downtime_hours, 'cost', bd.cost,
        'reported_by', bd.reported_by, 'assigned_to', bd.assigned_to
      ) AS sub
      FROM mill_breakdowns bd
      ORDER BY bd.breakdown_time DESC
      LIMIT p_limit
    ) x
  );
END;
$function$;

-- B2. get_packing_log — gate pola 274 + subquery pola 275
CREATE OR REPLACE FUNCTION public.get_packing_log(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_role_assignments WHERE nrp = authz_current_nrp() AND role_code = 'admin_pusat') AND NOT authz_is_owner() THEN
    RAISE EXCEPTION 'Akses ditolak. Hanya admin_pusat.' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
    FROM (
      SELECT jsonb_build_object(
        'id', pk.id, 'date', pk.pack_date, 'time', pk.pack_time,
        'product', pk.product_type, 'quantity', pk.quantity_kg,
        'batch_id', pk.batch_id, 'destination', pk.destination,
        'truck_plate', pk.truck_plate, 'driver', pk.driver_name,
        'status', pk.status, 'qc_status', pk.qc_status
      ) AS sub
      FROM mill_packing pk
      ORDER BY pk.pack_date DESC, pk.pack_time DESC
      LIMIT p_limit
    ) x
  );
END;
$function$;

-- B3. get_qc_results — subquery pola 275, TANPA gate (bucket C terbuka;
--     keputusan user: hanya breakdown + packing yang di-gate)
CREATE OR REPLACE FUNCTION public.get_qc_results(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
    FROM (
      SELECT jsonb_build_object(
        'id', q.id, 'batch_id', q.batch_id, 'date', q.sample_date,
        'time', q.sample_time, 'ffa', q.ffa_pct, 'moisture', q.moisture_pct,
        'dobi', q.dobi, 'color', q.color, 'dirt', q.dirt_pct,
        'result', q.result, 'tested_by', q.tested_by, 'notes', q.notes
      ) AS sub
      FROM mill_qc_results q
      ORDER BY q.sample_date DESC, q.sample_time DESC
      LIMIT p_limit
    ) x
  );
END;
$function$;
