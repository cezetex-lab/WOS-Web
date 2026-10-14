-- Pulihkan employee.view_all ke hrd_ops (idempotent)

BEGIN;

INSERT INTO public.permission_set_items (permission_set, permission_code)
SELECT 'hrd_ops', 'employee.view_all'
WHERE NOT EXISTS (
  SELECT 1 FROM public.permission_set_items
  WHERE permission_set = 'hrd_ops'
    AND permission_code = 'employee.view_all'
);

COMMIT;
