-- 199_auth_testing_override.sql (idempotent)
-- Tabel override bypass MFA/OTP khusus owner (OWNER = hantu, ga kelihatan worker/admin)
-- Owner bisa set bypass MFA/OTP untuk testing tanpa selalu isi MFA/OTP

CREATE TABLE IF NOT EXISTS auth_testing_override (
  id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  nrp text NOT NULL UNIQUE,
  mfa_bypass boolean NOT NULL DEFAULT false,
  otp_bypass boolean NOT NULL DEFAULT false,
  updated_by_owner uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_testing_override_nrp ON auth_testing_override (nrp);

-- Grant: hanya owner RPC yang boleh manipilasi tabel ini (via auth.uid)
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_testing_override TO postgres, service_role;

-- Row Level Security (RLS) diaktifkan, tapi hanya bisa diakses via owner RPC
ALTER TABLE auth_testing_override ENABLE ROW LEVEL SECURITY;

-- Policy: hanya bisa diakses via owner RPC (pakai auth.uid = owner)
CREATE POLICY owner_only_testing_override ON auth_testing_override
  FOR ALL
  USING (auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM admin_roles ar
    JOIN user_role_assignments ura ON ura.role_id = ar.id
    WHERE ura.nrp = (SELECT nrp FROM employees_core WHERE auth_id = auth.uid())
    AND ar.role_code IN ('admin_pusat', 'owner')
  ));
