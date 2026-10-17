-- ============================================================================
-- 276 — P2-F14-BQ Tahap 2: Scope-by-NRP 13 RPC (Rekomendasi B) + RLS 2 tabel.
--
-- KEPUTUSAN USER (2026-10-17, brief eksekusi 276): setujui Rekomendasi B
-- (SCOPE-BY-NRP) untuk 13 RPC = 11 RPC rekomendasi B asli
-- (fatigue/simper/worker_kpi/perf_team/team_data/perf_notes/career_path +
--  tulis: harvest_record/forum_post/reply/safety_incident)
-- + get_maintenance_schedule (scoping kolom cost+parts_used, keputusan user)
-- + 2 RPC INVOKER via ubah RLS SELECT (harvest_records/transport_dispatch,
--   hasil investigasi Tahap 1: policy lama = hardening generik 137,
--   BUKAN keputusan produk eksplisit -> C direvisi jadi B).
--
-- ATURAN BODY (brief):
--   READ  : nrp difilter ke authz_current_nrp() KECUALI caller admin
--           (authz_check_admin('employee.view_all') — pola whitelist BQ).
--   WRITE : param p_nrp/p_author DIPERCAYA hanya utk admin; caller non-admin
--           DIPAKSA authz_current_nrp() (anti impersonasi — probe BQ
--           membuktikan 5 fungsi tulis dipercaya apa adanya).
--   PRESERVE: signature (termasuk DEFAULT arg), return shape {ok,data},
--           ACL, SECURITY DEFINER + search_path — TIDAK berubah.
--
-- get_maintenance_schedule (keputusan user, brief Langkah 1B):
--   kolom cost + parts_used di jsonb_build_object dibungkus
--   CASE WHEN authz_check_admin('employee.view_all') THEN ... ELSE NULL
--   (jadwal tetap terlihat worker; angka finansial + parts tersembunyi).
--
-- RLS (2 tabel INVOKER — fungsi get_harvest_records/get_transport_dispatch
-- tidak diubah sama sekali; mereka INVOKER jadi RLS = satu-satunya pelindung):
--   harvest_records SELECT : worker_nrp = authz_current_nrp() OR admin
--   transport_dispatch SELECT : driver_nrp = authz_current_nrp() OR admin
--   Policy WRITE (authz_check_admin) TIDAK disentuh.
--
-- ROLLBACK: supabase/scripts/rollback/276_rollback.sql (pre-image byte-exact
-- dari pg_get_functiondef live + definisi policy pra-276).
-- Bukti probe: RED pre-apply + GREEN post-apply di agentsLogs_2026-10.md.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BAGIAN A — RLS SELECT policy (2 tabel INVOKER)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "rls_harvest_records_select" ON public.harvest_records;
CREATE POLICY "rls_harvest_records_select"
  ON public.harvest_records FOR SELECT TO public
  USING ((worker_nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'::text)));

DROP POLICY IF EXISTS "rls_transport_dispatch_select" ON public.transport_dispatch;
CREATE POLICY "rls_transport_dispatch_select"
  ON public.transport_dispatch FOR SELECT TO public
  USING ((driver_nrp = authz_current_nrp() OR authz_check_admin('employee.view_all'::text)));

-- ---------------------------------------------------------------------------
-- BAGIAN B — 12 fungsi DEFINER: scope-by-NRP
-- ---------------------------------------------------------------------------

-- 1. get_fatigue_data(p_nrp DEFAULT NULL) — READ
--    Pra: (p_nrp IS NULL OR fd.nrp = p_nrp) -> worker tanpa arg = SELURUH populasi.
CREATE OR REPLACE FUNCTION public.get_fatigue_data(p_nrp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'nrp', fd.nrp, 'name', fd.nama, 'shift', fd.shift,
        'hours_worked', fd.hours_worked, 'hours_rest', fd.hours_rest,
        'fatigue_level', fd.fatigue_level, 'status', fd.status,
        'last_check', fd.last_check
      ) as sub
      FROM fatigue_data fd
      WHERE (CASE WHEN v_is_admin THEN (p_nrp IS NULL OR fd.nrp = p_nrp)
                  ELSE fd.nrp = v_nrp END)
      ORDER BY fd.fatigue_level DESC, fd.nama
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 2. get_simper_list(p_nrp DEFAULT NULL) — READ (pola sama fatigue)
CREATE OR REPLACE FUNCTION public.get_simper_list(p_nrp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
BEGIN
  RETURN jsonb_build_object('ok', true, 'data', COALESCE((
    SELECT jsonb_agg(sub)
    FROM (
      SELECT jsonb_build_object(
        'id', sd.id, 'nrp', sd.nrp, 'zone', sd.zone,
        'purpose', sd.purpose, 'status', sd.status,
        'valid_until', sd.valid_until, 'issued_by', sd.issued_by
      ) as sub
      FROM simper_data sd
      WHERE (CASE WHEN v_is_admin THEN (p_nrp IS NULL OR sd.nrp = p_nrp)
                  ELSE sd.nrp = v_nrp END)
      ORDER BY sd.valid_until DESC
    ) t
  ), '[]'::jsonb));
END;
$function$;

-- 3. get_worker_kpi(p_nrp) — READ (cross-scope terbukti RED: NRP002->NRP001 ok:true)
CREATE OR REPLACE FUNCTION public.get_worker_kpi(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := CASE WHEN authz_check_admin('employee.view_all') THEN p_nrp ELSE authz_current_nrp() END;
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('periode',periode,'kpi_score',kpi_score,'feedback',feedback_json)
    ORDER BY created_at DESC),'[]'::jsonb))
  FROM hr_performance WHERE nrp=v_eff LIMIT 12); END;
