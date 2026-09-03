// ============================================================
// useFormValidation.js - React hook for form validation
// ============================================================
import { useState, useCallback } from 'react';
import { validatePassword, validateNRP, validateNIK, validateEmail, validatePhone, hasSQLInjection, validateForm } from '../validation/security';

/**
 * Hook for form validation using security.js validators
 * @param {object} schema - { fieldName: { type, required, label } }
 * @returns {object} { errors, validateField, validateAll, clearErrors }
 */
export function useFormValidation(schema = {}) {
  const [errors, setErrors] = useState({});

  const validateField = useCallback((name, value) => {
    const config = schema[name];
    if (!config) return null;

    // Required check
    if (config.required && (!value || (typeof value === 'string' && !value.trim()))) {
      const err = config.label ? config.label + ' wajib diisi' : name + ' wajib diisi';
      setErrors(prev => ({ ...prev, [name]: err }));
      return err;
    }

    // SQL injection check
    if (value && typeof value === 'string' && hasSQLInjection(value)) {
      const err = (config.label || name) + ' mengandung karakter tidak valid';
      setErrors(prev => ({ ...prev, [name]: err }));
      return err;
    }

    // Type-specific validation
    let valid = true;
    let errMsg = '';

    switch (config.type) {
      case 'email':
        valid = validateEmail(value);
        errMsg = 'Format email tidak valid';
        break;
      case 'nik':
        valid = validateNIK(value);
        errMsg = 'NIK harus 16 digit angka';
        break;
      case 'nrp':
        valid = validateNRP(value);
        errMsg = 'Format NRP tidak valid (contoh: MNG0001)';
        break;
      case 'phone':
        valid = validatePhone(value);
        errMsg = 'Format telepon tidak valid';
        break;
      case 'password':
        const pwResult = validatePassword(value);
        valid = pwResult.valid;
        errMsg = pwResult.errors.join(', ');
        break;
    }

    if (!valid) {
      setErrors(prev => ({ ...prev, [name]: errMsg }));
      return errMsg;
    }

    // Clear error if valid
    setErrors(prev => {
      const next = { ...prev };
      delete next[name];
      return next;
    });
    return null;
  }, [schema]);

  const validateAll = useCallback((values) => {
    const allErrors = {};
    for (const [name, config] of Object.entries(schema)) {
      const value = values[name];
      if (config.required && (!value || (typeof value === 'string' && !value.trim()))) {
        allErrors[name] = config.label ? config.label + ' wajib diisi' : name + ' wajib diisi';
        continue;
      }
      if (value && typeof value === 'string' && hasSQLInjection(value)) {
        allErrors[name] = (config.label || name) + ' mengandung karakter tidak valid';
        continue;
      }
      switch (config.type) {
        case 'email': if (value && !validateEmail(value)) allErrors[name] = 'Format email tidak valid'; break;
        case 'nik': if (value && !validateNIK(value)) allErrors[name] = 'NIK harus 16 digit angka'; break;
        case 'nrp': if (value && !validateNRP(value)) allErrors[name] = 'Format NRP tidak valid'; break;
        case 'phone': if (value && !validatePhone(value)) allErrors[name] = 'Format telepon tidak valid'; break;
        case 'password':
          if (value) {
            const pw = validatePassword(value);
            if (!pw.valid) allErrors[name] = pw.errors.join(', ');
          }
          break;
      }
    }
    setErrors(allErrors);
    return { valid: Object.keys(allErrors).length === 0, errors: allErrors };
  }, [schema]);

  const clearErrors = useCallback(() => setErrors({}), []);

  return { errors, validateField, validateAll, clearErrors };
}
