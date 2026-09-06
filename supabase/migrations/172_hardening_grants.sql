-- ================================================================
-- 172_hardening_grants.sql — HARDENING GRANT EXECUTE (audit ulang pasca-169)
-- End-state deterministik: revoke semua, lalu grant minimal per pemakai.
--   anon          = entry point pra-login saja (Home.jsx pre-auth)
--   authenticated = seluruh RPC yang dipanggil aplikasi src/ (termasuk owner_*,
--                    semua owner_* di-guard is_owner -> non-owner ditolak)
--   service_role  = SEMUA fungsi (edge functions & cron tak bisa patah)
--   TIDAK di-grant ke anon/auth: decrypt_pii & export_* (grant NOL, SD-internal)
-- Verifikasi: kueri di bagian akhir (count per role + fungsi tanpa grant).
-- ================================================================

-- 1) Bersihkan SEMUA grant default/eksplisit (termasuk sisa over-grant 168 ke auth)
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;

-- 2) service_role: akses penuh (backend internal / cron / edge)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- 3) anon: entry pra-login (worker login/OTP/reset + branding + lockout)
GRANT EXECUTE ON FUNCTION public.change_password(p_nrp text, p_old_password text, p_new_password text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_login_lockout(p_identifier text, p_attempt_type text) TO anon;
GRANT EXECUTE ON FUNCTION public.generate_admin_otp() TO anon;
GRANT EXECUTE ON FUNCTION public.generate_worker_otp(p_nrp text, p_nik text) TO anon;
GRANT EXECUTE ON FUNCTION public.generate_worker_otp(p_nrp text, p_nik text, p_password text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_branding() TO anon;
GRANT EXECUTE ON FUNCTION public.login_worker(p_nrp text, p_nik text, p_password text) TO anon;
GRANT EXECUTE ON FUNCTION public.login_worker(p_nrp text, p_password text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp(p_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_worker_otp(p_nrp text, p_code text) TO anon;

-- 4) authenticated: RPC yang dipakai aplikasi login
GRANT EXECUTE ON FUNCTION public.add_okr_result(p_okr_id integer, p_kr text, p_target numeric, p_unit text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_performance_note(p_nrp text, p_author text, p_type text, p_content text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_request(p_id text, p_note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_change_password(p_old_password text, p_new_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_webhook(p_name text, p_url text, p_events text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_worker(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_webhook(p_id bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_export_sheet(p_sheet text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_asset_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_assets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_audit_chain() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_audit_log() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_badges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_budget() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_divisions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_employee_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_employees() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_exit_interviews() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_external_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_facility_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_feature_flags() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_kpi_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_kpi_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_leave() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_low_performers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_master_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_okr() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_org_structure() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_overtime() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_payroll(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_payroll_summary(p_period text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_pending_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_referrals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_role_matrix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_settlements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_sso_providers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_timesheet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_top_performers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_vacancies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_webhook_logs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_webhooks() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_request(p_id text, p_note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_worker_password(p_nrp text, p_new_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_feature_flag(p_name text, p_enabled boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_webhook(p_id bigint, p_active boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_idea_status(p_idea_id text, p_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_team_request(p_id text, p_status text, p_note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cache_get(p_key text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cache_set(p_key text, p_value text, p_ttl integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_incentive(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_password(p_nrp text, p_old_password text, p_new_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_login_lockout(p_identifier text, p_attempt_type text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_module_access(p_module_code text, p_required_role_level integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_owner_identity() TO authenticated;
GRANT EXECUTE ON FUNCTION public.checkin_asset(p_asset_id text, p_condition text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_asset(p_asset_id text, p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_forum_post(p_nrp text, p_title text, p_content text, p_category text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_okr(p_nrp text, p_periode text, p_objective text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_task(p_assignee text, p_title text, p_due date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_task(p_nrp text, p_assigner text, p_title text, p_desc text, p_priority text, p_due date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_worker_request(p_nrp text, p_type text, p_detail text, p_note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_worker_request(p_nrp text, p_type text, p_reason text, p_from date, p_to date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_admin_otp() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_worker_otp(p_nrp text, p_nik text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_worker_otp(p_nrp text, p_nik text, p_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_announcements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_anomaly_sentinel() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_audit_log_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_audit_log_owner(p_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_audit_log_v2(p_action_type text, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer, p_offset integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auto_healing_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_boiler_status(p_site_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_branding() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_breakdown_log(p_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_business_units_for_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_candidate_pipeline(p_vacancy_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_career_path(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_company_config() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_continuous_perf_team(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_user_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_early_warning() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_enabled_modules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_estate_blocks() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_estate_blocks(p_page integer, p_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_executive_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_fatigue_data(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_flight_risk_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_forum_posts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_harvest_records() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_heavy_equipment(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_incentives(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_industry_admin_stats(p_industry text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_jsa_list(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_kpi_by_division() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_login_attempt_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_maintenance_schedule(p_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_medical_checkup(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_modules_for_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_okrs(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_notification_config() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_offboarding_checklist(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_onboarding_tasks(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_owner_employees_by_bu() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_owner_overview_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_packing_log(p_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_performance_notes(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pkwt_expiry_alert() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_press_status(p_site_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_production_daily(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_qc_results(p_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reviews_360(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_role_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_safety_incidents(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_screening_results() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shift_assignments(p_date date, p_shift text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shift_schedule() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_simper_list(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_simulations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_skills_intelligence(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_succession(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_survey_results(p_survey_id integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_talent_marketplace() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_task_board(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_data(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_narrative(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_requests(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_transport_dispatch() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_turnover_prediction() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_context_by_auth_id(p_auth_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_whistleblowers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_activities(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_attendance(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_badges(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_benefits(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_certifications(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_kpi(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_learning(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_leave(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_narrative(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_overtime(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_payroll(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_profile(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_referrals(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_requests(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_worker_status(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_workforce_planning() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_ideas() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_ideas(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.login_admin(p_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.login_worker(p_nrp text, p_nik text, p_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.login_worker(p_nrp text, p_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.move_candidate(p_id text, p_stage text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_assign_admin_user(p_nrp text, p_role_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_create_admin_role(p_role_code text, p_role_name text, p_scope_type text, p_scope_id text, p_permissions jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_create_announcement(p_title text, p_message text, p_priority text, p_target_audience text, p_expiry_date date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_create_bu(p_unit_code text, p_unit_name text, p_description text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_create_employee(p_nrp text, p_nama text, p_email text, p_divisi text, p_posisi text, p_bu_id text, p_status_kerja text, p_role text, p_role_level integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_create_integration(p_name text, p_type text, p_config jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_create_system_announcement(p_title text, p_message text, p_type text, p_dismissible boolean, p_end_at timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_deactivate_employee(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_announcement(p_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_bu(p_bu_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_integration(p_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_system_announcement(p_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_force_logout(p_nrp text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_activity_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_admin_accounts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_admin_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_announcements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_changelog() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_employees(p_bu_id text, p_search text, p_limit integer, p_offset integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_integrations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_retention_rules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_security_settings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_system_announcements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_tickets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_get_usage_analytics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_login(p_email text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_set_tier(p_bu_id text, p_tier integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_toggle_lock(p_module_code text, p_enable boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_toggle_lock(p_module_code text, p_enable boolean, p_bu_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_update_admin_role(p_role_id integer, p_role_name text, p_permissions jsonb, p_is_active boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_update_bu(p_bu_id text, p_unit_name text, p_description text, p_is_active boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_update_retention_rule(p_id text, p_retention_days integer, p_archive_enabled boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_update_role(p_nrp text, p_role text, p_role_level integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_update_ticket_status(p_ticket_id text, p_status text, p_assigned_to text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_request(p_request_id text, p_action text, p_approver text, p_note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_session(p_session_id text, p_ip text, p_ua text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reply_forum_post(p_post_id uuid, p_nrp text, p_content text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reset_password(p_nrp text, p_token text, p_new_password text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_simulation(p_turnover_change numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_idea(p_nrp text, p_title text, p_description text, p_category text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_request(p_nrp text, p_type text, p_details text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_survey(p_survey_id integer, p_nrp text, p_answers jsonb, p_score integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_whistleblower(p_category text, p_desc text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_branding(p_company_name text, p_tagline text, p_logo_url text, p_primary_color text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_company_config(p_config_id text, p_value jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_notification_config(p_id text, p_email_enabled boolean, p_push_enabled boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_task_status(p_id integer, p_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_task_status(p_task_id text, p_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_otp(p_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_worker_otp(p_nrp text, p_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_idea(p_idea_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.worker_change_password(p_nrp text, p_old text, p_new text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.worker_logout() TO authenticated;
GRANT EXECUTE ON FUNCTION public.worker_update_profile(p_nrp text, p_email text, p_no_hp text, p_alamat text) TO authenticated;

-- 5) Cek hasil (read-only, fungsi non-ekstensi saja — ACL fungsi pgvector)
--    dikelola supabase_admin dan tidak bisa di-revoke dari role pooler (no-op senyap))
SELECT 'total_fungsi_non_ext' AS ukuran, count(*)::text AS jumlah FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_extension'::regclass AND d.deptype='e')
UNION ALL SELECT 'callable_anon', count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND has_function_privilege('anon',p.oid,'EXECUTE') AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_extension'::regclass AND d.deptype='e')
UNION ALL SELECT 'callable_authenticated', count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_extension'::regclass AND d.deptype='e')
UNION ALL SELECT 'callable_service_role', count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND has_function_privilege('service_role',p.oid,'EXECUTE') AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_extension'::regclass AND d.deptype='e')
UNION ALL SELECT 'decrypt/export/owner_* non-ext tertutup anon+auth', count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND (p.proname='decrypt_pii' OR p.proname LIKE 'export\_%' OR p.proname LIKE 'owner\_%') AND NOT has_function_privilege('anon',p.oid,'EXECUTE') AND NOT has_function_privilege('authenticated',p.oid,'EXECUTE');
