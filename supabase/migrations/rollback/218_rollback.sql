-- rollback/218_rollback.sql — Restore 3 dropped legacy tables
-- These are empty tables restored for schema completeness.

-- 1. mill_boiler (from migration 052)
CREATE TABLE IF NOT EXISTS public.mill_boiler (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nrp text,
    reading_date date,
    boiler_pressure numeric,
    steam_temperature numeric,
    fuel_consumption numeric,
    efficiency numeric,
    notes text,
    created_at timestamptz DEFAULT now()
);

-- 2. mfa_store (from migration 057 — legacy, replaced by mfa_factors)
CREATE TABLE IF NOT EXISTS public.mfa_store (
    nrp text PRIMARY KEY,
    secret text NOT NULL,
    enabled boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 3. hr_preview_data (from migration 001)
CREATE TABLE IF NOT EXISTS public.hr_preview_data (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nrp text,
    data jsonb,
    created_at timestamptz DEFAULT now()
);

NOTIFY pgrst, 'reload schema';
