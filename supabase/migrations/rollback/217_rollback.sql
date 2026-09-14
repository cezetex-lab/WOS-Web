-- rollback/217_rollback.sql — Restore deprecated login_admin stub
CREATE OR REPLACE FUNCTION public.login_admin(p_password TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('ok', false, 'msg', 'Admin login sekarang menggunakan Supabase Auth.', 'deprecated', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION public.login_admin(text) TO authenticated;
NOTIFY pgrst, 'reload schema';
