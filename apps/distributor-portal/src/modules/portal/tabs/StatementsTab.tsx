import { useI18n, formatETB } from '@tera/i18n';
import { EmptyState, Spinner } from '@tera/ui';
import { useStatements } from '../hooks';
export function StatementsTab() {
  const { t } = useI18n(); const q = useStatements();
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const s = q.data; const pct = s.limit_etb > 0 ? (s.balance_etb / s.limit_etb) * 100 : 0;
  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Stat label={t('portal.statements.balance')} value={formatETB(s.balance_etb)} />
        <Stat label={t('portal.statements.limit')} value={formatETB(s.limit_etb)} />
        <Stat label={t('portal.statements.utilization')} value={`${pct.toFixed(0)}%`} danger={pct > 80} />
        <Stat label={t('portal.statements.oldest_unpaid')} value={s.days_since_oldest_unpaid !== null ? `${s.days_since_oldest_unpaid}d` : '—'} danger={s.days_since_oldest_unpaid !== null && s.days_since_oldest_unpaid > s.grace_days} />
      </div>
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.statements.recent_deliveries')}</h2>
        {s.recent_deliveries.length === 0 ? <EmptyState title={t('portal.statements.no_deliveries')} /> : (
          <div className="border border-border rounded-md bg-surface overflow-hidden">
            <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
              <th className="text-left px-4 py-2 font-medium text-muted">{t('portal.statements.date')}</th>
              <th className="text-left px-4 py-2 font-medium text-muted">{t('portal.statements.order')}</th>
              <th className="text-left px-4 py-2 font-medium text-muted">{t('portal.statements.vehicle')}</th>
              <th className="text-right px-4 py-2 font-medium text-muted">{t('portal.statements.qty')}</th>
            </tr></thead><tbody>{s.recent_deliveries.map((d) => (
              <tr key={d.order_id} className="border-b border-border last:border-0">
                <td className="px-4 py-2 text-muted text-xs">{new Date(d.delivered_at).toLocaleString()}</td>
                <td className="px-4 py-2 text-xs font-mono">{d.order_id}</td>
                <td className="px-4 py-2">{d.vehicle_id}</td>
                <td className="px-4 py-2 text-right tabular-nums">{d.total_quantity}</td>
              </tr>
            ))}</tbody></table>
          </div>
        )}</section>
    </div>
  );
}
function Stat({ label, value, danger }: { label: string; value: string; danger?: boolean }) {
  return <div className="rounded-lg border border-border bg-surface px-4 py-3"><p className="text-xs text-muted uppercase">{label}</p><p className={`text-xl font-bold tabular-nums mt-1 ${danger ? 'text-danger' : ''}`}>{value}</p></div>;
}
