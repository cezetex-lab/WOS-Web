/**
 * DynamicRoutes.jsx — Renders routes dynamically from module_definitions table.
 *
 * Reads route_path, route_component, route_group from DB.
 * Maps route_component → lazy React component via route-config.js.
 * No hardcoded routes — add modules from Owner Dashboard → Module Management.
 */
import React, { Suspense, useState, useEffect } from 'react';
import { useLocation, Navigate } from 'react-router-dom';
import { rpc } from '@/lib/supabase-browser';
import { getComponent } from '@/lib/route-config';
import LazyLoad from './LazyLoad';
import ErrorBoundary from './ErrorBoundary';

function RouteWrapper({ Component, name }) {
  return (
    <ErrorBoundary fallbackName={name || 'Page'}>
      <LazyLoad>
        <Component />
      </LazyLoad>
    </ErrorBoundary>
  );
}

/**
 * Fetches ALL modules with route config from DB.
 * Admin routes should always be registered (access control is inside components).
 */
async function fetchAllRouteConfig() {
  // NOTE: rpc() helper mengembalikan DATA MENTAH (array jsonb dari
  // get_enabled_modules), bukan envelope {data, error}. Jangan destructure.
  const res = await rpc('get_enabled_modules');
  const list = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
  if (!list.length) console.warn('[DynamicRoutes] get_enabled_modules returned no rows');

  return list
    .filter(m => m.route_path && m.route_component)
    .map(m => ({
      path: m.route_path,
      componentName: m.route_component,
      group: m.route_group || 'worker',
      code: m.module_code,
    }));
}

const normalizePath = p => ((p || '').replace(/\/+$/, '') || '/');

export default function DynamicRoutes({ withNav }) {
  const [routes, setRoutes] = useState([]);
  const [loading, setLoading] = useState(true);
  const location = useLocation();

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const config = await fetchAllRouteConfig();
      if (!cancelled) {
        setRoutes(config);
        setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  if (loading) return <div className="p-4 text-white">Loading routes...</div>;

  // NOTE: route_path values from module_definitions are absolute paths (e.g. /admin/payroll).
  // A nested <Routes> can never match here: this component renders inside <Route path="/*">,
  // so the splat already consumes the whole location — match the current path manually instead.
  const current = normalizePath(location.pathname);
  const match = routes.find(r => normalizePath(r.path) === current);

  if (!match) return <Navigate to="/" replace />;

  const Component = getComponent(match.componentName);
  if (!Component) {
    console.warn(`[DynamicRoutes] Unknown component: ${match.componentName} for module ${match.code}`);
    return <Navigate to="/" replace />;
  }

  return (
    <Suspense fallback={<div className="flex items-center justify-center h-64 text-slate-400">Loading...</div>}>
      {withNav(Component)}
    </Suspense>
  );
}
