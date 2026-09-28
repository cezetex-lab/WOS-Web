-- ============================================================
-- 251 ROLLBACK — definisi SEBELUM Fix #4 (P1-13-01/P2-13-01)
-- Dibuat 2026-09-27. TIDAK di-commit (gitignored).
-- Pakai hanya kalau 251/252 harus dibatalkan:
--   psql "$DATABASE_URL" -f migrations/rollback/251_rollback.sql
-- CATATAN: rollback TIDAK memulihkan 519 baris actor NULL (kita tidak backfill,
-- jadi tidak ada yang perlu dibalik di data). Cleanup dead code tetap di Fix #9.
-- ============================================================

CREATE OR REPLACE FUNCTION public._generic_audit_trigger_fixed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_action TEXT;
  v_nrp TEXT;
  v_old JSONB;
  v_new JSONB;
BEGIN
  v_action := TG_OP || ' ' || TG_TABLE_NAME;
  v_nrp := COALESCE(NEW.nrp, OLD.nrp, 'SYSTEM');

  IF TG_OP = 'INSERT' THEN
    v_new := to_jsonb(NEW);
    INSERT INTO audit_log (action, detail, timestamp)
    VALUES (v_action, jsonb_build_object('nrp', v_nrp, 'table', TG_TABLE_NAME, 'data', v_new)::text, NOW());
  ELSIF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    IF v_old IS DISTINCT FROM v_new THEN
      INSERT INTO audit_log (action, detail, timestamp)
      VALUES (v_action, jsonb_build_object('nrp', v_nrp, 'table', TG_TABLE_NAME, 'old', v_old, 'new', v_new)::text, NOW());
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    INSERT INTO audit_log (action, detail, timestamp)
    VALUES (v_action, jsonb_build_object('nrp', v_nrp, 'table', TG_TABLE_NAME, 'data', v_old)::text, NOW());
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.audit_log_hash_chain()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_prev_hash TEXT;
BEGIN
  SELECT row_hash INTO v_prev_hash
  FROM audit_log ORDER BY id DESC LIMIT 1;

  IF v_prev_hash IS NULL THEN
    v_prev_hash := '0';
  END IF;

  NEW.prev_hash := v_prev_hash;
  NEW.row_hash := encode(
    sha256(
      (COALESCE(NEW.id::TEXT, '') ||
       COALESCE(NEW.timestamp::TEXT, '') ||
       COALESCE(NEW.actor, '') ||
       COALESCE(NEW.action, '') ||
       COALESCE(NEW.detail, '') ||
       v_prev_hash)::BYTEA
    ),
    'hex'
  );
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.verify_audit_chain(p_start_id integer DEFAULT NULL::integer, p_end_id integer DEFAULT NULL::integer)
 RETURNS TABLE(issue_type text, row_id integer, detail text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_prev_row_hash TEXT := '0';
  v_expected_hash TEXT;
  v_id INTEGER;
  v_ts TIMESTAMPTZ;
  v_actor TEXT;
  v_action TEXT;
  v_detail TEXT;
  v_prev TEXT;
  v_hash TEXT;
BEGIN
  FOR v_id, v_ts, v_actor, v_action, v_detail, v_prev, v_hash IN
    SELECT al.id, al.timestamp, al.actor, al.action, al.detail, al.prev_hash, al.row_hash
    FROM audit_log al
    WHERE (p_start_id IS NULL OR al.id >= p_start_id)
      AND (p_end_id IS NULL OR al.id <= p_end_id)
    ORDER BY al.id
  LOOP
    IF v_prev != v_prev_row_hash THEN
      issue_type := 'BROKEN_LINK';
      row_id := v_id;
      detail := 'prev_hash mismatch at id ' || v_id;
      RETURN NEXT;
    END IF;
    v_expected_hash := encode(
      sha256(
        (COALESCE(v_id::TEXT, '') ||
         COALESCE(v_ts::TEXT, '') ||
         COALESCE(v_actor, '') ||
         COALESCE(v_action, '') ||
         COALESCE(v_detail, '') ||
         v_prev)::BYTEA
      ),
      'hex'
    );
    IF v_hash != v_expected_hash THEN
      issue_type := 'TAMPERED';
      row_id := v_id;
      detail := 'row_hash mismatch at id ' || v_id;
      RETURN NEXT;
    END IF;
    v_prev_row_hash := v_hash;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cleanup_audit_log(p_days integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_deleted INT;
BEGIN
  DELETE FROM audit_log WHERE created_at < NOW() - (p_days || ' days')::INTERVAL;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_deleted, 'retention_days', p_days);
END;
$function$
;

-- ---- trigger yang di-drop oleh 251 (buat pulihkan) ----
CREATE TRIGGER trg_audit_payroll_insert AFTER INSERT ON public.hr_payroll FOR EACH ROW EXECUTE FUNCTION _audit_payroll_change();
CREATE TRIGGER trg_audit_payroll_update AFTER UPDATE ON public.hr_payroll FOR EACH ROW EXECUTE FUNCTION _audit_payroll_change();
CREATE TRIGGER trg_audit_role_change AFTER UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION _audit_role_change();
