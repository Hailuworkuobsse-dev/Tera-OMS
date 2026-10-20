import type { JobRun, JobRunsResponse, JobScheduleEntry, JobScheduleResponse, JobKey } from '@tera/contracts';
import * as repo from './repository.js';
import { enqueueJob } from './queue.js';
const SCHEDULE: { key: JobKey; labelKey: string; schedule: string }[] = [
  { key: 'metric_snapshot', labelKey: 'jobs.job.metric_snapshot', schedule: '0 22 * * *' },
  { key: 'credit_rebuild', labelKey: 'jobs.job.credit_rebuild', schedule: '15 22 * * *' },
  { key: 'fuel_variance', labelKey: 'jobs.job.fuel_variance', schedule: '30 22 * * *' },
];
export async function listRuns(limit = 50): Promise<JobRunsResponse> {
  const rows = await repo.findRecentRuns(limit);
  return { total: rows.length, runs: rows.map(toRun) };
}
export async function listSchedule(): Promise<JobScheduleResponse> {
  const jobs: JobScheduleEntry[] = [];
  for (const s of SCHEDULE) {
    const last = await repo.findLatestForJob(s.key);
    jobs.push({ job_key: s.key, label_key: s.labelKey, schedule: s.schedule, next_run_at: computeNextRun(s.schedule), last_run: last ? toRun(last) : null });
  }
  return { jobs };
}
export async function runNow(key: JobKey, actorId: string): Promise<void> { await enqueueJob(key, `manual:${actorId}`); }
function toRun(row: any): JobRun {
  return { id: row.id, job_key: row.jobKey, status: row.status, started_at: row.startedAt.toISOString(), finished_at: row.finishedAt?.toISOString() ?? null, duration_ms: row.durationMs, processed_count: row.processedCount, skipped_count: row.skippedCount, triggered_by: row.triggeredBy, error: row.error };
}
function computeNextRun(cronExpr: string): string | null {
  const p = cronExpr.split(' '); if (p.length < 2) return null;
  const m = parseInt(p[0]!, 10); const h = parseInt(p[1]!, 10); if (!Number.isFinite(m) || !Number.isFinite(h)) return null;
  const now = new Date(); const next = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), h, m, 0));
  if (next.getTime() <= now.getTime()) next.setUTCDate(next.getUTCDate() + 1);
  return next.toISOString();
}
