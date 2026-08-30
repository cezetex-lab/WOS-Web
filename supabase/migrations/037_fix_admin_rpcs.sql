-- ============================================================
-- 037: Fix admin_get_employees GROUP BY error
-- ============================================================

DROP FUNCTION IF EXISTS admin_get_employees() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_employees()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.nama), '[]'::jsonb)
  FROM (
    SELECT
      e.nrp,
      e.nik,
      e.nama,
      e.email,
      e.divisi,
      e.posisi AS jabatan,
      e.status_kerja AS status,
      e.status_kerja AS jenis,
      e.no_hp AS phone,
      e.business_unit,
      e.tanggal_masuk,
      CASE WHEN e.status_kerja = 'Aktif' THEN true ELSE false END AS is_active
    FROM employees_master e
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

SELECT '037_fix_admin_rpcs.sql applied' as status;
