import React from 'react';
import { ThemeProvider, ToastProvider } from '../lib/ui-components';

export default function Layout({ children }) {
  return (
    <ThemeProvider>
      <ToastProvider>
        {children}
      </ToastProvider>
    </ThemeProvider>
  );
}