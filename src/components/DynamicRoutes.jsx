/**
 * DynamicRoutes.jsx — Renders routes dynamically from module_definitions table.
 *
 * Reads route_path, route_component, route_group from DB.
 * Maps route_component → lazy React component via route-config.js.
 * No hardcoded routes — add modules from Owner Dashboard → Module Management.
 */
import React, { Suspense, useState, useEffect } from 'react';
import { Route } from 'react-router-dom';
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
 * Fetches enabled modules with route config from DB,
 * returns array of { path, component, group }.
 */
async function fetchRouteConfig() {
  const { data, error } = await rpc('get_enabled_modules');
  if (error || !data) return [];

  return data
    .filter(m => m.route_path && m.route_component)
    .map(m => ({
      path: m.route_path,
      componentName: m.route_component,
      group: m.route_group || 'worker',
      code: m.module_code,
    }));
}

/**
 * Also fetch ALL modules (not just enabled) for admin routes.
 * Admin routes should always be registered (access control is inside components).
 */
async function fetchAllRouteConfig() {
  const { data, error } = await rpc('get_enabled_modules');
  if (error || !data) return [];

  // For now, return all modules with route config (enabled ones)
  return data
    .filter(m => m.route_path && m.route_component)
    .map(m => ({
      path: m.route_path,
      componentName: m.route_component,
      group: m.route_group || 'worker',
      code: m.module_code,
    }));
}

export default function DynamicRoutes({ withNav }) {
  const [routes, setRoutes] = useState([]);
  const [loading, setLoading] = useState(true);

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

  if (loading) return null; // or loading spinner

  return (
    <>
      {routes.map(({ path, componentName, group, code }) => {
        const Component = getComponent(componentName);
        if (!Component) {
          console.warn(`[DynamicRoutes] Unknown component: ${componentName} for module ${code}`);
          return null;
        }

        // Worker routes need withNav wrapper
        if (group === 'worker') {
          return (
            <Route
              key={code}
              path={path}
              element={
                <Suspense fallback={<div className="flex items-center justify-center h-64 text-slate-400">Loading...</div>}>
                  {withNav(Component)}
                </Suspense>
              }
            />
          );
        }

        // Admin routes — also with nav (role check is inside components)
        return (
          <Route
            key={code}
            path={path}
            element={
              <Suspense fallback={<div className="flex items-center justify-center h-64 text-slate-400">Loading...</div>}>
                {withNav(Component)}
              </Suspense>
            }
          />
        );
      })}
    </>
  );
}
