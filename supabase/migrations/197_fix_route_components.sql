-- 197_fix_route_components.sql
-- Root cause of "tab error / module not loading" in admin: 12 module rows had
-- route_component = module_code slug (inserted by register-routes.mjs L-3 fix)
-- instead of the React component name from src/lib/route-config.js COMPONENT_MAP.
-- DynamicRoutes -> getComponent() returned null -> Navigate to "/".
-- Idempotent: only updates rows whose route_component is currently the bad slug.
-- ================================================================

UPDATE module_definitions SET route_component = 'ApprovalCenter'      WHERE module_code = 'approval-center'   AND route_component = 'approval-center';
UPDATE module_definitions SET route_component = 'AuditChainPage'      WHERE module_code = 'audit-chain'       AND route_component = 'audit-chain';
UPDATE module_definitions SET route_component = 'AuditLog'            WHERE module_code = 'audit-log'         AND route_component = 'audit-log';
UPDATE module_definitions SET route_component = 'CareerDevelopment'   WHERE module_code = 'career-dev'        AND route_component = 'career-dev';
UPDATE module_definitions SET route_component = 'FeatureFlagsPage'    WHERE module_code = 'feature-flags'     AND route_component = 'feature-flags';
UPDATE module_definitions SET route_component = 'MasterDataPage'      WHERE module_code = 'master-data'       AND route_component = 'master-data';
UPDATE module_definitions SET route_component = 'Okrs'                WHERE module_code = 'okrs'              AND route_component = 'okrs';
UPDATE module_definitions SET route_component = 'OrgChart'            WHERE module_code = 'org-chart'         AND route_component = 'org-chart';
UPDATE module_definitions SET route_component = 'PerformanceTrend'    WHERE module_code = 'performance-trend' AND route_component = 'performance-trend';
UPDATE module_definitions SET route_component = 'RoleMatrixPage'      WHERE module_code = 'role-matrix'       AND route_component = 'role-matrix';
UPDATE module_definitions SET route_component = 'ShiftSchedule'       WHERE module_code = 'shift-schedule'    AND route_component = 'shift-schedule';
UPDATE module_definitions SET route_component = 'TalentMarketPage'    WHERE module_code = 'talent-market'     AND route_component = 'talent-market';

-- Landing rows for /admin and /worker are shadowed by static routes in App.jsx
-- (Route path="/admin" wins over the "/*" splat), so their route_component is
-- never resolved. Null it so DynamicRoutes simply skips them instead of warning.
UPDATE module_definitions SET route_component = NULL WHERE module_code IN ('admin_landing', 'worker_landing');
