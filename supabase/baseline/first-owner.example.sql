-- ============================================================================
-- AKUN OWNER PERTAMA — tempel di SQL Editor project BARU, setelah baseline.
-- Ganti 3 nilai di blok CONFIG di bawah. JANGAN dijalankan di DB live.
-- ============================================================================
-- Kenapa perlu langkah manual: baseline sengaja TIDAK membawa identitas pemilik
-- (system_owner_identity, owner_email) supaya perusahaan baru tidak mewarisi merek
-- dan email perusahaan lain. Akibatnya project baru belum punya siapa pun yang bisa
-- masuk ke OwnerDashboard.
--
-- Alur otentikasi owner (terverifikasi ke kode live 2026-09-18):
--   /owner            → OwnerLogin  : signInWithPassword(email, password)   [Supabase Auth]
--                    → RPC owner_login(p_email) : p_email HARUS == get_owner_email()
--   /owner/dashboard  → OwnerGuard  : RPC check_owner_identity()
--                    → true bila auth.uid() ada di system_owner_identity (is_active)
--   RPC admin lain    → authz_check_admin() juga memeriksa system_owner_identity lebih dulu
--
-- Jadi syarat minimum: (1) user Supabase Auth dengan email owner,
--                      (2) baris system_owner_identity menunjuk auth_id-nya,
--                      (3) company_config.owner_email berisi email yang sama.
-- ============================================================================

-- ── CONFIG: ganti tiga nilai ini ────────────────────────────────────────────
-- OWNER_EMAIL : harus SAMA dengan email user Supabase Auth yang Anda buat
-- OWNER_AUTH_ID : UUID user tersebut (Dashboard → Authentication → Users)
-- COMPANY_NAME : nama perusahaan (opsional di sini, bisa lewat OwnerDashboard)
\set owner_email 'owner@perusahaan.com'
\set owner_auth_id '00000000-0000-0000-0000-000000000000'
\set company_name 'PT Contoh Tambang'
-- ────────────────────────────────────────────────────────────────────────────

-- 1) owner_email: satu-satunya email yang diterima owner_login() (fail-closed, migrasi 230)
do $$
declare
  v_email text := :'owner_email';
  v_cat   text;
begin
  select coalesce((select id from public.config_categories where id = 'security'),
                  (select id from public.config_categories order by id limit 1)) into v_cat;

  if exists (select 1 from public.company_config where config_key = 'owner_email') then
    update public.company_config
       set config_value = jsonb_set(config_value, '{value}', to_jsonb(v_email)),
           updated_at = now()
     where config_key = 'owner_email';
  else
    -- data_type hanya boleh: number | string | boolean | json | array
    insert into public.company_config
      (category_id, config_key, config_value, data_type, label, is_system)
    values (v_cat, 'owner_email', jsonb_build_object('value', v_email), 'string', 'Email Owner', false);
  end if;
  raise notice 'owner_email = %', v_email;
end $$;

-- 2) Identitas owner: inilah yang membuat check_owner_identity() bernilai true
insert into public.system_owner_identity (auth_id, owner_email, is_active)
values (:'owner_auth_id'::uuid, :'owner_email', true)
on conflict (auth_id) do update
  set owner_email = excluded.owner_email,
      is_active   = true;

-- 3) Nama perusahaan (opsional; logo/warna lewat OwnerDashboard → 🎨 Branding)
update public.branding
   set company_name = :'company_name'
 where company_name is distinct from :'company_name';

-- 4) OPSIONAL — bila owner juga perlu muncul sebagai karyawan (mis. untuk payroll/absensi):
--    employees_core hanya mewajibkan nrp + nama.
-- insert into public.employees_core (nrp, nama, email, auth_id, status_kerja_internal)
-- values ('OWNER001', 'Direktur Utama', :'owner_email', :'owner_auth_id'::uuid, 'PKWTT')
-- on conflict (nrp) do update set email = excluded.email, auth_id = excluded.auth_id;

-- ── VERIFIKASI ──────────────────────────────────────────────────────────────
select public.get_owner_email() as owner_email_aktif;
select auth_id, owner_email, is_active from public.system_owner_identity;
select company_name from public.branding;

-- ============================================================================
-- CATATAN: `\set` di atas adalah meta-command psql. Kalau Anda menempel ini ke
-- Supabase SQL Editor (yang tidak mendukung `\set`), ganti dulu setiap :'nama'
-- dengan nilai literal, mis. :'owner_email' → 'owner@perusahaan.com'.
-- ============================================================================
