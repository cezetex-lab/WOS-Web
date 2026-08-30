-- ============================================================
-- 039: Fix Worker/Admin — 6 missing KPI + Attendance RPCs
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. admin_get_kpi_overview — overall KPI stats
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_kpi_overview() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_kpi_overview()
RETURNS JSONB AS $$
  SELECT jsonb_build_object(
    'ok', true,
    'total_employees', (SELECT COUNT(*) FROM employees_master WHERE status_kerja = 'Aktif'),
    'avg_kpi', COALESCE((SELECT ROUND(AVG(kpi_score), 1) FROM hr_performance), 0),
    'high_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score >= 80),
    'low_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score < 60),
    'medium_performers', (SELECT COUNT(*) FROM hr_performance WHERE kpi_score >= 60 AND kpi_score < 80),
    'total_records', (SELECT COUNT(*) FROM hr_performance),
    'latest_period', COALESCE((SELECT periode FROM hr_performance ORDER BY created_at DESC LIMIT 1), '-')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 2. admin_get_kpi_by_division — KPI grouped by division
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_kpi_by_division() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_kpi_by_division()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.avg_kpi DESC), '[]'::jsonb)
  FROM (
    SELECT
      COALESCE(e.divisi, 'Unknown') AS divisi,
      COALESCE(e.business_unit, 'HQ') AS business_unit,
      COUNT(DISTINCT e.nrp) AS headcount,
      ROUND(COALESCE(AVG(p.kpi_score), 0), 1) AS avg_kpi,
      COUNT(DISTINCT CASE WHEN p.kpi_score >= 80 THEN e.nrp END) AS high_performers,
      COUNT(DISTINCT CASE WHEN p.kpi_score < 60 THEN e.nrp END) AS low_performers
    FROM employees_master e
    LEFT JOIN hr_performance p ON p.nrp = e.nrp
    WHERE e.status_kerja = 'Aktif'
    GROUP BY e.divisi, e.business_unit
    ORDER BY AVG(p.kpi_score) DESC NULLS LAST
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 3. admin_get_kpi_trend — KPI trend over time
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_kpi_trend() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_kpi_trend()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.periode ASC), '[]'::jsonb)
  FROM (
    SELECT
      p.periode,
      ROUND(AVG(p.kpi_score), 1) AS avg_kpi,
      COUNT(*) AS total_employees,
      COUNT(CASE WHEN p.kpi_score >= 80 THEN 1 END) AS high_count,
      COUNT(CASE WHEN p.kpi_score < 60 THEN 1 END) AS low_count
    FROM hr_performance p
    WHERE p.periode IS NOT NULL
    GROUP BY p.periode
    ORDER BY p.periode DESC
    LIMIT 12
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 4. admin_get_top_performers — top 10 performers
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_top_performers() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_top_performers()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
  FROM (
    SELECT
      p.nrp,
      e.nama,
      e.divisi,
      e.business_unit,
      e.posisi,
      p.kpi_score,
      p.periode
    FROM hr_performance p
    JOIN employees_master e ON e.nrp = p.nrp
    WHERE e.status_kerja = 'Aktif'
    ORDER BY p.kpi_score DESC
    LIMIT 10
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 5. admin_get_low_performers — bottom 10 performers
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_low_performers() CASCADE;
CREATE OR REPLACE FUNCTION admin_get_low_performers()
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.*), '[]'::jsonb)
  FROM (
    SELECT
      p.nrp,
      e.nama,
      e.divisi,
      e.business_unit,
      e.posisi,
      p.kpi_score,
      p.periode
    FROM hr_performance p
    JOIN employees_master e ON e.nrp = p.nrp
    WHERE e.status_kerja = 'Aktif'
    ORDER BY p.kpi_score ASC NULLS LAST
    LIMIT 10
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────
-- 6. get_worker_attendance — attendance for a worker or all
-- ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_worker_attendance(p_nrp TEXT) CASCADE;
CREATE OR REPLACE FUNCTION get_worker_attendance(p_nrp TEXT DEFAULT NULL)
RETURNS JSONB AS $$
  SELECT COALESCE(jsonb_agg(sub.* ORDER BY sub.date DESC), '[]'::jsonb)
  FROM (
    SELECT
      a.nrp,
      e.nama,
      e.divisi,
      a.date,
      a.status_hadir,
      a.jam_masuk,
      a.menit_terlambat,
      a.jam_keluar,
      a.shift,
      a.menit_lembur
    FROM hr_attendance a
    JOIN employees_master e ON e.nrp = a.nrp
    WHERE (p_nrp IS NULL OR a.nrp = p_nrp)
    ORDER BY a.date DESC
    LIMIT 50
  ) sub;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
SELECT '039_fix_worker_kpi_rpcs.sql applied' as status;
