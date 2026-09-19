-- ============================================================
-- Migration 062: Global Core
-- Phase 5: currency, timezone, employment_type, i18n
-- ============================================================

-- 1. Add timezone to employees_master
ALTER TABLE employees_master ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'Asia/Jakarta';

-- 2. Add currency_code to hr_payroll
ALTER TABLE hr_payroll ADD COLUMN IF NOT EXISTS currency_code TEXT DEFAULT 'IDR';

-- 3. Expand employment_type CHECK (status_kerja)
-- FIX (2026-09-18): normalisasi nilai lama HARUS dijalankan SEBELUM ADD CONSTRAINT.
-- Sebelumnya UPDATE-nya ada di bawah, sehingga instalasi dari awal gagal di sini
-- ('ERROR: check constraint "employees_master_status_kerja_check" ... is violated by
-- some row') karena seed demo 034 memakai status_kerja = 'Aktif'.
-- Urutan baru ini idempoten: di DB live (semua baris sudah PKWTT) UPDATE-nya kena 0 baris.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'employees_master_status_kerja_check') THEN
    ALTER TABLE employees_master DROP CONSTRAINT employees_master_status_kerja_check;
  END IF;
END $$;

-- 4. Normalisasi employment_type lama ke nilai baru.
-- PKWTT = permanent, PKWT = fixed-term contract.
-- FIX (2026-09-18): pemetaan lama hanya menangani 5 nilai ('Aktif','Permanent',
-- 'Active','Contract','Kontrak'), sehingga seed demo 047 (status_kerja = 'Resign')
-- tetap melanggar CHECK di bawah dan instalasi dari awal berhenti di sini.
-- Sekarang eksplisit + tidak menyisakan nilai di luar daftar (idempoten: di DB
-- live semua baris sudah PKWTT sehingga UPDATE kena 0 baris).
UPDATE employees_master
   SET status_kerja = CASE
     WHEN status_kerja IN ('Aktif','Permanent','Active') THEN 'PKWTT'
     WHEN status_kerja IN ('Contract','Kontrak')         THEN 'PKWT'
     ELSE 'PKWTT'  -- nilai di luar kontrak (mis. demo 'Resign') -> default permanen
   END
 WHERE status_kerja IS NULL
    OR status_kerja NOT IN ('PKWTT','PKWT','KONTRAK','OUTSOURCING','MAGANG','PART_TIME','FREELANCE','PROBATION');

ALTER TABLE employees_master
  ADD CONSTRAINT employees_master_status_kerja_check
  CHECK (status_kerja IN ('PKWTT','PKWT','KONTRAK','OUTSOURCING','MAGANG','PART_TIME','FREELANCE','PROBATION'));

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_emp_timezone ON employees_master(timezone);
CREATE INDEX IF NOT EXISTS idx_payroll_currency ON hr_payroll(currency_code);
CREATE INDEX IF NOT EXISTS idx_emp_status_kerja ON employees_master(status_kerja);

-- 6. Currency master reference table
CREATE TABLE IF NOT EXISTS currency_master (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  symbol TEXT,
  decimal_precision INTEGER DEFAULT 2,
  exchange_rate_to_idr NUMERIC(15,4) DEFAULT 1.0,
  effective_date DATE DEFAULT CURRENT_DATE,
  is_active BOOLEAN DEFAULT TRUE
);

-- Seed major currencies
INSERT INTO currency_master (code, name, symbol, exchange_rate_to_idr) VALUES
('IDR', 'Indonesian Rupiah', 'Rp', 1.0),
('USD', 'US Dollar', '$', 15800.00),
('SGD', 'Singapore Dollar', 'S$', 11800.00),
('MYR', 'Malaysian Ringgit', 'RM', 3600.00),
('AUD', 'Australian Dollar', 'A$', 10200.00),
('EUR', 'Euro', 'EUR', 17200.00),
('GBP', 'British Pound', 'GBP', 20100.00),
('JPY', 'Japanese Yen', 'JPY', 105.00),
('CNY', 'Chinese Yuan', 'CNY', 2180.00)
ON CONFLICT (code) DO NOTHING;

-- 7. Timezone master reference table
CREATE TABLE IF NOT EXISTS timezone_master (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  utc_offset TEXT,
  is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO timezone_master (code, name, utc_offset) VALUES
('Asia/Jakarta', 'WIB (Jakarta)', '+07:00'),
('Asia/Makassar', 'WITA (Makassar)', '+08:00'),
('Asia/Jayapura', 'WIT (Jayapura)', '+09:00'),
('Asia/Singapore', 'SGT (Singapore)', '+08:00'),
('Asia/Kuala_Lumpur', 'MYT (Kuala Lumpur)', '+08:00'),
('Australia/Sydney', 'AEST (Sydney)', '+10:00'),
('America/New_York', 'EST (New York)', '-05:00'),
('Europe/London', 'GMT (London)', '+00:00'),
('Asia/Tokyo', 'JST (Tokyo)', '+09:00')
ON CONFLICT (code) DO NOTHING;

-- 8. RLS
ALTER TABLE currency_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE timezone_master ENABLE ROW LEVEL SECURITY;
CREATE POLICY "currency_read" ON currency_master FOR SELECT USING (true);
CREATE POLICY "timezone_read" ON timezone_master FOR SELECT USING (true);