import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useSnapshot } from './hooks';
export function MonitoringPage() {
  const { t } = useI18n(); const q = useSnapshot();
  if (q.isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">{t('common.error')}</div></div>;
  const s = q.data; const tone = s.http_error_rate_pct > 5 ? 'danger' : s.http_error_rate_pct > 1 ? 'warn' : 'success';
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6 flex items-start justify-between flex-wrap gap-4">
        <div><h1 className="text-2xl font-bold">{t('monitoring.title')}</h1><p className="text-sm text-muted mt-1">{t('monitoring.subtitle')}</p>
          <p className="text-xs text-muted mt-1">{t('monitoring.as_of')}: {new Date(s.as_of).toLocaleTimeString()} · {t('monitoring.uptime')}: {s.uptime_seconds}s</p></div>
        <a href="/metrics" target="_blank" rel="noopener noreferrer" className="text-sm text-primary hover:underline">{t('monitoring.open_prometheus')} ↗</a>
      </header>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <Stat label={t('monitoring.requests_total')} value={s.http_requests_total.toLocaleString()} />
        <Stat label={t('monitoring.requests_5xx')} value={s.http_5xx_total.toLocaleString()} tone={s.http_5xx_total > 0 ? 'danger' : undefined} />
        <Stat label={t('monitoring.error_rate')} value={`${s.http_error_rate_pct.toFixed(2)}%`} pillTone={tone} />
        <Stat label={t('monitoring.uptime')} value={`${s.uptime_seconds}s`} />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <Stat label={t('monitoring.pending_orders')} value={String(s.pending_orders)} />
        <Stat label={t('monitoring.unreconciled')} value={String(s.unreconciled_payments)} />
        <Stat label={t('monitoring.stale_clients')} value={String(s.stale_sync_clients)} tone={s.stale_sync_clients > 3 ? 'warn' : undefined} />
        <Stat label={t('monitoring.high_variance_fuel')} value={String(s.high_variance_fuel_logs_7d)} />
      </div>
      <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('monitoring.jobs_24h')}</h2>
      {s.job_runs_24h.length === 0 ? <EmptyState title={t('monitoring.no_jobs_24h')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('monitoring.job')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-2 font-medium text-muted">{t('monitoring.runs')}</th>
          </tr></thead><tbody>{s.job_runs_24h.map((r, i) => (
            <tr key={`${r.job}-${r.status}-${i}`} className="border-b border-border last:border-0">
              <td className="px-4 py-2 font-mono text-xs">{r.job}</td>
              <td className="px-4 py-2"><StatusPill tone={r.status === 'DONE' ? 'success' : r.status === 'FAILED' ? 'danger' : 'warn'}>{r.status}</StatusPill></td>
              <td className="px-4 py-2 text-right tabular-nums">{r.count}</td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
function Stat({ label, value, tone, pillTone }: { label: string; value: string; tone?: 'danger' | 'warn'; pillTone?: 'success' | 'warn' | 'danger' }) {
  return <div className="border border-border rounded-md bg-surface px-4 py-3">
    <p className="text-xs text-muted uppercase tracking-wide">{label}</p>
    <div className="flex items-center gap-2 mt-1"><p className={`text-xl font-bold tabular-nums ${tone === 'danger' ? 'text-danger' : tone === 'warn' ? 'text-warn' : ''}`}>{value}</p>
      {pillTone && <StatusPill tone={pillTone}>{pillTone === 'success' ? 'OK' : pillTone === 'warn' ? 'watch' : 'high'}</StatusPill>}</div>
  </div>;
}
