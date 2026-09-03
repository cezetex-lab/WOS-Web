// ============================================================
// useKeyboardNavigation.js - WCAG: Keyboard navigation support
// ============================================================
import { useEffect, useCallback } from 'react';

/**
 * Hook for keyboard navigation support
 * @param {object} options - { onEscape, onEnter, onArrowUp, onArrowDown, enabled }
 */
export function useKeyboardNavigation(options = {}) {
  const handleKeyDown = useCallback((e) => {
    if (options.enabled === false) return;
    
    switch (e.key) {
      case 'Escape':
        options.onEscape?.(e);
        break;
      case 'Enter':
        if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
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
 * @param {React.RefObject} containerRef - Ref to container
 * @param {boolean} active - Whether focus trap is active
 */
export function useFocusTrap(containerRef, active = false) {
  useEffect(() => {
    if (!active || !containerRef.current) return;
    
    const container = containerRef.current;
    const focusable = container.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const first = focusable[0];
    const last = focusable[focusable.length - 1];

    function handleTab(e) {
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
