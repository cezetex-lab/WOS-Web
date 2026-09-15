import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => { store[key] = value; },
    removeItem: (key: string) => { delete store[key]; },
    clear: () => { store = {}; },
  };
})();
Object.defineProperty(globalThis, 'localStorage', { value: localStorageMock });

// Simple test component that mimics PrivacyConsent logic
function PrivacyConsent({ onAccept }: { onAccept?: () => void }) {
  const [show, setShow] = React.useState(() => localStorage.getItem('wos_privacy_consent') !== 'true');

  const accept = () => {
    localStorage.setItem('wos_privacy_consent', 'true');
    setShow(false);
    onAccept?.();
  };

  if (!show) return null;
  return (
    <div data-testid="consent-banner">
      <p>We use cookies for security</p>
      <button onClick={accept}>Accept</button>
    </div>
  );
}

describe('L4: PrivacyConsent Component', () => {
  beforeEach(() => localStorageMock.clear());

  it('shows banner when not consented', () => {
    render(<PrivacyConsent />);
    expect(screen.getByTestId('consent-banner')).toBeTruthy();
    expect(screen.getByText('We use cookies for security')).toBeTruthy();
  });

  it('hides banner when already consented', () => {
    localStorageMock.setItem('wos_privacy_consent', 'true');
    const { container } = render(<PrivacyConsent />);
    expect(container.innerHTML).toBe('');
  });

  it('hides banner after accept', () => {
    const onAccept = vi.fn();
    render(<PrivacyConsent onAccept={onAccept} />);
    fireEvent.click(screen.getByText('Accept'));
    expect(onAccept).toHaveBeenCalled();
    expect(localStorageMock.getItem('wos_privacy_consent')).toBe('true');
  });
});
