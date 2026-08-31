// ============================================================
// security.js — Password Policy + Input Sanitization + Validation
// ============================================================

/**
 * Password Policy (OWASP guidelines)
 * - Min 8 chars
 * - At least 1 uppercase
 * - At least 1 lowercase
 * - At least 1 number
 * - At least 1 special char
 */
export const PASSWORD_POLICY = {
  minLength: 8,
  maxLength: 128,
  requireUppercase: true,
  requireLowercase: true,
  requireNumber: true,
  requireSpecial: true,
  specialChars: '!@#$%^&*()_+-=[]{}|;:,.<>?'
};

export function validatePassword(password) {
  const errors = [];
  if (!password) return { valid: false, errors: ['Password wajib diisi'] };
  if (password.length < PASSWORD_POLICY.minLength)
    errors.push(`Minimal ${PASSWORD_POLICY.minLength} karakter`);
  if (password.length > PASSWORD_POLICY.maxLength)
    errors.push(`Maksimal ${PASSWORD_POLICY.maxLength} karakter`);
  if (PASSWORD_POLICY.requireUppercase && !/[A-Z]/.test(password))
    errors.push('Harus ada huruf besar (A-Z)');
  if (PASSWORD_POLICY.requireLowercase && !/[a-z]/.test(password))
    errors.push('Harus ada huruf kecil (a-z)');
  if (PASSWORD_POLICY.requireNumber && !/[0-9]/.test(password))
    errors.push('Harus ada angka (0-9)');
  if (PASSWORD_POLICY.requireSpecial && !/[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]/.test(password))
    errors.push('Harus ada karakter spesial (!@#$%^&*)');
  return { valid: errors.length === 0, errors };
}

/**
 * Input Sanitization — prevent XSS
 */
export function sanitizeInput(input) {
  if (typeof input !== 'string') return input;
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .trim();
}

/**
 * NRP Validation — 3-4 letter prefix + 4 digits
 * Format: MNG0001, EST0001, MLL0001, HQ0001, ADM-001
 */
export function validateNRP(nrp) {
  if (!nrp) return false;
  return /^[A-Z]{2,4}[0-9]{3,4}$/.test(nrp) || /^[A-Z]{2,4}-[0-9]{2,4}$/.test(nrp);
}

/**
 * NIK Validation — 16 digits (Indonesian standard)
 */
export function validateNIK(nik) {
  if (!nik) return false;
  return /^[0-9]{16}$/.test(nik);
}

/**
 * Email Validation
 */
export function validateEmail(email) {
  if (!email) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Phone Validation — Indonesian format
 */
export function validatePhone(phone) {
  if (!phone) return false;
  return /^(\+62|62|0)[0-9]{9,13}$/.test(phone.replace(/\s/g, ''));
}

/**
 * SQL Injection prevention — basic check
 */
export function hasSQLInjection(input) {
  if (!input || typeof input !== 'string') return false;
  const patterns = [
    /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|WHERE|AND|OR)\b)/i,
    /(--)|(\/\*)|(\*\/)|(;)/,
    /('|")(\s)*(OR|AND)(\s)*('|")/i
  ];
  return patterns.some(p => p.test(input));
}

/**
 * Validate all form fields before submit
 */
export function validateForm(fields) {
  const errors = {};
  for (const [name, config] of Object.entries(fields)) {
    const { value, type, required, label } = config;
    if (required && (!value || value.toString().trim() === '')) {
      errors[name] = `${label || name} wajib diisi`;
      continue;
    }
    if (value && hasSQLInjection(value)) {
      errors[name] = `${label || name} mengandung karakter tidak valid`;
    }
    if (type === 'email' && value && !validateEmail(value)) {
      errors[name] = 'Format email tidak valid';
    }
    if (type === 'nik' && value && !validateNIK(value)) {
      errors[name] = 'NIK harus 16 digit angka';
    }
    if (type === 'phone' && value && !validatePhone(value)) {
      errors[name] = 'Format telepon tidak valid';
    }
  }
  return { valid: Object.keys(errors).length === 0, errors };
}

/**
 * Mask sensitive data for display
 * e.g., maskSalary("8500000") → "8.500.***"
 */
export function maskSensitive(value, showFirst = 3) {
  if (!value) return '***';
  const str = String(value);
  if (str.length <= showFirst) return str;
  return str.slice(0, showFirst) + '***';
}

/**
 * Role-based field visibility check
 */
const SENSITIVE_FIELDS = ['salary', 'bank_account', 'tax_number', 'npwp', 'bpjs_ketenagakerjaan', 'bpjs_kesehatan'];

export function canViewSensitiveField(userRole, field) {
  if (!SENSITIVE_FIELDS.includes(field)) return true;
  // Only admin_pusat, admin_hr, manager, and the employee themselves
  return ['admin_pusat', 'admin_hrd', 'manager'].includes(userRole);
}
