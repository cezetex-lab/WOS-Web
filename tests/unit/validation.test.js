import { describe, it, expect } from 'vitest';

describe('Input Validation Utilities', () => {
  it('validates email format', () => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    expect(emailRegex.test('user@company.com')).toBe(true);
    expect(emailRegex.test('invalid')).toBe(false);
    expect(emailRegex.test('@no.com')).toBe(false);
    expect(emailRegex.test('user@')).toBe(false);
  });

  it('validates NRP format', () => {
    const nrpRegex = /^[A-Z]{2,3}\d{3,5}$/;
    expect(nrpRegex.test('NRP001')).toBe(true);
    expect(nrpRegex.test('MIN001')).toBe(true);
    expect(nrpRegex.test('123')).toBe(false);
    expect(nrpRegex.test('')).toBe(false);
  });

  it('validates phone number format', () => {
    const phoneRegex = /^(\+62|62|0)8\d{8,11}$/;
    expect(phoneRegex.test('081234567890')).toBe(true);
    expect(phoneRegex.test('+6281234567890')).toBe(true);
    expect(phoneRegex.test('123')).toBe(false);
  });

  it('validates password strength', () => {
    const isStrongPassword = (p) => p.length >= 8 && /[A-Z]/.test(p) && /[0-9]/.test(p);
    expect(isStrongPassword('Password1')).toBe(true);
    expect(isStrongPassword('weak')).toBe(false);
    expect(isStrongPassword('nouppercase1')).toBe(false);
    expect(isStrongPassword('NO数字')).toBe(false);
  });

  it('validates date format (YYYY-MM-DD)', () => {
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    expect(dateRegex.test('2026-09-03')).toBe(true);
    expect(dateRegex.test('03-09-2026')).toBe(false);
    expect(dateRegex.test('2026/09/03')).toBe(false);
  });

  it('sanitizes HTML input', () => {
    const sanitize = (str) => str.replace(/<[^>]*>/g, '');
    expect(sanitize('<script>alert("xss")</script>')).toBe('alert("xss")');
    expect(sanitize('Hello <b>World</b>')).toBe('Hello World');
    expect(sanitize('No tags')).toBe('No tags');
  });

  it('trims whitespace', () => {
    expect('  hello  '.trim()).toBe('hello');
    expect('\nhello\n'.trim()).toBe('hello');
  });
});

describe('Number Formatting', () => {
  it('formats currency IDR', () => {
    const formatIDR = (n) => 'Rp ' + n.toLocaleString('id-ID');
    expect(formatIDR(1000000)).toBe('Rp 1.000.000');
    expect(formatIDR(0)).toBe('Rp 0');
  });

  it('formats percentage', () => {
    const formatPct = (n) => (n * 100).toFixed(1) + '%';
    expect(formatPct(0.85)).toBe('85.0%');
    expect(formatPct(0)).toBe('0.0%');
    expect(formatPct(1)).toBe('100.0%');
  });

  it('formats large numbers with K/M suffix', () => {
    const formatShort = (n) => {
      if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
      if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
      return n.toString();
    };
    expect(formatShort(1500000)).toBe('1.5M');
    expect(formatShort(2500)).toBe('2.5K');
    expect(formatShort(500)).toBe('500');
  });
});
