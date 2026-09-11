-- Register missing admin routes
INSERT INTO module_definitions (route_path, route_component, route_group, module_code, module_name, is_active)
VALUES
  ('/admin/career-path', 'CareerPathPage', 'admin', 'career-path', 'Career Path', true),
  ('/admin/compensation-intel', 'CompensationIntel', 'admin', 'compensation-intel', 'Compensation Intel', true)
ON CONFLICT (route_path) DO NOTHING;

-- Verify
SELECT route_path, route_component FROM module_definitions
WHERE route_path IN ('/admin/career-path', '/admin/compensation-intel')
ORDER BY route_path;
