import { useState } from 'react';
import { useI18n, formatETB } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useUnreconciled, useReconcile } from './hooks';
export function ReconciliationTab() {
  const { t } = useI18n(); const q = useUnreconciled(); const reconcile = useReconcile(); const [pending, setPending] = useState<string | null>(null);
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const payments = q.data?.payments ?? [];
  return (
    <div className="flex flex-col gap-4">
      <header className="flex items-center justify-between flex-wrap gap-3">
        <div><h2 className="text-lg font-semibold">{t('finance.recon.title')}</h2><p className="text-sm text-muted">{t('finance.recon.subtitle')}</p></div>
        <p className="text-sm text-muted">{payments.length} {t('finance.recon.pending')}</p>
      </header>
      {reconcile.isError && <div className="text-sm text-danger border border-danger/30 bg-dangerBg rounded px-3 py-2">{(reconcile.error as Error).message}</div>}
      {payments.length === 0 ? <EmptyState title={t('finance.recon.empty')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.distributor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.vehicle')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.method')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.recon.amount')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.captured')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead><tbody>{payments.map((p) => (
            <tr key={p.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3"><div className="font-medium">{p.distributor_name}</div><div className="text-xs text-muted">{p.driver_id}</div></td>
              <td className="px-4 py-3 text-sm">{p.vehicle_id}</td>
              <td className="px-4 py-3"><StatusPill tone={p.method === 'TELEBIRR' ? 'success' : 'neutral'}>{p.method}</StatusPill>{p.telebirr_ref && <div className="text-xs text-muted font-mono mt-1">{p.telebirr_ref}</div>}</td>
              <td className="px-4 py-3 text-right tabular-nums font-medium">{formatETB(p.amount_etb)}</td>
              <td className="px-4 py-3 text-xs text-muted">{new Date(p.captured_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-right"><Button size="sm" loading={reconcile.isPending && pending === p.id} onClick={() => { setPending(p.id); reconcile.mutate({ id: p.id }, { onSettled: () => setPending(null) }); }}>{t('finance.recon.reconcile')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
      <div className="text-xs text-muted rounded-md border border-border bg-surface p-3">{t('finance.recon.hint')}</div>
    </div>
  );
}
