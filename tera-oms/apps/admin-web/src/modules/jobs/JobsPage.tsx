import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useRuns, useSchedule, useRunJob } from './hooks';
import type { JobKey, JobStatus } from './types';
function tone(s: JobStatus): 'success' | 'warn' | 'danger' | 'neutral' { if (s === 'DONE') return 'success'; if (s === 'RUNNING') return 'warn'; if (s === 'FAILED') return 'danger'; return 'neutral'; }
export function JobsPage() {
  const { t } = useI18n();
  const scheduleQ = useSchedule(); const runsQ = useRuns(); const runMut = useRunJob();
  const [pending, setPending] = useState<JobKey | null>(null);
  const run = (k: JobKey) => { setPending(k); runMut.mutate(k, { onSettled: () => setPending(null) }); };
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('jobs.title')}</h1><p className="text-sm text-muted mt-1">{t('jobs.subtitle')}</p></header>
      {scheduleQ.isLoading && <Spinner label={t('common.loading')} />}
      {scheduleQ.data && scheduleQ.data.jobs.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-6">
          {scheduleQ.data.jobs.map((s) => (
            <div key={s.job_key} className="border border-border rounded-md bg-surface p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">{t(s.label_key)}</span>
                {s.last_run ? <StatusPill tone={tone(s.last_run.status)}>{s.last_run.status}</StatusPill> : <StatusPill tone="neutral">{t('jobs.never_run')}</StatusPill>}
              </div>
              <div className="text-xs text-muted font-mono">{s.schedule}</div>
              <div className="text-xs text-muted">{t('jobs.next_run')}: {s.next_run_at ? new Date(s.next_run_at).toLocaleString() : '—'}</div>
              {s.last_run && <div className="text-xs text-muted">{s.last_run.processed_count} ✓{s.last_run.skipped_count > 0 && `, ${s.last_run.skipped_count} skipped`}{s.last_run.duration_ms !== null && ` · ${s.last_run.duration_ms}ms`}</div>}
              <Button size="sm" variant="secondary" onClick={() => run(s.job_key)} loading={pending === s.job_key}>{t('jobs.run_now')}</Button>
            </div>
          ))}
        </div>
      )}
      <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('jobs.history')}</h2>
      {runsQ.isLoading && <Spinner label={t('common.loading')} />}
      {runsQ.data && runsQ.data.runs.length === 0 && <EmptyState title={t('jobs.history.empty')} />}
      {runsQ.data && runsQ.data.runs.length > 0 && (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('jobs.table.when')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('jobs.table.job')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-2 font-medium text-muted">{t('jobs.table.processed')}</th>
            <th className="text-right px-4 py-2 font-medium text-muted">{t('jobs.table.duration')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('jobs.table.triggered_by')}</th>
          </tr></thead><tbody>{runsQ.data.runs.map((r) => (
            <tr key={r.id} className="border-b border-border last:border-0">
              <td className="px-4 py-2 text-xs text-muted whitespace-nowrap">{new Date(r.started_at).toLocaleString()}</td>
              <td className="px-4 py-2 font-mono text-xs">{r.job_key}</td>
              <td className="px-4 py-2"><StatusPill tone={tone(r.status)}>{r.status}</StatusPill></td>
              <td className="px-4 py-2 text-right tabular-nums">{r.processed_count}{r.skipped_count > 0 && <span className="text-xs text-muted"> (+{r.skipped_count})</span>}</td>
              <td className="px-4 py-2 text-right tabular-nums text-muted text-xs">{r.duration_ms !== null ? `${r.duration_ms}ms` : '—'}</td>
              <td className="px-4 py-2 text-xs text-muted font-mono">{r.triggered_by}</td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
