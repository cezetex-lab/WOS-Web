```
=== replay instalasi dari awal: mode=baseline db=wos_replay_baseline ===
database scratch dibuat: wos_replay_baseline (database kosong, tanpa objek apa pun)
prereq platform: schema extensions+auth, auth.uid()/role()/email()/jwt(), auth.users, stub cron, default privilege Supabase — OK
extension pgcrypto: OK
extension uuid-ossp: OK
extension vector: OK

=== HASIL: 2/2 berkas sukses, 0 GAGAL ===

--- DAFTAR SUKSES ---
ok     BASELINE 000_baseline_schema.sql (3677ms)
ok     BASELINE 010_baseline_config_data.sql (815ms)

--- METRIK: live vs hasil replay ---
  SAMA  tabel_non_partisi  live=  208  replay=  208
  SAMA  partisi            live=  285  replay=  285
  SAMA  view               live=    1  replay=    1
  SAMA  fungsi_project     live=  549  replay=  549
  SAMA  policy             live=  223  replay=  223
  SAMA  trigger            live=   27  replay=   27
  SAMA  rls_enabled        live=  265  replay=  265
  SAMA  rls_forced         live=  256  replay=  256
  SAMA  sequence           live=   95  replay=   95
  SAMA  index              live=  615  replay=  615
  SAMA  cron_job           live=    4  replay=    4
  SAMA  migration_cap      live=  157  replay=  157

--- BANDING ACL (live vs replay) ---
  entri ACL live=2591 replay=2591
  HILANG di replay : 0
  BERLEBIH di replay: 0
  BEDA hak          : 0

  uji revoke anon/PUBLIC (harus MATCH dengan live):
     worker_update_profile    live=[authenticated,postgres,service_role] replay=[authenticated,postgres,service_role] MATCH
     admin_get_payroll        live=[authenticated,postgres,service_role] replay=[authenticated,postgres,service_role] MATCH
     get_worker_profile       live=[authenticated,postgres,service_role] replay=[authenticated,postgres,service_role] MATCH
     login_worker_by_email    live=[anon,authenticated,postgres,service_role] replay=[anon,authenticated,postgres,service_role] MATCH

--- UJI IDEMPOTENSI: baseline dijalankan ULANG di database yang sama ---
  ok   000_baseline_schema.sql (3158ms)
  ok   010_baseline_config_data.sql (817ms)
  hasil: 2/2 berkas idempoten
```
