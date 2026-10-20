import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useOverrides } from './hooks';
type Filter = 'all' | 'active' | 'expired';
export function OverridesTab() {
  const { t } = useI18n(); const [filter, setFilter] = useState<Filter>('active'); const q = useOverrides();
  const rows = useMemo(() => { const all = q.data?.overrides ?? []; if (filter === 'active') return all.filter((r) => !r.expired); if (filter === 'expired') return all.filter((r) => r.expired); return all; }, [q.data, filter]);
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <p className="text-sm text-muted">{q.data?.total ?? 0} {t('finance.overrides.total')}</p>
        <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
          {(['active', 'expired', 'all'] as const).map((f) => <button key={f} onClick={() => setFilter(f)} className={`px-3 py-1.5 text-sm rounded ${filter === f ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>{t(`finance.overrides.filter.${f}`)}</button>)}
        </div>
      </div>
      {rows.length === 0 ? <EmptyState title={t('finance.overrides.empty')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('credit.table.distributor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.reason')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.actor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.created')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.expires')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
          </tr></thead><tbody>{rows.map((o) => (
            <tr key={o.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-medium">{o.distributor_name}</td>
              <td className="px-4 py-3 text-muted italic max-w-xs truncate">"{o.reason}"</td>
              <td className="px-4 py-3 text-xs text-muted font-mono">{o.actor_id}</td>
              <td className="px-4 py-3 text-xs text-muted">{new Date(o.created_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-xs text-muted">{new Date(o.expires_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-right"><StatusPill tone={o.expired ? 'neutral' : 'success'}>{o.expired ? t('finance.overrides.status.expired') : t('finance.overrides.status.active')}</StatusPill></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
