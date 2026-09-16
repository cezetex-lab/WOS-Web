/**
 * useRpcQuery — Generic hook for a single RPC call.
 * Replaces repetitive useState+useEffect+rpc boilerplate across 12+ pages.
 *
 * Features: cancelled-flag cleanup, isRpcError guard, optional select/projector.
 */
import { useState, useEffect, useCallback } from 'react';
import { rpc, isRpcError } from '@/lib/supabase-browser';
import type { RpcError } from '@/types';

export interface UseRpcQueryOptions<R> {
  fn: string;
  params?: Record<string, unknown>;
  enabled?: boolean;
  defaultValue: R;
  select?: (raw: unknown) => R;
}

export interface UseRpcQueryResult<R> {
  data: R;
  isLoading: boolean;
  error: RpcError | null;
  refetch: () => Promise<void>;
}

export function useRpcQuery<R>({
  fn,
  params,
  enabled = true,
  defaultValue,
  select,
}: UseRpcQueryOptions<R>): UseRpcQueryResult<R> {
  const [data, setData] = useState<R>(defaultValue);
  const [isLoading, setIsLoading] = useState(enabled);
  const [error, setError] = useState<RpcError | null>(null);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    const result = await rpc(fn, params ?? {});

    if (isRpcError(result)) {
      setError(result);
      setData(defaultValue);
      setIsLoading(false);
      return;
    }

    setData(select ? select(result) : (result as R));
    setIsLoading(false);
  }, [fn, params, defaultValue, select]);

  useEffect(() => {
    if (!enabled) {
      setIsLoading(false);
      return;
    }

    let cancelled = false;

    (async () => {
      const result = await rpc(fn, params ?? {});

      if (cancelled) return;

      if (isRpcError(result)) {
        setError(result);
        setData(defaultValue);
      } else {
        setData(select ? select(result) : (result as R));
      }

      setIsLoading(false);
    })();

    return () => { cancelled = true; };
  }, [fn, params, enabled, defaultValue, select]);

  return { data, isLoading, error, refetch: fetchData };
}
