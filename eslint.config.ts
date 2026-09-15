import js from '@eslint/js';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
import babelParser from '@babel/eslint-parser';

// NOTE: typescript-eslint is NOT used here on purpose — its typescript-estree
// layer crashes against the project's TypeScript 7 (native port) API
// ("Cannot read properties of undefined (reading 'Cjs')"). Babel parses the TS
// syntax fine, and type-correctness is owned by `npm run check:types` (tsc).

// Vitest globals are enabled project-wide (vitest.config.ts → globals: true),
// but the `globals` package has no "vitest" preset — declare the API surface.
const vitestGlobals = {
  describe: 'readonly',
  it: 'readonly',
  test: 'readonly',
  expect: 'readonly',
  vi: 'readonly',
  beforeEach: 'readonly',
  afterEach: 'readonly',
  beforeAll: 'readonly',
  afterAll: 'readonly',
  suite: 'readonly',
};

export default [
  js.configs.recommended,
  {
    // TS-only rule (§3.11): src/, tests/ and root config files are all TS.
    files: ['src/**/*.{ts,tsx}', 'tests/**/*.{ts,tsx}', '*.config.ts'],
    languageOptions: {
      parser: babelParser,
      ecmaVersion: 'latest',
      sourceType: 'module',
      parserOptions: {
        ecmaFeatures: { jsx: true },
        requireConfigFile: false,
        babelOptions: {
          presets: ['@babel/preset-typescript'],
          plugins: ['@babel/plugin-syntax-jsx'],
        },
      },
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.es2021,
        ...vitestGlobals,
      },
    },
    plugins: {
      react,
      'react-hooks': reactHooks,
    },
    rules: {
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
      'react/jsx-uses-vars': 'error',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'no-empty': ['error', { allowEmptyCatch: true }],
      // TypeScript owns unused-symbol + undefined-name detection (tsc --noEmit);
      // ESLint sees TS annotations/generics as identifiers.
      'no-unused-vars': 'off',
      'no-undef': 'off',
      'no-console': 'warn',
    },
    settings: {
      react: { version: 'detect' },
    },
  },
  {
    files: ['*.config.ts', 'tests/**/*.{ts,tsx}'],
    rules: {
      // Node/build/test glue legitimately logs (benchmarks, diagnostics).
      'no-console': 'off',
    },
  },
  {
    // Ambient declaration files: ESLint's Babel-based scope analysis merges
    // separate `declare module` blocks, so identical local type aliases look
    // like redeclarations (false positive). tsc validates these files.
    files: ['**/*.d.ts'],
    rules: {
      'no-redeclare': 'off',
      'no-undef': 'off',
      'no-unused-vars': 'off',
    },
  },
  prettier,
  {
    ignores: ['dist/', 'node_modules/', 'supabase/', 'test-results/', '.freebuff/'],
  },
];
