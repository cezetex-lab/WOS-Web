// ============================================================
// useI18n.js - React hook for internationalization
// ============================================================
import { useState, useCallback } from 'react';
import { t as translate, setLanguage, getLanguage } from '../../i18n';

export function useI18n() {
  const [lang, setLang] = useState(() => getLanguage());

  const t = useCallback((key) => translate(key), [lang]);

  const changeLanguage = useCallback((newLang) => {
    setLanguage(newLang);
    setLang(newLang);
  }, []);

  return { t, lang, changeLanguage };
}
