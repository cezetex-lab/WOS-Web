-- FIX: Update user_roles CHECK constraint to include 'owner' and new V6 roles
-- Old constraint from 051: admin_pusat, admin_hrd, admin_finance, admin_produksi, manager, worker

DO $$
BEGIN
  -- Drop old constraint
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_roles_role_check') THEN
    ALTER TABLE user_roles DROP CONSTRAINT user_roles_role_check;
  END IF;
  -- Add new constraint with all V6 roles
  ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
    CHECK (role IN (
      'owner', 'admin', 'worker',
      'admin_pusat','admin_hrd','admin_finance','admin_produksi',
      'manager','supervisor','director'
    ));
END $$;
