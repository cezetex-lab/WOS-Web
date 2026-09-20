```
=== replay instalasi dari awal: mode=chain db=wos_replay_chain ===
database scratch dibuat: wos_replay_chain (database kosong, tanpa objek apa pun)
prereq platform: schema extensions+auth, auth.uid()/role()/email()/jwt(), auth.users, stub cron, default privilege Supabase — OK
extension pgcrypto: OK
extension uuid-ossp: OK
extension vector: OK

=== HASIL: 164/164 berkas sukses, 0 GAGAL ===

--- DAFTAR SUKSES ---
ok     MIGRATION 000_pgcrypto.sql (595ms)
ok     MIGRATION 001_init.sql (815ms)
ok     MIGRATION 003_fix_columns.sql (677ms)
ok     MIGRATION 005_fix_hash_bug.sql (366ms)
ok     MIGRATION 006_cron_setup.sql (489ms)
ok     MIGRATION 007_pgvector_ai_copilot.sql (495ms)
ok     MIGRATION 008_restore_missing_objects.sql (629ms)
ok     MIGRATION 011_ULTIMATE.sql (2150ms)
ok     MIGRATION 018_new_25_tables.sql (819ms)
ok     MIGRATION 027_seed_remaining_tables.sql (613ms)
ok     MIGRATION 028_admin_worker_rpcs.sql (510ms)
ok     MIGRATION 033_seed_ai_knowledge_base.sql (511ms)
ok     MIGRATION 034_wave_a_foundation.sql (1233ms)
ok     MIGRATION 035_wave_b_connection_cache.sql (712ms)
ok     MIGRATION 038_fix_all_rpc_errors.sql (919ms)
ok     MIGRATION 039_fix_worker_kpi_rpcs.sql (465ms)
ok     MIGRATION 040_wave4_self_service.sql (455ms)
ok     MIGRATION 042_wave5_missing_rpcs.sql (568ms)
ok     MIGRATION 043_fix_admin_worker_rpc_missing.sql (486ms)
ok     MIGRATION 044_push_subscriptions.sql (684ms)
ok     MIGRATION 045_wave8_integrations.sql (614ms)
ok     MIGRATION 047_optimized_seed.sql (1467ms)
ok     MIGRATION 048_enable_rls_remaining.sql (578ms)
ok     MIGRATION 050_wave_final_features.sql (612ms)
ok     MIGRATION 051_admin_2level_roles.sql (613ms)
ok     MIGRATION 052_mill_modules.sql (613ms)
ok     MIGRATION 053_seed_remaining_tables.sql (818ms)
ok     MIGRATION 054_audit_columns.sql (613ms)
ok     MIGRATION 055_mining_estate_rpcs.sql (467ms)
ok     MIGRATION 057_mfa_totp.sql (556ms)
ok     MIGRATION 058_duplicate_cleanup.sql (612ms)
ok     MIGRATION 059_review360_rpc_fix.sql (613ms)
ok     MIGRATION 060_worker_views_rpcs.sql (613ms)
ok     MIGRATION 061_data_governance.sql (613ms)
ok     MIGRATION 062_global_core.sql (614ms)
ok     MIGRATION 063_performance_indexes.sql (614ms)
ok     MIGRATION 065_estate_mining_rpcs.sql (526ms)
ok     MIGRATION 071_foundation.sql (595ms)
ok     MIGRATION 072_rpc_gatekeepers.sql (613ms)
ok     MIGRATION 073_industry_rpc_templates.sql (433ms)
ok     MIGRATION 075_fix_industry_columns.sql (487ms)
ok     MIGRATION 076_test_accounts.sql (611ms)
ok     MIGRATION 077_fix_seed_data.sql (613ms)
ok     MIGRATION 078_fix_role_check.sql (614ms)
ok     MIGRATION 079_auth_lookup.sql (613ms)
ok     MIGRATION 080_owner_rpcs.sql (613ms)
ok     MIGRATION 081_fix_toggle_lock.sql (570ms)
ok     MIGRATION 082_fix_role_overview.sql (554ms)
ok     MIGRATION 083_rls_hardening.sql (818ms)
ok     MIGRATION 084_account_lockout.sql (614ms)
ok     MIGRATION 086_branding.sql (614ms)
ok     MIGRATION 087_fix_auth_lookup.sql (614ms)
ok     MIGRATION 088_fix_branding_rls_and_auth.sql (613ms)
ok     MIGRATION 089_branding_full.sql (613ms)
ok     MIGRATION 090_sync_auth_users.sql (513ms)
ok     MIGRATION 091_owner_not_employee.sql (612ms)
ok     MIGRATION 092_owner_login.sql (610ms)
ok     MIGRATION 093_fix_owner_context.sql (613ms)
ok     MIGRATION 095_company_config.sql (511ms)
ok     MIGRATION 100_owner_wave1.sql (613ms)
ok     MIGRATION 101_owner_wave2.sql (615ms)
ok     MIGRATION 102_owner_wave3.sql (613ms)
ok     MIGRATION 110_owner_admin_architecture.sql (611ms)
ok     MIGRATION 111_owner_security_hardening.sql (613ms)
ok     MIGRATION 120_seed_admin_accounts.sql (612ms)
ok     MIGRATION 130_fix_missing_rpcs.sql (531ms)
ok     MIGRATION 131_security_idor_fix.sql (510ms)
ok     MIGRATION 132_admin_bu_filter_and_owner_login.sql (595ms)
ok     MIGRATION 133_rls_tightening.sql (509ms)
ok     MIGRATION 134_authz_architecture_v2.sql (607ms)
ok     MIGRATION 135_authz_seed_permissions.sql (440ms)
ok     MIGRATION 136_authz_migrate_violations.sql (589ms)
ok     MIGRATION 137_rls_remaining_tables.sql (503ms)
ok     MIGRATION 138_admin_rls_hardening.sql (519ms)
ok     MIGRATION 139_admin_rbac_concurrent_session.sql (613ms)
ok     MIGRATION 140_fix_industry_schema.sql (618ms)
ok     MIGRATION 141_153_CONSOLIDATED_.sql (1838ms)
ok     MIGRATION 154_pilar2_self_service.sql (613ms)
ok     MIGRATION 155_pilar3_platform.sql (614ms)
ok     MIGRATION 156_pilar4_ai.sql (613ms)
ok     MIGRATION 157_pilar5_flexibility.sql (531ms)
ok     MIGRATION 158_fase1_employees_master_columns.sql (492ms)
ok     MIGRATION 159_fase2_master_data.sql (510ms)
ok     MIGRATION 160_fase3_hr_engine.sql (613ms)
ok     MIGRATION 161_fase4_narrative.sql (614ms)
ok     MIGRATION 162_fase5_preview.sql (615ms)
ok     MIGRATION 163_fase6_simulation.sql (612ms)
ok     MIGRATION 164_fase7_auth_flow.sql (611ms)
ok     MIGRATION 165_fase8_bulk_edp_command.sql (510ms)
ok     MIGRATION 166_fase9_infrastructure.sql (613ms)
ok     MIGRATION 167_pilar6_monetization.sql (531ms)
ok     MIGRATION 168_fix_p0_p1.sql (593ms)
ok     MIGRATION 169_fix_auth_session_p0.sql (612ms)
ok     MIGRATION 171_restore_db_only_functions.sql (613ms)
ok     MIGRATION 172_hardening_grants.sql (1025ms)
ok     MIGRATION 173_force_rls_gradual.sql (614ms)
ok     MIGRATION 174_fix_search_path_204.sql (424ms)
ok     MIGRATION 175_smoke_tests.sql (595ms)
ok     MIGRATION 176_fix_rownum_and_pgcrypto_path.sql (613ms)
ok     MIGRATION 176_fix_search_path_extensions.sql (617ms)
ok     MIGRATION 177_fix_preexisting_bugs.sql (611ms)
ok     MIGRATION 178_fix_smoke_test_data.sql (611ms)
ok     MIGRATION 179_fix_payroll_groupby_and_smoke.sql (614ms)
ok     MIGRATION 180_estate_mill_functions.sql (532ms)
ok     MIGRATION 181_fix_estate_mill_columns.sql (492ms)
ok     MIGRATION 182_fix_mv_rls.sql (536ms)
ok     MIGRATION 183_split_employees_master.sql (613ms)
ok     MIGRATION 184_test_q1_q4_security.sql (516ms)
ok     MIGRATION 185_dynamic_routes.sql (584ms)
ok     MIGRATION 186_add_missing_routes.sql (613ms)
ok     MIGRATION 186_enable_pg_cron_schedules.sql (614ms)
ok     MIGRATION 187_fix_dynamic_routes_rpc.sql (613ms)
ok     MIGRATION 188_backfill_dynamic_routes.sql (510ms)
ok     MIGRATION 189_fix_admin_business_unit_id.sql (510ms)
ok     MIGRATION 190_fix_admin_get_payroll.sql (613ms)
ok     MIGRATION 191_fix_approve_rpcs_and_auth_hardening.sql (615ms)
ok     MIGRATION 192_fix_auth_schema_drift.sql (613ms)
ok     MIGRATION 193_atomic_rate_limit.sql (612ms)
ok     MIGRATION 194_fix_trust_the_client_rpcs.sql (613ms)
ok     MIGRATION 195_fix_worker_passwords_reset_required.sql (612ms)
ok     MIGRATION 196_fix_industrial_rpc_anon_grant.sql (614ms)
ok     MIGRATION 197_fix_route_components.sql (511ms)
ok     MIGRATION 198_branding_insightwip.sql (512ms)
ok     MIGRATION 199_auth_testing_override.sql (369ms)
ok     MIGRATION 200_owner_testing_override_functions.sql (550ms)
ok     MIGRATION 201_override_bypass_verify.sql (615ms)
ok     MIGRATION 202_fix_get_enabled_modules_search_path_and_area.sql (611ms)
ok     MIGRATION 203_fix_admin_get_vacancies.sql (612ms)
ok     MIGRATION 204_admin_mill_routes.sql (455ms)
ok     MIGRATION 205_get_enabled_modules_legacy_rename.sql (465ms)
ok     MIGRATION 206_nik_null_guard.sql (511ms)
ok     MIGRATION 207_fix_search_path_strays.sql (375ms)
ok     MIGRATION 208_fix_groupby.sql (491ms)
ok     MIGRATION 208_industry_tables_and_rpcs.sql (459ms)
ok     MIGRATION 209_dead_forms_handlers.sql (613ms)
ok     MIGRATION 210_revoke_anon_remaining.sql (510ms)
ok     MIGRATION 211_employees_master_write_trigger.sql (615ms)
ok     MIGRATION 212_pg_cron_setup.sql (615ms)
ok     MIGRATION 213_registration_and_favicon.sql (507ms)
ok     MIGRATION 214_f9_missing_rpcs.sql (614ms)
ok     MIGRATION 215_ai_rag_access_and_rate_limits.sql (613ms)
ok     MIGRATION 215_gap_employee_fields.sql (614ms)
ok     MIGRATION 216_login_worker_by_email.sql (512ms)
ok     MIGRATION 217_drop_deprecated_login_admin.sql (529ms)
ok     MIGRATION 218_drop_legacy_tables.sql (572ms)
ok     MIGRATION 219_schema_versioning.sql (529ms)
ok     MIGRATION 220_audit_hash_chain.sql (614ms)
ok     MIGRATION 221_revoke_anon_admin_grants.sql (613ms)
ok     MIGRATION 222_worker_profile_rpc.sql (613ms)
ok     MIGRATION 223_fix_branding_anon_grant.sql (612ms)
ok     MIGRATION 224_fix_check_migrations_duplicate_rule.sql (402ms)
ok     MIGRATION 225_dynamic_attendance_partitions.sql (518ms)
ok     MIGRATION 226_revoke_anon_public_write_rpcs.sql (611ms)
ok     MIGRATION 227_attendance_partition_rls_force.sql (611ms)
ok     MIGRATION 228_retire_dead_mv_cache_layer.sql (612ms)
ok     MIGRATION 229_fresh_install_fk_repair.sql (613ms)
ok     MIGRATION 230_owner_email_fail_closed.sql (613ms)
ok     MIGRATION 231_apply_missing_effects.sql (612ms)
ok     MIGRATION 232_revoke_anon_inherited_grants.sql (616ms)
ok     MIGRATION 233_reapply_226c_intended_revokes.sql (615ms)
ok     MIGRATION 236_sql04_fix_hr_okrs.sql (501ms)
ok     MIGRATION 237_sql05_fix_rls_policies.sql (620ms)
ok     MIGRATION 238_sql07_fix_default_privileges.sql (613ms)
ok     MIGRATION 239_sql09_fix_duplicate_create.sql (512ms)

--- METRIK: live vs hasil replay ---
  BEDA  tabel_non_partisi  live=  209  replay=  212
  SAMA  partisi            live=  285  replay=  285
  SAMA  view               live=    1  replay=    1
  BEDA  fungsi_project     live=  553  replay=  547
  BEDA  policy             live=  224  replay=  311
  BEDA  trigger            live=   27  replay=   38
  BEDA  rls_enabled        live=  266  replay=  268
  BEDA  rls_forced         live=  256  replay=  260
  BEDA  sequence           live=   96  replay=   98
  BEDA  index              live=  618  replay=  608
  BEDA  cron_job           live=    4  replay=   14
  BEDA  migration_cap      live=  164  replay=    1

--- BANDING ACL (live vs replay) ---
  entri ACL live=2612 replay=2605
  HILANG di replay : 62
     - rel:hr_okrs_id_seq:anon [SELECT,UPDATE,USAGE]
     - rel:hr_okrs_id_seq:authenticated [SELECT,UPDATE,USAGE]
     - rel:hr_okrs_id_seq:postgres [SELECT,UPDATE,USAGE]
     - rel:hr_okrs_id_seq:service_role [SELECT,UPDATE,USAGE]
     - rel:hr_surveys_id_seq:anon [SELECT,UPDATE,USAGE]
     - rel:hr_surveys_id_seq:authenticated [SELECT,UPDATE,USAGE]
     - rel:hr_surveys_id_seq:postgres [SELECT,UPDATE,USAGE]
     - rel:hr_surveys_id_seq:service_role [SELECT,UPDATE,USAGE]
     - rel:safety_incidents:anon [DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     - fn:_legacy_create_worker_request_dated(p_nrp text, p_type text, p_reason text, p_from date, p_to date):authenticated [EXECUTE]
     - fn:_legacy_create_worker_request_dated(p_nrp text, p_type text, p_reason text, p_from date, p_to date):postgres [EXECUTE]
     - fn:_legacy_create_worker_request_dated(p_nrp text, p_type text, p_reason text, p_from date, p_to date):service_role [EXECUTE]
     - fn:_legacy_generate_worker_otp_nopass(p_nrp text, p_nik text):postgres [EXECUTE]
     - fn:_legacy_generate_worker_otp_nopass(p_nrp text, p_nik text):service_role [EXECUTE]
     - fn:_legacy_get_breakdown_log_by_site(p_site_code text):authenticated [EXECUTE]
     - fn:_legacy_get_breakdown_log_by_site(p_site_code text):postgres [EXECUTE]
     - fn:_legacy_get_breakdown_log_by_site(p_site_code text):service_role [EXECUTE]
     - fn:_legacy_get_estate_blocks_by_bu(p_bu_id text):authenticated [EXECUTE]
     - fn:_legacy_get_estate_blocks_by_bu(p_bu_id text):postgres [EXECUTE]
     - fn:_legacy_get_estate_blocks_by_bu(p_bu_id text):service_role [EXECUTE]
     - fn:_legacy_get_estate_blocks_paged(p_page integer, p_limit integer):authenticated [EXECUTE]
     - fn:_legacy_get_harvest_records_by_bu(p_bu_id text):authenticated [EXECUTE]
     - fn:_legacy_get_harvest_records_by_bu(p_bu_id text):postgres [EXECUTE]
     - fn:_legacy_get_harvest_records_by_bu(p_bu_id text):service_role [EXECUTE]
     - fn:_legacy_get_nursery_data_by_bu(p_bu_id text):authenticated [EXECUTE]
  BERLEBIH di replay: 55
     + rel:currency_master:authenticated [DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:currency_master:postgres [DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:currency_master:service_role [DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:estate_harvest_id_seq:anon [SELECT,UPDATE,USAGE]
     + rel:estate_harvest_id_seq:authenticated [SELECT,UPDATE,USAGE]
     + rel:estate_harvest_id_seq:postgres [SELECT,UPDATE,USAGE]
     + rel:estate_harvest_id_seq:service_role [SELECT,UPDATE,USAGE]
     + rel:mining_equipment_id_seq:anon [SELECT,UPDATE,USAGE]
     + rel:mining_equipment_id_seq:authenticated [SELECT,UPDATE,USAGE]
     + rel:mining_equipment_id_seq:postgres [SELECT,UPDATE,USAGE]
     + rel:mining_equipment_id_seq:service_role [SELECT,UPDATE,USAGE]
     + rel:mining_simper_id_seq:anon [SELECT,UPDATE,USAGE]
     + rel:mining_simper_id_seq:authenticated [SELECT,UPDATE,USAGE]
     + rel:mining_simper_id_seq:postgres [SELECT,UPDATE,USAGE]
     + rel:mining_simper_id_seq:service_role [SELECT,UPDATE,USAGE]
     + rel:onboarding_tasks_id_seq:anon [SELECT,UPDATE,USAGE]
     + rel:onboarding_tasks_id_seq:authenticated [SELECT,UPDATE,USAGE]
     + rel:onboarding_tasks_id_seq:postgres [SELECT,UPDATE,USAGE]
     + rel:onboarding_tasks_id_seq:service_role [SELECT,UPDATE,USAGE]
     + rel:onboarding_tasks_old:authenticated [DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:onboarding_tasks_old:postgres [DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:onboarding_tasks_old:service_role [DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:timezone_master:authenticated [DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:timezone_master:postgres [DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     + rel:timezone_master:service_role [DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
  BEDA hak          : 517
     ~ rel:active_sessions:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:active_sessions:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:admin_division_access:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:admin_division_access:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:admin_roles:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:admin_roles:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:ai_conversations:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:ai_conversations:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:ai_documents:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:ai_documents:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:announcements:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:announcements:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:approval_config:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:approval_config:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:approval_instances:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:approval_instances:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:asset_assignments:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:asset_assignments:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:assets:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:assets:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:audit_chain:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:audit_chain:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:audit_log:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:audit_log:service_role live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]
     ~ rel:audit_log_owner:authenticated live=[DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE] replay=[DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE]

  uji revoke anon/PUBLIC (harus MATCH dengan live):
     worker_update_profile    live=[authenticated,postgres,service_role] replay=[authenticated,postgres,service_role] MATCH
     admin_get_payroll        live=[authenticated,postgres,service_role] replay=[authenticated,postgres,service_role] MATCH
     get_worker_profile       live=[authenticated,postgres,service_role] replay=[authenticated,postgres,service_role] MATCH
     login_worker_by_email    live=[anon,authenticated,postgres,service_role] replay=[anon,authenticated,postgres,service_role] MATCH
```
