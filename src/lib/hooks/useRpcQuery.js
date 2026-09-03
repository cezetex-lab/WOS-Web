// ============================================================
// useRpcQuery.js - React Query hook for Supabase RPC calls
// ============================================================
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { rpc } from '../supabase-browser';

/**
 * Hook for fetching data via RPC with React Query caching
 * @param {string} fn - RPC function name
 * @param {object} params - RPC parameters
 * @param {object} options - Query options
 * @returns {object} { data, loading, error, refetch }
 */
export function useRpcQuery(fn, params = {}, options = {}) {
  const queryKey = ['rpc', fn, params];
  const { data, isLoading, error, refetch } = useQuery({
    queryKey,
    queryFn: async () => {
      const result = await rpc(fn, params);
      if (result && result.ok === false) throw new Error(result.msg || 'RPC failed');
      return result;
    },
    enabled: options.enabled !== false && !!fn,
    staleTime: options.staleTime || 5 * 60 * 1000,
    cacheTime: options.cacheTime || 30 * 60 * 1000,
    refetchOnWindowFocus: options.refetchOnWindowFocus || false,
    retry: options.retry || 2,
  });
  return {
    data: data || [],
    loading: isLoading,
    error: error ? error.message : null,
    refetch,
  };
}

/**
 * Hook for mutations (INSERT, UPDATE, DELETE via RPC)
 * @param {string} fn - RPC function name
 * @param {object} options - Mutation options
 * @returns {object} { mutate, loading, error }
 */
export function useRpcMutation(fn, options = {}) {
  const queryClient = useQueryClient();
  const { mutate, isLoading, error } = useMutation({
    mutationFn: async (params) => {
      const result = await rpc(fn, params);
      if (result && result.ok === false) throw new Error(result.msg || 'RPC failed');
      return result;
    },
    onSuccess: (data) => {
      if (options.invalidateKeys) {
        options.invalidateKeys.forEach(key => {
          queryClient.invalidateQueries({ queryKey: key });
        });
      }
      if (options.onSuccess) options.onSuccess(data);
    },
    onError: (err) => {
      if (options.onError) options.onError(err);
    },
  });
  return {
    mutate,
    loading: isLoading,
    error: error ? error.message : null,
  };
}
