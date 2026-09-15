// ============================================================
// useKeyboardNavigation.ts - WCAG: Keyboard navigation support
// ============================================================
import { useEffect, useCallback, RefObject } from 'react';

export interface KeyboardNavigationOptions {
  onEscape?: (e: KeyboardEvent) => void;
  onEnter?: (e: KeyboardEvent) => void;
  onArrowUp?: (e: KeyboardEvent) => void;
  onArrowDown?: (e: KeyboardEvent) => void;
  enabled?: boolean;
}

/**
 * Hook for keyboard navigation support
 * @param options - { onEscape, onEnter, onArrowUp, onArrowDown, enabled }
 */
export function useKeyboardNavigation(options: KeyboardNavigationOptions = {}) {
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (options.enabled === false) return;
    
    switch (e.key) {
      case 'Escape':
        options.onEscape?.(e);
        break;
      case 'Enter':
        if ((e.target as HTMLElement).tagName !== 'INPUT' && (e.target as HTMLElement).tagName !== 'TEXTAREA') {
          options.onEnter?.(e);
        }
        break;
      case 'ArrowUp':
        e.preventDefault();
        options.onArrowUp?.(e);
        break;
      case 'ArrowDown':
        e.preventDefault();
        options.onArrowDown?.(e);
        break;
    }
  }, [options]);

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);
}

/**
 * Trap focus within a container (for modals)
 * @param containerRef - Ref to container
 * @param active - Whether focus trap is active
 */
export function useFocusTrap(containerRef: RefObject<HTMLElement>, active: boolean = false) {
  useEffect(() => {
    if (!active || !containerRef.current) return;
    
    const container = containerRef.current;
    const focusable = container.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const first = focusable[0] as HTMLElement;
    const last = focusable[focusable.length - 1] as HTMLElement;

    function handleTab(e: KeyboardEvent) {
      if (e.key !== 'Tab') return;
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }

    container.addEventListener('keydown', handleTab);
    first?.focus();
    return () => container.removeEventListener('keydown', handleTab);
  }, [active, containerRef]);
}
