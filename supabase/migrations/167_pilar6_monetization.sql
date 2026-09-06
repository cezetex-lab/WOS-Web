-- ================================================================
-- PILAR 6: MONETISASI (PAKET PERPETUAL)
-- Tier pricing + License generator + Module entitlement
-- Migration 167
-- ================================================================
-- Sumber spec: supabase/c/insightWOS_MASTER_PLAN.md bagian 6
-- Peta skema eksisting (CONFIRMED dari migrasi 071):
--   business_units.tier                    INT 0..4 (subscription)
--   module_definitions.minimum_tier_required
--   business_unit_modules.is_enabled
-- RULE 8: tier = SUBSCRIPTION, BUKAN authorization.
-- license_key TIDAK disimpan plaintext (hanya hash + tail), sehingga
-- aman walau tabel terbaca; key hanya muncul sekali saat generate.
-- ================================================================

-- ------------------------------------------------------------------
-- 6.1 TIER PRICING (katalog paket perpetual)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tier_pricing (
  tier             INT PRIMARY KEY CHECK (tier BETWEEN 0 AND 4),
  nama             TEXT NOT NULL,
  harga_idr        NUMERIC NOT NULL DEFAULT 0,
  target_karyawan  TEXT,
  industry_modules TEXT,
  support          TEXT,
  update_policy    TEXT,
  fitur            JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE tier_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE tier_pricing FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tp_select" ON tier_pricing;
CREATE POLICY "tp_select" ON tier_pricing FOR SELECT
USING (auth.uid() IS NOT NULL);

-- Seed harga sesuai insightWOS_MASTER_PLAN.md bagian 6.1-6.2
INSERT INTO tier_pricing (tier, nama, harga_idr, target_karyawan, industry_modules, support, update_policy, fitur) VALUES
  (0, 'GRATIS (Community)', 0, '1-25', 'Tidak ada',
   'Community', 'Tidak ada',
   '["Database karyawan (100 row limit)","Absensi mobile GPS","Pengajuan cuti & izin","ESS dasar","2 user roles"]'),
  (1, 'MINIMALIS', 9500000, '25-100', 'Tidak ada',
   '1 bulan', '1 tahun',
   '["Database unlimited","Absensi + shift","Cuti & izin multi-level","Lembur dasar","Laporan Excel/PDF","5 roles","Backup tool"]'),
  (2, 'STANDAR', 35000000, '100-500', 'Tidak ada',
   '3 bulan', '2 tahun',
   '["Semua TIER 1","Payroll otomatis + slip gaji","KPI & OKR","Performance review 360","LMS","Recruitment pipeline","15+ roles","Dashboard analytics"]'),
  (3, 'PREMIUM', 95000000, '500-2.000', '1 Industry module (MINING/ESTATE/MILL)',
   '6 bulan + Dedicated CS', '3 tahun',
   '["Semua TIER 2","Talent management","Engagement survey & eNPS","Badges & gamifikasi","Workforce analytics","Flight risk & turnover prediction","Custom branding","Full API access","Webhooks","MFA + SSO basic","10 jam konsultasi"]'),
  (4, 'ENTERPRISE', 295000000, '2.000+', 'ALL (21 module)',
   '24/7 1 tahun + Account Manager', 'Lifetime',
   '["Semua TIER 3","AI Copilot + RAG","Workforce simulation","Multi-BU / multi-company","Full source code + white-label","Advanced SSO (SAML/OIDC)","Audit trail immutable","SLA 99.9%","40 jam konsultasi","On-site training 3 hari","Lifetime update"]')
ON CONFLICT (tier) DO UPDATE SET
  nama = EXCLUDED.nama,
  harga_idr = EXCLUDED.harga_idr,
  target_karyawan = EXCLUDED.target_karyawan,
  industry_modules = EXCLUDED.industry_modules,
  support = EXCLUDED.support,
  update_policy = EXCLUDED.update_policy,
  fitur = EXCLUDED.fitur,
  updated_at = NOW();

-- Katalog pricing untuk halaman pricing / dashboard (public read via RPC)
DROP FUNCTION IF EXISTS get_tier_pricing() CASCADE;
CREATE OR REPLACE FUNCTION get_tier_pricing()
RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB;
  v_rows JSONB;
BEGIN
  -- Owner / admin bisa lihat semua (termasuk non-active); selainnya hanya active.
  v_ctx := get_current_user_context();
  IF v_ctx IS NOT NULL AND (v_ctx->>'is_owner')::BOOLEAN THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'tier', tier, 'nama', nama, 'harga_idr', harga_idr, 'target_karyawan', target_karyawan,
      'industry_modules', industry_modules, 'support', support, 'update_policy', update_policy,
      'fitur', fitur, 'is_active', is_active) ORDER BY tier), '[]'::jsonb)
    INTO v_rows FROM tier_pricing;
  ELSE
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'tier', tier, 'nama', nama, 'harga_idr', harga_idr, 'target_karyawan', target_karyawan,
      'industry_modules', industry_modules, 'support', support, 'update_policy', update_policy,
      'fitur', fitur) ORDER BY tier), '[]'::jsonb)
    INTO v_rows FROM tier_pricing WHERE is_active = true;
  END IF;

  RETURN jsonb_build_object('ok', true, 'data', v_rows);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 6.2 COMPANY LICENSE (generator + validator)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS company_licenses (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_unit_id  TEXT NOT NULL REFERENCES business_units(id) ON DELETE CASCADE,
  tier              INT NOT NULL CHECK (tier BETWEEN 0 AND 4),
  licensee_name     TEXT,
  license_key_hash  TEXT NOT NULL UNIQUE,
  license_key_tail  TEXT NOT NULL,
  meta              JSONB,
  status            TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','REVOKED','EXPIRED')),
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  activated_at      TIMESTAMPTZ,
  last_verified_at  TIMESTAMPTZ,
  created_by        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_company_licenses_bu ON company_licenses (business_unit_id, is_active);

ALTER TABLE company_licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_licenses FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cl_select" ON company_licenses;
CREATE POLICY "cl_select" ON company_licenses FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "cl_insert_owner" ON company_licenses;
CREATE POLICY "cl_insert_owner" ON company_licenses FOR INSERT
WITH CHECK (COALESCE((get_current_user_context()->>'is_owner')::BOOLEAN, false));

DROP POLICY IF EXISTS "cl_update_owner" ON company_licenses;
CREATE POLICY "cl_update_owner" ON company_licenses FOR UPDATE
USING (COALESCE((get_current_user_context()->>'is_owner')::BOOLEAN, false));

-- Generator lisensi (OWNER ONLY). Key plaintext HANYA dikembalikan sekali.
DROP FUNCTION IF EXISTS generate_license(TEXT, INT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION generate_license(
  p_business_unit_id TEXT,
  p_tier INT,
  p_licensee_name TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_ctx JSONB;
  v_bu RECORD;
  v_hex TEXT;
  v_key TEXT;
  v_tail TEXT;
BEGIN
  v_ctx := get_current_user_context();
  IF v_ctx IS NULL OR NOT (v_ctx->>'is_owner')::BOOLEAN THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Owner access required');
  END IF;
  IF p_business_unit_id IS NULL OR p_tier IS NULL OR p_tier < 0 OR p_tier > 4 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  SELECT * INTO v_bu FROM business_units WHERE id = p_business_unit_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Business unit tidak ditemukan');
  END IF;

  -- Format: IWOS-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX (32 hex)
  v_hex := UPPER(encode(gen_random_bytes(16), 'hex'));
  v_key := 'IWOS-'
    || SUBSTR(v_hex, 1, 4) || '-' || SUBSTR(v_hex, 5, 4) || '-' || SUBSTR(v_hex, 9, 4) || '-' || SUBSTR(v_hex, 13, 4) || '-'
    || SUBSTR(v_hex, 17, 4) || '-' || SUBSTR(v_hex, 21, 4) || '-' || SUBSTR(v_hex, 25, 4) || '-' || SUBSTR(v_hex, 29, 4);
  v_tail := RIGHT(v_key, 4);

  INSERT INTO company_licenses (business_unit_id, tier, licensee_name, license_key_hash, license_key_tail, meta, created_by)
  VALUES (p_business_unit_id, p_tier, p_licensee_name,
          encode(digest(v_key, 'sha256'), 'hex'),
          v_tail,
          jsonb_build_object('unit_code', v_bu.unit_code, 'unit_name', v_bu.unit_name),
          v_ctx->>'nrp');

  -- Lisensi baru = tier subscription business unit
  UPDATE business_units SET tier = p_tier WHERE id = p_business_unit_id;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('LICENSE_GENERATED',
          jsonb_build_object('business_unit_id', p_business_unit_id, 'tier', p_tier, 'tail', v_tail)::text,
          NOW());

  RETURN jsonb_build_object('ok', true, 'business_unit_id', p_business_unit_id, 'tier', p_tier,
                            'license_key', v_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Aktivasi lisensi: verifikasi hash lalu sinkronkan tier ke business_units.
DROP FUNCTION IF EXISTS activate_license(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION activate_license(p_license_key TEXT)
RETURNS JSONB AS $$
DECLARE
  v_lic RECORD;
  v_hash TEXT;
BEGIN
  IF p_license_key IS NULL OR LENGTH(p_license_key) < 20 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'License key tidak valid');
  END IF;

  v_hash := encode(digest(TRIM(p_license_key), 'sha256'), 'hex');
  SELECT * INTO v_lic FROM company_licenses
  WHERE license_key_hash = v_hash AND status = 'ACTIVE' AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'License tidak ditemukan / tidak aktif');
  END IF;

  UPDATE company_licenses SET activated_at = COALESCE(activated_at, NOW()), last_verified_at = NOW()
  WHERE id = v_lic.id;

  UPDATE business_units SET tier = v_lic.tier WHERE id = v_lic.business_unit_id;

  INSERT INTO audit_log (action, detail, timestamp)
  VALUES ('LICENSE_ACTIVATED',
          jsonb_build_object('business_unit_id', v_lic.business_unit_id, 'tier', v_lic.tier)::text,
          NOW());

  RETURN jsonb_build_object('ok', true, 'business_unit_id', v_lic.business_unit_id, 'tier', v_lic.tier);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Validasi lisensi BU (tanpa membocorkan key).
DROP FUNCTION IF EXISTS validate_license(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION validate_license(p_business_unit_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_lic RECORD;
  v_tier INT;
BEGIN
  IF p_business_unit_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  SELECT * INTO v_lic FROM company_licenses
  WHERE business_unit_id = p_business_unit_id AND status = 'ACTIVE' AND is_active = true
  ORDER BY created_at DESC LIMIT 1;

  SELECT tier INTO v_tier FROM business_units WHERE id = p_business_unit_id;

  IF v_lic.id IS NOT NULL THEN
    UPDATE company_licenses SET last_verified_at = NOW() WHERE id = v_lic.id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'business_unit_id', p_business_unit_id,
    'licensed', (v_lic.id IS NOT NULL),
    'license_tier', v_lic.tier,
    'bu_tier', v_tier,
    'tail', v_lic.license_key_tail,
    'activated_at', v_lic.activated_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- 6.3 MODULE ENTITLEMENT (tier vs minimum_tier_required vs is_enabled)
-- ------------------------------------------------------------------

-- Update minimum_tier_required sesuai paket produk (master plan 6.4):
-- CORE = 0, INDUSTRY = 3, PLATFORM/GOVERNANCE = 2, INTELLIGENCE (AI) = 4.
DO $$ BEGIN
  IF to_regclass('public.module_definitions') IS NOT NULL THEN
    UPDATE module_definitions
    SET minimum_tier_required = CASE
      WHEN is_industry_module THEN 3
      WHEN module_group = 'INTELLIGENCE' THEN 4
      WHEN module_group = 'PLATFORM' THEN 2
      WHEN module_group = 'GOVERNANCE' THEN 2
      ELSE 0
    END;
  END IF;
END $$;

-- Lihat tier sebuah business unit.
DROP FUNCTION IF EXISTS get_bu_tier(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_bu_tier(p_business_unit_id TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_bu TEXT;
  v_tier INT;
BEGIN
  v_bu := COALESCE(p_business_unit_id, authz_get_bu());
  IF v_bu IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'business_unit_id', NULL, 'tier', NULL);
  END IF;
  SELECT tier INTO v_tier FROM business_units WHERE id = v_bu;
  RETURN jsonb_build_object('ok', true, 'business_unit_id', v_bu, 'tier', v_tier);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Cek entitlement modul untuk sebuah BU.
-- allowed = (tier BU >= minimum_tier_required) AND (modul diaktifkan BU).
DROP FUNCTION IF EXISTS check_module_entitlement(TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION check_module_entitlement(
  p_module_code TEXT,
  p_business_unit_id TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_bu TEXT;
  v_tier INT := 0;
  v_md RECORD;
  v_enabled BOOLEAN := true;
BEGIN
  IF p_module_code IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Parameter tidak valid');
  END IF;

  v_bu := COALESCE(p_business_unit_id, authz_get_bu());
  IF v_bu IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Business unit tidak dapat ditentukan');
  END IF;

  SELECT tier INTO v_tier FROM business_units WHERE id = v_bu;
  v_tier := COALESCE(v_tier, 0);

  SELECT * INTO v_md FROM module_definitions WHERE module_code = p_module_code;
  IF NOT FOUND THEN
    -- Modul legacy/tidak terdaftar: tidak dibatasi (biar tidak memutus modul lama)
    RETURN jsonb_build_object('ok', true, 'module_code', p_module_code,
                              'business_unit_id', v_bu, 'tier', v_tier,
                              'allowed', true, 'registered', false);
  END IF;

  SELECT is_enabled INTO v_enabled FROM business_unit_modules
  WHERE business_unit_id = v_bu AND module_code = p_module_code;

  IF v_enabled IS NULL THEN
    -- Tanpa baris business_unit_modules: modul non-industri dianggap aktif
    v_enabled := NOT COALESCE(v_md.is_industry_module, false);
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'module_code', p_module_code,
    'business_unit_id', v_bu,
    'tier', v_tier,
    'minimum_tier_required', v_md.minimum_tier_required,
    'is_enabled', v_enabled,
    'allowed', (v_tier >= COALESCE(v_md.minimum_tier_required, 0) AND v_enabled),
    'registered', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------------
-- GRANTs
-- ------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION get_tier_pricing() TO anon;
GRANT EXECUTE ON FUNCTION get_tier_pricing() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_license(TEXT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION activate_license(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_license(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_bu_tier(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_module_entitlement(TEXT, TEXT) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '=== Pilar 6: Monetisasi -- 2 tables, 6 functions ===';
END $$;
