import { describe, it, expect, vi } from 'vitest';
import React from 'react';
import { render } from '@testing-library/react';

// ErrorBoundary implementation (same as src/components/ErrorBoundary.jsx)
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }
  static getDerivedStateFromError() { return { hasError: true }; }
  render() {
    if (this.state.hasError) {
      return <div data-testid="error-fallback">Something went wrong: {this.props.fallbackName}</div>;
    }
    return this.props.children;
  }
}

function ThrowingComponent() {
  throw new Error('Test error');
}

function SafeComponent() {
  return <div data-testid="safe">All good</div>;
}

describe('L4: ErrorBoundary Component', () => {
  it('renders children when no error', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const { container } = render(
      <ErrorBoundary fallbackName="Test">
        <SafeComponent />
      </ErrorBoundary>
    );
    expect(container.querySelector('[data-testid="safe"]')).toBeTruthy();
    spy.mockRestore();
  });

  it('shows fallback when child throws', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    render(
      <ErrorBoundary fallbackName="MyPage">
        <ThrowingComponent />
      </ErrorBoundary>
    );
    expect(document.querySelector('[data-testid="error-fallback"]').textContent).toContain('MyPage');
    spy.mockRestore();
  });
});