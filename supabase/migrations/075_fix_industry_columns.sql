-- FIX: Add business_unit_id to all existing Industry tables
-- Some tables were created in earlier migrations without this column

-- Estate
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_blocks' AND column_name='business_unit_id') THEN ALTER TABLE estate_blocks ADD COLUMN business_unit_id TEXT; END IF; END $$;

-- Mill (from 052)
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_boiler' AND column_name='business_unit_id') THEN ALTER TABLE mill_boiler ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_press' AND column_name='business_unit_id') THEN ALTER TABLE mill_press ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_packing' AND column_name='business_unit_id') THEN ALTER TABLE mill_packing ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_maintenance' AND column_name='business_unit_id') THEN ALTER TABLE mill_maintenance ADD COLUMN business_unit_id TEXT; END IF; END $$;

-- mill_qc_results → rename to mill_qc if needed, or add column
DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='mill_qc_results') AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='mill_qc') THEN ALTER TABLE mill_qc_results RENAME TO mill_qc; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_qc' AND column_name='business_unit_id') THEN ALTER TABLE mill_qc ADD COLUMN business_unit_id TEXT; END IF; END $$;

-- mill_breakdowns → rename to mill_breakdown if needed
DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='mill_breakdowns') AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='mill_breakdown') THEN ALTER TABLE mill_breakdowns RENAME TO mill_breakdown; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_breakdown' AND column_name='business_unit_id') THEN ALTER TABLE mill_breakdown ADD COLUMN business_unit_id TEXT; END IF; END $$;

-- All 21 tables: add business_unit_id if missing (safety net)
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_simper' AND column_name='business_unit_id') THEN ALTER TABLE mining_simper ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_equipment' AND column_name='business_unit_id') THEN ALTER TABLE mining_equipment ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_production' AND column_name='business_unit_id') THEN ALTER TABLE mining_production ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_fuel' AND column_name='business_unit_id') THEN ALTER TABLE mining_fuel ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_fatigue' AND column_name='business_unit_id') THEN ALTER TABLE mining_fatigue ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_safety' AND column_name='business_unit_id') THEN ALTER TABLE mining_safety ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mining_jsa' AND column_name='business_unit_id') THEN ALTER TABLE mining_jsa ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_harvest' AND column_name='business_unit_id') THEN ALTER TABLE estate_harvest ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_irrigation' AND column_name='business_unit_id') THEN ALTER TABLE estate_irrigation ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_nursery' AND column_name='business_unit_id') THEN ALTER TABLE estate_nursery ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_transport' AND column_name='business_unit_id') THEN ALTER TABLE estate_transport ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_field' AND column_name='business_unit_id') THEN ALTER TABLE estate_field ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='estate_yield' AND column_name='business_unit_id') THEN ALTER TABLE estate_yield ADD COLUMN business_unit_id TEXT; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='mill_shift' AND column_name='business_unit_id') THEN ALTER TABLE mill_shift ADD COLUMN business_unit_id TEXT; END IF; END $$;