$function$;

-- 4. get_continuous_perf_team(p_nrp) — READ (pindai tim atasan bebas -> scoped)
CREATE OR REPLACE FUNCTION public.get_continuous_perf_team(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := CASE WHEN authz_check_admin('employee.view_all') THEN p_nrp ELSE authz_current_nrp() END;
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',p.nrp,'nama',e.nama,'periode',p.periode,'kpi_score',p.kpi_score)
    ORDER BY p.periode DESC),'[]'::jsonb))
  FROM hr_performance p JOIN hr_org o ON o.nrp=p.nrp AND o.atasan_nrp=v_eff
  LEFT JOIN employees_master e ON e.nrp=p.nrp
  WHERE p.periode IS NOT NULL
  LIMIT 20); END;
$function$;

-- 5. get_team_data(p_nrp) — READ (pola sama perf_team)
CREATE OR REPLACE FUNCTION public.get_team_data(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := CASE WHEN authz_check_admin('employee.view_all') THEN p_nrp ELSE authz_current_nrp() END;
BEGIN RETURN (
  SELECT jsonb_build_object('ok',true,'data',COALESCE(jsonb_agg(
    jsonb_build_object('nrp',e.nrp,'nama',e.nama,'posisi',e.posisi,'divisi',e.divisi,
      'kpi_score',COALESCE(p.kpi_score,0),'status_kerja',e.status_kerja)
    ORDER BY e.nama),'[]'::jsonb))
  FROM hr_org o JOIN employees_master e ON e.nrp=o.nrp
  LEFT JOIN hr_performance p ON p.nrp=o.nrp AND p.periode=(
    SELECT MAX(periode) FROM hr_performance)
  WHERE o.atasan_nrp=v_eff); END;
$function$;

-- 6. get_performance_notes(p_nrp) — READ (teks evaluasi HR lintas-orang -> scoped)
CREATE OR REPLACE FUNCTION public.get_performance_notes(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_eff text := CASE WHEN authz_check_admin('employee.view_all') THEN p_nrp ELSE authz_current_nrp() END;
BEGIN
  RETURN (
    SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'nrp', n.nrp,
        'author', n.author_nrp,
        'type', n.note_type,
        'content', n.content,
        'created_at', n.created_at
      ) ORDER BY n.created_at DESC
    ), '[]'::jsonb))
    FROM performance_notes n
    WHERE n.nrp = v_eff OR n.author_nrp = v_eff
    LIMIT 50
  );
