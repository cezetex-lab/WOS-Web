/**
 * useModuleAccess — Plain React hooks (no React Query dependency)
 * P2 FIX: Removed session fallback — auth.uid() is the only source of truth
 */
import { useState, useEffect } from 'react';
import { supabase, rpc, isRpcError } from '@/lib/supabase-browser';
import type { UserContext } from '@/types';

export function useModuleAccess(moduleCode: string, requiredRoleLevel: number = 1) {
  const [hasAccess, setHasAccess] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!moduleCode) return;
    let cancelled = false;
    (async () => {
      const result = await rpc<boolean>('check_module_access', {
        p_module_code: moduleCode,
        p_required_role_level: requiredRoleLevel,
      });
      if (!cancelled) {
        setHasAccess(result === true);
        setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [moduleCode, requiredRoleLevel]);

  return { data: hasAccess, isLoading: loading };
}

export function useEnabledModules() {
  const [modules, setModules] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const result = await rpc<any[]>('get_enabled_modules');
      if (!cancelled) {
        setModules(isRpcError(result) ? [] : result || []);
        setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  return { data: modules, isLoading: loading };
}

export function useCurrentUserContext() {
  const [ctx, setCtx] = useState<UserContext | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        // P2 FIX: No session fallback — must login via Supabase Auth
        if (!cancelled) {
          setCtx(null);
          setLoading(false);
        }
        return;
      }

      const result = await rpc<Partial<UserContext>>('get_user_context_by_auth_id', { p_auth_id: user.id });
      if (!cancelled) {
        // Kegagalan transport tidak boleh di-spread menjadi "context" palsu.
        setCtx(isRpcError(result) ? null : {
          ...result,
          ok: result?.ok ?? true,
          is_owner: result?.role === 'owner',
        });
        setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  return { data: ctx, isLoading: loading };
}
