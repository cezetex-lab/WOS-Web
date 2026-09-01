/**
 * useModuleAccess — React Query hook untuk cek akses modul via RPC
 * 
 * Panggil: const { data, isLoading } = useModuleAccess('mining_simper');
 * data = true/false (boolean akses)
 */
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase-browser';

export function useModuleAccess(moduleCode, requiredRoleLevel = 1, options = {}) {
  return useQuery({
    queryKey: ['moduleAccess', moduleCode, requiredRoleLevel],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('check_module_access', {
        p_module_code: moduleCode,
        p_required_role_level: requiredRoleLevel,
      });
      if (error) {
        console.error('check_module_access error:', error);
        return false;
      }
      return data === true;
    },
    staleTime: 5 * 60 * 1000, // 5 minutes cache
    retry: false,
    ...options,
  });
}

export function useEnabledModules() {
  return useQuery({
    queryKey: ['enabledModules'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_enabled_modules');
      if (error) {
        console.error('get_enabled_modules error:', error);
        return [];
      }
      return data || [];
    },
    staleTime: 5 * 60 * 1000,
    retry: false,
  });
}

export function useCurrentUserContext() {
  return useQuery({
    queryKey: ['currentUserContext'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_current_user_context');
      if (error) {
        console.error('get_current_user_context error:', error);
        return null;
      }
      return data;
    },
    staleTime: 5 * 60 * 1000,
    retry: false,
  });
}
