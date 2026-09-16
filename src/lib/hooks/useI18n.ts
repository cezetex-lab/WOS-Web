// ============================================================
// useI18n.ts - React hook for internationalization
// ============================================================
import { useState, useCallback } from 'react';
import { t as translate, setLang, getLang } from '../i18n';

export function useI18n() {
  const [lang, setLangState] = useState(() => getLang());

  const t = useCallback((key: string) => translate(key), []);

  const changeLanguage = useCallback((newLang: string) => {
    setLang(newLang);
    setLangState(newLang);
  }, []);

  return { t, lang, changeLanguage };
}
