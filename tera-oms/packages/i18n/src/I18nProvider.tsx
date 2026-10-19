import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import type { Locale, TranslateFn } from './types';
import AM from './locales/am.json';
import EN from './locales/en.json';
import OM from './locales/om.json';

const LOCALES: Record<Locale, Record<string, string>> = { am: AM, en: EN, om: OM };
const FALLBACK: Locale = 'en';

interface Ctx { locale: Locale; setLocale: (l: Locale) => void; t: TranslateFn; }
const I18nContext = createContext<Ctx | null>(null);

export function I18nProvider({ children, initialLocale = 'am' }: { children: ReactNode; initialLocale?: Locale }) {
  const [locale, setLocale] = useState<Locale>(initialLocale);
  const value = useMemo<Ctx>(() => {
    const t: TranslateFn = (key, vars) => {
      let s = LOCALES[locale][key] ?? LOCALES[FALLBACK][key] ?? key;
      if (vars) for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, String(v));
      return s;
    };
    return { locale, setLocale, t };
  }, [locale]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): Ctx {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n must be used inside <I18nProvider>');
  return ctx;
}
