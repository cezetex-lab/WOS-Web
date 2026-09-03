// ============================================================
// feature-flags.js - Centralized feature flag system
// Uses Supabase for runtime configuration
// ============================================================
import { supabase } from './supabase-browser';

const FLAG_CACHE = {};
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Get a feature flag value
 * @param {string} flagName - Flag name (e.g., 'mining_module', 'ai_copilot')
 * @param {boolean} defaultValue - Default if flag not found
 * @returns {boolean}
 */
export async function getFeatureFlag(flagName, defaultValue = false) {
  // Check cache
  if (FLAG_CACHE[flagName] && Date.now() - FLAG_CACHE[flagName].time < CACHE_TTL) {
    return FLAG_CACHE[flagName].value;
  }

  try {
    const { data } = await supabase
      .from('feature_flags')
      .select('enabled')
      .eq('name', flagName)
      .single();

    const value = data?.enabled ?? defaultValue;
    FLAG_CACHE[flagName] = { value, time: Date.now() };
    return value;
  } catch {
    return defaultValue;
  }
}

/**
 * Check multiple flags at once
 * @param {string[]} flagNames
 * @returns {object} { flagName: boolean }
 */
export async function getFeatureFlags(flagNames) {
  const results = {};
  for (const name of flagNames) {
    results[name] = await getFeatureFlag(name);
  }
  return results;
}

/**
 * Clear flag cache (e.g., after toggle)
 */
export function clearFlagCache(flagName) {
  if (flagName) {
    delete FLAG_CACHE[flagName];
  } else {
    Object.keys(FLAG_CACHE).forEach(k => delete FLAG_CACHE[k]);
  }
}

/**
 * Default feature flags for the platform
 */
export const DEFAULT_FLAGS = {
  mining_module: true,
  estate_module: true,
  mill_module: true,
  ai_copilot: true,
  push_notifications: true,
  offline_mode: false,
  dark_mode: false,
  export_excel: true,
  export_pdf: true,
  mfa_enabled: true,
  wf_approval: true,
  performance_review: true,
  learning_module: true,
  recruitment_module: true,
  engagement_module: true,
};