END;
$function$;

-- 7. get_career_path(p_nrp) — READ (RED proof: cross-scope DATA NYATA terbukti)
CREATE OR REPLACE FUNCTION public.get_career_path(p_nrp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_emp RECORD;
  v_skills JSONB;
  v_next_level INT;
  v_recommendations TEXT[];
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_eff text := CASE WHEN v_is_admin THEN p_nrp ELSE v_nrp END;
BEGIN
  -- Get employee data (scoped: non-admin hanya boleh baca dirinya sendiri)
  SELECT e.nrp, e.nama, e.posisi, e.divisi, e.business_unit,
         COALESCE(ur.role_level, 1) AS current_level
  INTO v_emp
  FROM employees_master e
  LEFT JOIN user_roles ur ON ur.nrp = e.nrp
  WHERE e.nrp = v_eff;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Employee not found');
  END IF;

  -- Get current skills
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('skill', skill_name, 'level', level, 'target_level', target_level)
  ), '[]'::jsonb)
  INTO v_skills
  FROM hr_skills
  WHERE nrp = v_eff;

  -- Determine next level (max 5)
  v_next_level := LEAST(v_emp.current_level + 1, 5);

  -- Generate recommendations based on skill gaps
  SELECT ARRAY_AGG('Pelatihan ' || skill_name || ' (level ' || target_level || ')')
  INTO v_recommendations
  FROM hr_skills
  WHERE nrp = v_eff AND level < target_level
  LIMIT 3;

  RETURN jsonb_build_object(
    'ok', true,
    'current_position', v_emp.posisi,
    'current_level', v_emp.current_level,
    'next_level', v_next_level,
    'division', v_emp.divisi,
    'business_unit', v_emp.business_unit,
    'skills', v_skills,
    'recommendations', COALESCE(v_recommendations, ARRAY[]::TEXT[]),
    'career_path', jsonb_build_array(
      jsonb_build_object('level', 1, 'title', 'Staff'),
      jsonb_build_object('level', 2, 'title', 'Senior Staff'),
      jsonb_build_object('level', 3, 'title', 'Supervisor'),
      jsonb_build_object('level', 4, 'title', 'Manager'),
      jsonb_build_object('level', 5, 'title', 'Director')
    )
  );
END;
$function$;

