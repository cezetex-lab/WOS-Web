-- Transfer ownership dari akun sampel ke akun user sebenarnya
-- Menyentuh DUA sumber: system_owner_identity (authz) + company_config (login page)
-- Idempotent: aman dijalankan ulang.
-- Sebelum: owner@insightwos.com / a8a77284-...
-- Sesudah: cezetex@gmail.com / 6f6b5940-...

BEGIN;

-- 1) system_owner_identity (authz_is_owner)
UPDATE public.system_owner_identity
SET auth_id = '6f6b5940-33e9-4a00-b3f1-c6adf715d606',
    owner_email = 'cezetex@gmail.com'
WHERE id = 1
  AND (auth_id != '6f6b5940-33e9-4a00-b3f1-c6adf715d606'
       OR owner_email != 'cezetex@gmail.com');

-- 2) company_config (get_owner_email untuk login page)
UPDATE public.company_config
SET config_value = '{"value": "cezetex@gmail.com"}'::jsonb,
    updated_at = NOW()
WHERE config_key = 'owner_email'
  AND config_value->>'value' != 'cezetex@gmail.com';

-- Verifikasi kondisi akhir (bukan jumlah baris ter-update)
DO $$
DECLARE
  v_auth_id TEXT;
  v_config  TEXT;
BEGIN
  SELECT auth_id INTO v_auth_id
  FROM public.system_owner_identity WHERE id = 1;
  IF v_auth_id IS DISTINCT FROM '6f6b5940-33e9-4a00-b3f1-c6adf715d606' THEN
    RAISE EXCEPTION 'system_owner_identity tidak sinkron: %', v_auth_id;
  END IF;

  SELECT config_value->>'value' INTO v_config
  FROM public.company_config WHERE config_key = 'owner_email';
  IF v_config IS DISTINCT FROM 'cezetex@gmail.com' THEN
    RAISE EXCEPTION 'company_config tidak sinkron: %', v_config;
  END IF;
END $$;

COMMIT;

