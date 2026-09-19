-- SQL-05 fix
DROP POLICY IF EXISTS admin_read_candidate_pipeline ON public.candidate_pipeline;
CREATE POLICY admin_read_candidate_pipeline ON public.candidate_pipeline FOR SELECT TO PUBLIC USING (true);
DROP POLICY IF EXISTS dc_admin ON public.dashboard_cache;
CREATE POLICY dc_admin ON public.dashboard_cache FOR ALL TO PUBLIC USING (false);
DROP POLICY IF EXISTS admin_read_vacancies ON public.vacancies;
CREATE POLICY admin_read_vacancies ON public.vacancies FOR SELECT TO PUBLIC USING (true);
