import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useNotifications, useSendTest } from './hooks';
import type { NotificationChannel } from './types';
const CHANNELS: { id: NotificationChannel; label: string }[] = [{ id: 'sms', label: 'SMS' }, { id: 'telegram', label: 'Telegram' }, { id: 'email', label: 'Email' }];
export function NotificationsPage() {
  const { t } = useI18n();
  const [filter, setFilter] = useState(''); const [tc, setTc] = useState<NotificationChannel>('sms'); const [tr, setTr] = useState('+251911000001');
  const q = useNotifications({ channel: filter || undefined }); const testMut = useSendTest();
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('notify.title')}</h1><p className="text-sm text-muted mt-1">{t('notify.subtitle')}</p></header>
      <div className="rounded-lg border border-primary/30 bg-primary/5 p-4 mb-6">
        <p className="text-sm font-medium mb-3">{t('notify.test.title')}</p>
        <div className="flex flex-wrap items-end gap-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('notify.test.channel')}</span>
            <select value={tc} onChange={(e) => setTc(e.target.value as NotificationChannel)} className="rounded-md border border-border bg-surface px-3 py-2">
              {CHANNELS.map((c) => <option key={c.id} value={c.id}>{c.label}</option>)}
            </select></label>
          <label className="text-sm flex-1 min-w-[200px]"><span className="text-muted block mb-1">{t('notify.test.recipient')}</span>
            <input value={tr} onChange={(e) => setTr(e.target.value)} className="w-full rounded-md border border-border bg-surface px-3 py-2" /></label>
          <Button onClick={() => testMut.mutate({ channel: tc, recipient: tr.trim() })} loading={testMut.isPending}>{t('notify.test.send')}</Button>
        </div>
        {testMut.data && <p className="text-sm text-success mt-2">✓ {t('notify.test.success', { status: testMut.data.status, ref: testMut.data.provider_ref ?? '—' })}</p>}
      </div>
      <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
        <p className="text-sm text-muted">{q.data?.total ?? 0} {t('notify.log.total')}</p>
        <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
          <button onClick={() => setFilter('')} className={`px-3 py-1.5 text-sm rounded ${filter === '' ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>{t('notify.log.all')}</button>
          {CHANNELS.map((c) => <button key={c.id} onClick={() => setFilter(c.id)} className={`px-3 py-1.5 text-sm rounded ${filter === c.id ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>{c.label}</button>)}
        </div>
      </div>
      {q.isLoading && <Spinner label={t('common.loading')} />}
      {q.data && q.data.entries.length === 0 && <EmptyState title={t('notify.log.empty')} />}
      {q.data && q.data.entries.length > 0 && (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.when')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.channel')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.recipient')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.body')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
          </tr></thead><tbody>{q.data.entries.map((e) => (
            <tr key={e.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 text-xs text-muted whitespace-nowrap">{new Date(e.sent_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-xs font-medium uppercase">{e.channel}</td>
              <td className="px-4 py-3 text-xs font-mono">{e.recipient}</td>
              <td className="px-4 py-3 text-sm max-w-md"><div className="text-xs text-muted">{e.template_key}</div><div>{e.rendered_body}</div></td>
              <td className="px-4 py-3 text-right"><StatusPill tone={e.status === 'SENT' ? 'success' : e.status === 'STUB' ? 'warn' : 'danger'}>{e.status}</StatusPill></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
