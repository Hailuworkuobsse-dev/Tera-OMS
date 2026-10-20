import { useI18n, formatETB } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useExposure } from './hooks';
import type { AgingBucket, ExposureAccount } from '@tera/contracts';

const BUCKET_TONE: Record<AgingBucket['label'], 'success' | 'warn' | 'danger' | 'neutral'> = { current: 'success', watch: 'warn', overdue: 'danger', critical: 'danger' };

export function CreditDashboardTab() {
  const { t } = useI18n(); const q = useExposure();
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const d = q.data; const maxBucket = Math.max(...d.aging_buckets.map((b) => b.exposure_etb), 1);
  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Stat label={t('finance.credit.total_exposure')} value={formatETB(d.total_exposure_etb)} />
        <Stat label={t('finance.credit.total_limit')} value={formatETB(d.total_limit_etb)} />
        <Stat label={t('finance.credit.utilization')} value={`${d.utilization_pct.toFixed(1)}%`} danger={d.utilization_pct > 80} />
        <Stat label={t('finance.credit.over_limit')} value={String(d.accounts_over_limit)} danger={d.accounts_over_limit > 0} />
      </div>
      <div>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('finance.credit.aging_buckets')}</h2>
        <div className="rounded-lg border border-border bg-surface p-4 flex flex-col gap-3">
          {d.aging_buckets.map((b) => (
            <div key={b.label} className="flex items-center gap-3">
              <div className="w-24 shrink-0"><StatusPill tone={BUCKET_TONE[b.label]}>{t(`finance.credit.bucket.${b.label}`)}</StatusPill></div>
              <div className="text-xs text-muted w-24">{b.days_range}</div>
              <div className="flex-1 bg-bg rounded-full h-3 relative overflow-hidden"><div className={`h-full rounded-full ${b.label === 'current' ? 'bg-success' : b.label === 'watch' ? 'bg-warn' : 'bg-danger'}`} style={{ width: `${(b.exposure_etb / maxBucket) * 100}%` }} /></div>
              <div className="w-32 text-right tabular-nums text-sm font-medium">{formatETB(b.exposure_etb)}</div>
              <div className="w-16 text-right text-xs text-muted">{b.account_count} {t('finance.credit.accounts')}</div>
            </div>
          ))}
        </div>
      </div>
      {d.near_limit_accounts.length > 0 && (
        <div>
          <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('finance.credit.near_limit')} ({d.near_limit_accounts.length})</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">{d.near_limit_accounts.map((a) => <NearLimitCard key={a.distributor_id} account={a} />)}</div>
        </div>
      )}
      <div>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('finance.credit.all_accounts')} ({d.all_accounts.length})</h2>
        {d.all_accounts.length === 0 ? <EmptyState title={t('finance.credit.no_accounts')} /> : (
          <div className="border border-border rounded-md bg-surface overflow-hidden">
            <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('credit.table.distributor')}</th>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('credit.table.region')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.exposure')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.limit')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.utilization')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.days_overdue')}</th>
            </tr></thead><tbody>{d.all_accounts.map((a) => (
              <tr key={a.distributor_id} className="border-b border-border last:border-0">
                <td className="px-4 py-3 font-medium">{a.distributor_name}</td>
                <td className="px-4 py-3 text-muted">{a.region}</td>
                <td className="px-4 py-3 text-right tabular-nums">{formatETB(a.exposure_etb)}</td>
                <td className="px-4 py-3 text-right tabular-nums text-muted">{formatETB(a.limit_etb)}</td>
                <td className={`px-4 py-3 text-right tabular-nums ${a.utilization_pct > 100 ? 'text-danger font-medium' : a.utilization_pct > 80 ? 'text-warn font-medium' : ''}`}>{a.utilization_pct.toFixed(1)}%</td>
                <td className={`px-4 py-3 text-right tabular-nums ${a.days_overdue > 30 ? 'text-danger font-medium' : a.days_overdue > 0 ? 'text-warn font-medium' : 'text-muted'}`}>{a.days_overdue}</td>
              </tr>
            ))}</tbody></table>
          </div>
        )}
      </div>
    </div>
  );
}
function Stat({ label, value, danger }: { label: string; value: string; danger?: boolean }) {
  return <div className="rounded-lg border border-border bg-surface px-4 py-3"><p className="text-xs text-muted uppercase">{label}</p><p className={`text-xl font-bold tabular-nums mt-1 ${danger ? 'text-danger' : ''}`}>{value}</p></div>;
}
function NearLimitCard({ account }: { account: ExposureAccount }) {
  const { t } = useI18n();
  const tone = account.utilization_pct > 100 ? 'text-danger' : 'text-warn'; const bar = account.utilization_pct > 100 ? 'bg-danger' : 'bg-warn';
  return (
    <div className="rounded-lg border border-border bg-surface p-4">
      <div className="flex items-center justify-between mb-2"><span className="font-medium text-sm">{account.distributor_name}</span><span className={`text-sm font-semibold tabular-nums ${tone}`}>{account.utilization_pct.toFixed(0)}%</span></div>
      <div className="text-xs text-muted mb-2">{formatETB(account.exposure_etb)} / {formatETB(account.limit_etb)}</div>
      <div className="w-full bg-bg rounded-full h-2 overflow-hidden"><div className={`h-full ${bar}`} style={{ width: `${Math.min(account.utilization_pct, 100)}%` }} /></div>
      {account.days_overdue > 0 && <p className="text-xs text-danger mt-2">{account.days_overdue} {t('finance.credit.days_overdue_suffix')}</p>}
    </div>
  );
}
