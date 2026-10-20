import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useAuditLog } from './hooks';
const ENTITIES = ['', 'route', 'dock_slot', 'payment', 'credit_override', 'notification'];
export function AuditPage() {
  const { t } = useI18n();
  const [entity, setEntity] = useState(''); const [actor, setActor] = useState('');
  const q = useAuditLog({ entity: entity || undefined, actor: actor || undefined });
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('audit.title')}</h1><p className="text-sm text-muted mt-1">{t('audit.subtitle')}</p></header>
      <div className="flex flex-wrap items-end gap-3 mb-4">
        <label className="text-sm"><span className="text-muted block mb-1">{t('audit.filter.entity')}</span>
          <select value={entity} onChange={(e) => setEntity(e.target.value)} className="rounded-md border border-border bg-surface px-3 py-2 min-w-[160px]">
            {ENTITIES.map((e) => <option key={e} value={e}>{e || t('audit.filter.entity_all')}</option>)}
          </select>
        </label>
        <label className="text-sm"><span className="text-muted block mb-1">{t('audit.filter.actor')}</span>
          <input value={actor} onChange={(e) => setActor(e.target.value)} className="rounded-md border border-border bg-surface px-3 py-2 min-w-[180px]" /></label>
        <button onClick={() => q.refetch()} className="ml-auto text-sm px-3 py-2 rounded-md border border-border bg-surface hover:bg-bg">{t('common.retry')}</button>
      </div>
      {q.isLoading && <Spinner label={t('common.loading')} />}
      {q.data && q.data.entries.length === 0 && <EmptyState title={t('audit.empty')} hint={t('audit.empty_hint')} />}
      {q.data && q.data.entries.length > 0 && (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.when')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.actor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.action')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.entity')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.reason')}</th>
          </tr></thead><tbody>{q.data.entries.map((e) => (
            <tr key={e.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 text-xs text-muted whitespace-nowrap">{new Date(e.created_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-xs font-mono">{e.actor_id}</td>
              <td className="px-4 py-3"><StatusPill tone={e.action === 'dispatched' || e.action === 'reconciled' ? 'success' : e.action === 'create' ? 'warn' : 'neutral'}>{e.action}</StatusPill></td>
              <td className="px-4 py-3 text-xs"><div className="font-medium">{e.entity}</div><div className="text-muted font-mono">{e.entity_id}</div></td>
              <td className="px-4 py-3 text-sm max-w-md">{e.reason}</td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
