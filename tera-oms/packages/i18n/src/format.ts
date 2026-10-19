import type { Locale } from './types';

const INTL_LOCALE: Record<Locale, string> = { am: 'am-ET', en: 'en-ET', om: 'om-ET' };

export function formatETB(amount: number, locale: Locale = 'am'): string {
  return new Intl.NumberFormat(INTL_LOCALE[locale], {
    style: 'currency', currency: 'ETB',
    maximumFractionDigits: 0, currencyDisplay: 'code',
  }).format(amount);
}
export function formatNumber(n: number, locale: Locale = 'am'): string {
  return new Intl.NumberFormat(INTL_LOCALE[locale]).format(n);
}
export function formatDate(d: Date | string, locale: Locale = 'am'): string {
  const date = typeof d === 'string' ? new Date(d) : d;
  return new Intl.DateTimeFormat(INTL_LOCALE[locale], {
    year: 'numeric', month: 'short', day: 'numeric', timeZone: 'Africa/Addis_Ababa',
  }).format(date);
}
export function formatTime(d: Date | string, locale: Locale = 'am'): string {
  const date = typeof d === 'string' ? new Date(d) : d;
  return new Intl.DateTimeFormat(INTL_LOCALE[locale], {
    hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Addis_Ababa',
  }).format(date);
}