-- 8. get_maintenance_schedule(p_site_code DEFAULT NULL) — READ + sembunyi cost/parts
--    (keputusan user 2026-10-17: jadwal terlihat semua; angka finansial admin-only)
CREATE OR REPLACE FUNCTION public.get_maintenance_schedule(p_site_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_admin boolean := authz_check_admin('employee.view_all');
BEGIN
  RETURN (SELECT jsonb_build_object('ok', true, 'data', COALESCE(jsonb_agg(sub), '[]'::jsonb))
  FROM (
    SELECT jsonb_build_object(
      'id', m.id, 'equipment_code', m.equipment_code, 'equipment_name', m.equipment_name,
      'maintenance_type', m.maintenance_type, 'description', m.description,
      'scheduled_date', m.scheduled_date, 'completed_date', m.completed_date,
      'status', m.status, 'assigned_to', m.assigned_to, 'priority', m.priority,
      'cost', CASE WHEN v_is_admin THEN m.cost ELSE NULL END,
      'parts_used', CASE WHEN v_is_admin THEN m.parts_used ELSE NULL END,
      'downtime_hours', m.downtime_hours,
      'site_code', m.site_code
    ) AS sub
    FROM mill_maintenance m
    WHERE p_site_code IS NULL OR m.site_code = p_site_code
    ORDER BY m.scheduled_date DESC
  ) sub);
END;
$function$;

-- 9. create_harvest_record(...) — WRITE (worker_nrp dipaksa claims utk non-admin)
CREATE OR REPLACE FUNCTION public.create_harvest_record(p_nrp text, p_block text, p_weight_kg numeric, p_ripe_pct numeric DEFAULT 0, p_quality text DEFAULT 'B'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_id text;
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_eff text := CASE WHEN v_is_admin THEN p_nrp ELSE v_nrp END;
BEGIN
  IF v_eff IS NULL OR v_eff = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_block IS NULL OR p_block = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Blok wajib dipilih.');
  END IF;
  IF p_weight_kg IS NULL OR p_weight_kg <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Berat harus lebih dari 0.');
  END IF;
  v_id := 'HVT-' || encode(gen_random_bytes(4), 'hex');
  INSERT INTO harvest_records (id, block, harvest_date, weight_kg, ripe_pct, worker_nrp, quality)
  VALUES (v_id, p_block, CURRENT_DATE, p_weight_kg,
          COALESCE(p_ripe_pct, 0), v_eff, COALESCE(p_quality, 'B'));
  RETURN jsonb_build_object('ok', true, 'msg', 'Panen tercatat.', 'id', v_id);
END;
$function$;

-- 10. report_safety_incident(...) — WRITE (reporter_nrp dipaksa claims utk non-admin)
CREATE OR REPLACE FUNCTION public.report_safety_incident(p_nrp text, p_type text, p_zone text, p_desc text, p_severity text DEFAULT 'MEDIUM'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_id text;
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_eff text := CASE WHEN v_is_admin THEN p_nrp ELSE v_nrp END;
BEGIN
  IF v_eff IS NULL OR v_eff = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'NRP wajib diisi.');
  END IF;
  IF p_desc IS NULL OR p_desc = '' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Deskripsi wajib diisi.');
  END IF;
  v_id := 'SAF-' || encode(gen_random_bytes(4), 'hex');
  INSERT INTO safety_incidents (id, incident_date, zone, incident_type, severity, description, reporter_nrp, status)
  VALUES (v_id, CURRENT_DATE, COALESCE(p_zone, 'UNKNOWN'), COALESCE(p_type, 'INCIDENT'),
          COALESCE(p_severity, 'MEDIUM'), p_desc, v_eff, 'OPEN');
  RETURN jsonb_build_object('ok', true, 'msg', 'Laporan insiden terkirim.', 'id', v_id);
END;
$function$;

-- 11. create_forum_post(...) — WRITE (nrp dipaksa claims utk non-admin)
CREATE OR REPLACE FUNCTION public.create_forum_post(p_nrp text, p_title text, p_content text, p_category text DEFAULT 'Umum'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  new_id uuid;
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_eff text := CASE WHEN v_is_admin THEN p_nrp ELSE v_nrp END;
BEGIN
  INSERT INTO forum_posts (nrp, title, content, category) VALUES (v_eff, p_title, p_content, p_category) RETURNING id INTO new_id;
  RETURN jsonb_build_object('ok', true, 'id', new_id);
END;
$function$;

-- 12. reply_forum_post(...) — WRITE (nrp dipaksa claims utk non-admin)
CREATE OR REPLACE FUNCTION public.reply_forum_post(p_post_id uuid, p_nrp text, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_nrp text := authz_current_nrp();
  v_is_admin boolean := authz_check_admin('employee.view_all');
  v_eff text := CASE WHEN v_is_admin THEN p_nrp ELSE v_nrp END;
BEGIN
  INSERT INTO forum_replies (post_id, nrp, content) VALUES (p_post_id, v_eff, p_content);
  UPDATE forum_posts SET replies_count = replies_count + 1 WHERE id = p_post_id;
  RETURN jsonb_build_object('ok', true);
END;
$function$;
