import js from '@eslint/js';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import prettier from 'eslint-config-prettier';
import globals from 'globals';

export default [
  js.configs.recommended,
  {
    files: ['src/**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
      globals: {
        ...globals.browser,
        ...globals.es2021,
      },
    },
    plugins: {
      react,
      'react-hooks': reactHooks,
    },
    rules: {
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
      // ESLint v9 core no-unused-vars tidak menghitung penggunaan JSX sebagai
      // "used" — zonder deze regel worden alle geïmporteerde componenten
      // onterecht als unused gemarkeerd (1000+ false positives repo-wide).
      'react/jsx-uses-vars': 'error',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      'no-console': 'warn',
      // Empty catch blocks = silent-fail pattern yang diing LUAR codebase
      // (network resilience, best-effort fetch). Lint tetap di-enforce
      // untuk if/else/loop/finally le kosong (allowEmptyCatch=false bagi-nya).
      'no-empty': ['error', { allowEmptyCatch: true }],
    },
    settings: {
      react: { version: 'detect' },
    },
  },
  prettier,
  {
    ignores: ['dist/', 'node_modules/', 'supabase/', 'tests/'],
  },
];

