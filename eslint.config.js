import js from '@eslint/js';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
import babelParser from '@babel/eslint-parser';

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
      'react/jsx-uses-vars': 'error',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      'no-console': 'warn',
      'no-empty': ['error', { allowEmptyCatch: true }],
    },
    settings: {
      react: { version: 'detect' },
    },
  },
  {
    files: ['src/**/*.tsx'],
    languageOptions: {
      parser: babelParser,
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
      'react/jsx-uses-vars': 'error',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      'no-console': 'warn',
      'no-empty': ['error', { allowEmptyCatch: true }],
      // Disable no-undef for TSX — TypeScript type annotations (interfaces,
      // generics like useState<any>) are parsed as identifiers by Babel.
      // Type checking is handled by tsc --noEmit, not ESLint.
      'no-undef': 'off',
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
