import { useI18n, formatETB } from '@tera/i18n';
export function Money({ value, bold = false }: { value: number; bold?: boolean }) {
  const { locale } = useI18n();
  return <span className={`tabular-nums ${bold ? 'font-semibold' : ''}`}>{formatETB(value, locale)}</span>;
}
