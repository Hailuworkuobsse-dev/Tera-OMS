import { useI18n } from '@tera/i18n';
import type { CreditFilter } from '../types';

const FILTERS: { id: CreditFilter; key: string }[] = [
  { id: 'ALL', key: 'credit.filter.all' },
  { id: 'OVERDUE_30', key: 'credit.filter.overdue_30' },
  { id: 'OVER_LIMIT', key: 'credit.filter.over_limit' },
];
export function FilterTabs({ value, onChange }: { value: CreditFilter; onChange: (f: CreditFilter) => void }) {
  const { t } = useI18n();
  return (
    <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
      {FILTERS.map((f) => (
        <button key={f.id} onClick={() => onChange(f.id)}
          className={`px-3 py-1.5 text-sm rounded ${value === f.id ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>
          {t(f.key)}
        </button>
      ))}
    </div>
  );
}
