-- 217: Drop deprecated login_admin function (replaced by Supabase Auth)
-- Admin login now uses supabase.auth.signInWithPassword + get_user_context_by_auth_id.
-- login_admin has been a no-op stub returning {ok:false, deprecated:true} since migration 141.

REVOKE ALL ON FUNCTION public.login_admin(text) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.login_admin(text);

NOTIFY pgrst, 'reload schema';
