-- 081: Fix owner_toggle_lock to accept p_bu_id (toggle ANY BU, not just owner's)
-- Also fix: use is_enabled = p_enable directly (not !currentEnabled which can be wrong)

CREATE OR REPLACE FUNCTION owner_toggle_lock(p_module_code TEXT, p_enable BOOLEAN, p_bu_id TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB := get_current_user_context();
  v_old BOOLEAN;
  v_target_bu TEXT;
BEGIN
  -- Owner check
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Hanya Owner.');
  END IF;

  -- Module check
  IF NOT EXISTS (SELECT 1 FROM module_definitions WHERE module_code = p_module_code AND is_industry_module = TRUE) THEN
    RETURN jsonb_build_object('ok', FALSE, 'msg', 'Bukan Industry module.');
  END IF;

  -- Determine target BU: use p_bu_id if provided, else owner's BU
  v_target_bu := COALESCE(p_bu_id, (v_ctx->>'business_unit_id')::TEXT);

  -- Get old value
  SELECT is_enabled INTO v_old
  FROM business_unit_modules
  WHERE business_unit_id = v_target_bu AND module_code = p_module_code;

  -- Update
  UPDATE business_unit_modules
  SET is_enabled = p_enable,
      toggled_by = (v_ctx->>'nrp'),
      toggled_at = NOW()
  WHERE business_unit_id = v_target_bu AND module_code = p_module_code;

  -- Audit log
  INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, old_value, new_value)
  VALUES (
    (v_ctx->>'nrp'),
    'TOGGLE_LOCK',
    'module',
    p_module_code || '@' || v_target_bu,
    jsonb_build_object('enabled', COALESCE(v_old, FALSE), 'bu', v_target_bu),
    jsonb_build_object('enabled', p_enable, 'bu', v_target_bu)
  );

  RETURN jsonb_build_object(
    'ok', TRUE,
    'msg', CASE WHEN p_enable THEN 'Lock ON' ELSE 'Lock OFF' END,
    'bu', v_target_bu
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION owner_toggle_lock(TEXT, BOOLEAN, TEXT) TO authenticated;
