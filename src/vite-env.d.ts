/// <reference types="vite/client" />

// Ambient declarations for JSX components (migrated to TS gradually)
// These cover lazy() imports without file extensions in route-config.ts
declare module '*.jsx' {
  import type { ComponentType } from 'react';
  const Component: ComponentType;
  export default Component;
}

declare module '*.tsx' {
  import type { ComponentType } from 'react';
  const Component: ComponentType;
  export default Component;
}

// Environment variables
interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
