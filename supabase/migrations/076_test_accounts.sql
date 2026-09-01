-- TEST ACCOUNTS: Owner + CEO Worker
-- Auth users must be created manually in Supabase Dashboard

-- 1. OWNER account (for ModuleManagement testing)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM employees_master WHERE nrp = 'OWNER001') THEN
    INSERT INTO employees_master (employee_id, nrp, nama, email, role_level, business_unit_id, divisi, posisi, status_kerja)
    VALUES ('OWNER001', 'OWNER001', 'Super Admin', 'owner@insightwos.com', 5, 'BU04', 'Management', 'Owner', 'PKWTT');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE nrp = 'OWNER001') THEN
    INSERT INTO user_roles (nrp, role_level, role) VALUES ('OWNER001', 5, 'owner');
  END IF;
END $$;

-- 2. CEO Worker (NRP001) — role_level=5, bisa lihat semua
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM employees_master WHERE nrp = 'NRP001') THEN
    INSERT INTO employees_master (employee_id, nrp, nama, email, role_level, business_unit_id, divisi, posisi, status_kerja)
    VALUES ('NRP001', 'NRP001', 'CEO Test', 'ceo@insightwos.com', 5, 'BU01', 'Management', 'CEO', 'PKWTT');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE nrp = 'NRP001') THEN
    INSERT INTO user_roles (nrp, role_level, role) VALUES ('NRP001', 5, 'admin');
  END IF;
END $$;

-- 3. Set ALL Business Units tier = 4 (Enterprise)
UPDATE business_units SET tier = 4 WHERE tier < 4;

-- 4. Enable ALL Industry modules for ALL BUs (testing mode)
UPDATE business_unit_modules SET is_enabled = TRUE;

-- 5. Audit log
INSERT INTO audit_log_owner (owner_nrp, action, target_type, target_id, new_value)
VALUES ('OWNER001', 'SEED_TEST', 'system', 'all', '{"tier": 4, "all_locks": true}');
