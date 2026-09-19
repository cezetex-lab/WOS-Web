-- SQL-04 fix: align live hr_okrs (6 cols) to canonical 10-col schema (141)
-- Evidence: live lacks key_result, target_value, current_value, updated_at
-- Source verified: src/Okrs.tsx references key_result & target_value
-- Decision: Opsi 2 (migrasi 10 kolom benar, kode menggunakan 4 kolom tambahan)
ALTER TABLE IF EXISTS hr_okrs ADD COLUMN IF NOT EXISTS key_result TEXT;
ALTER TABLE IF EXISTS hr_okrs ADD COLUMN IF NOT EXISTS target_value NUMERIC(10,2);
ALTER TABLE IF EXISTS hr_okrs ADD COLUMN IF NOT EXISTS current_value NUMERIC(10,2) DEFAULT 0;
ALTER TABLE IF EXISTS hr_okrs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
