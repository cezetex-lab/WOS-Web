BEGIN;

UPDATE public.system_owner_identity
SET auth_id = 'a8a77284-ed50-4642-b393-4bccb448e0c8',
    owner_email = 'owner@insightwos.com'
WHERE id = 1
  AND owner_email = 'cezetex@gmail.com';

UPDATE public.company_config
SET config_value = '{"value": "owner@insightwos.com"}'::jsonb,
    updated_at = NOW()
WHERE config_key = 'owner_email'
  AND config_value->>'value' = 'cezetex@gmail.com';

COMMIT;

