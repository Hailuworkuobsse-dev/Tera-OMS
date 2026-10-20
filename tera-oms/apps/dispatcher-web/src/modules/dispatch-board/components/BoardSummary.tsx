import { useI18n } from '@tera/i18n';
import type { BoardResponse } from '../types';
export function BoardSummary({ summary }: { summary: BoardResponse['summary'] }) {
  const { t } = useI18n();
  const stat = (label: string, value: number, tone?: 'warn' | 'danger') => (
    <div className="flex-1 min-w-[110px] border border-border rounded-md px-3 py-2 bg-surface">
      <div className="text-xs text-muted">{label}</div>
      <div className={`text-xl font-semibold tabular-nums ${tone === 'danger' ? 'text-danger' : tone === 'warn' ? 'text-warn' : ''}`}>{value}</div>
    </div>
  );
  return (
    <div className="flex flex-wrap gap-2">
      {stat(t('dispatch.summary.routes_planned'), summary.routes_planned)}
      {stat(t('dispatch.summary.routes_dispatched'), summary.routes_dispatched)}
      {stat(t('dispatch.summary.slots_available'), summary.slots_available)}
      {stat(t('dispatch.summary.slots_allocated'), summary.slots_allocated, summary.slots_allocated > 0 ? 'warn' : undefined)}
      {stat(t('dispatch.summary.unallocated_routes'), summary.unallocated_routes, summary.unallocated_routes > 0 ? 'danger' : undefined)}
    </div>
  );
}
