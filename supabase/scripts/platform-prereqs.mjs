/**
 * platform-prereqs.mjs — objek yang DISEDIAKAN platform Supabase dan karenanya TIDAK
 * ADA di database kosong: schema `extensions`/`auth`, `auth.uid()/role()/email()/jwt()`,
 * `auth.users`, stub `cron.*`, dan default privilege Supabase (anon/authenticated/
 * service_role TANPA PUBLIC).
 *
 * Dipakai bersama oleh:
 *   * replay-fresh-install.mjs — membuat database scratch yang menyerupai project Supabase
 *   * verify-install-e2e.mjs   — menguji installer baseline pada project kosong
 *
 * SATU SUMBER KEBENARAN: kalau platform berubah, ubah di sini; kedua harness ikut.
 * Catatan penting: schema `extensions` WAJIB dibuat lebih dulu, kalau tidak
 * `CREATE EXTENSION ... WITH SCHEMA extensions` gagal dan mematikan berkas awal.
 */
export const PREREQS = `
create schema if not exists extensions;
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text, raw_user_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);
create or replace function auth.uid() returns uuid
  language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create or replace function auth.role() returns text
  language sql stable as $$ select nullif(current_setting('request.jwt.claim.role', true), '')::text $$;
create or replace function auth.email() returns text
  language sql stable as $$ select nullif(current_setting('request.jwt.claim.email', true), '')::text $$;
create or replace function auth.jwt() returns jsonb
  language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) $$;
-- pg_cron tidak bisa dipasang di database kedua pada cluster yang sama; stub ini
-- membuat cron.schedule/unschedule bisa di-resolve sehingga berkas penjadwalan jalan.
create schema if not exists cron;
create table if not exists cron.job (
  jobid bigserial primary key, jobname text, schedule text, command text,
  database text, username text, active boolean default true
);
create table if not exists cron.job_run_details (
  jobid bigint, status text, start_time timestamptz, return_message text
);
-- Default privilege Supabase. Proyek Supabase menjalankan ALTER DEFAULT PRIVILEGES
-- sehingga fungsi/tabel BARU di schema public tetap diberi hak ke anon/authenticated/
-- service_role, tetapi TIDAK ke PUBLIC — pernyataan itu MENGGANTIKAN default bawaan
-- PostgreSQL (yang memberi EXECUTE ke PUBLIC). Tanpa menirunya di database scratch,
-- setiap fungsi yang dibuat setelah 172 terlihat punya EXECUTE untuk PUBLIC dan
-- perbandingan ACL menghasilkan ±30 "kebocoran" palsu. Terverifikasi ke live
-- 2026-09-18: pg_default_acl untuk public tidak memuat PUBLIC.
alter default privileges in schema public grant execute on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant select, insert, update, delete, truncate, references, trigger on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;

create or replace function cron.schedule(p_name text, p_schedule text, p_command text)
  returns bigint language plpgsql as $$
declare v_id bigint;
begin
  select jobid into v_id from cron.job where jobname = p_name;
  if v_id is null then
    insert into cron.job(jobname, schedule, command) values (p_name, p_schedule, p_command) returning jobid into v_id;
  end if;
  return v_id;
end $$;
create or replace function cron.unschedule(p_name text) returns boolean
  language plpgsql as $$ begin delete from cron.job where jobname = p_name; return true; end $$;
`;
