import type { MonitoringSnapshot } from '@tera/contracts';
import { computeQuantileFromValues } from './histogram.js';
import { httpTotals } from './metrics-state.js';
import { getUptimeSeconds } from './service.js';
import * as repo from './repository.js';
export async function getSnapshot(): Promise<MonitoringSnapshot> {
  const [solveJobs, durations, pending, unrecon, stale, highFuel, jobRuns] = await Promise.all([
    repo.loadSolveJobsByStatus(), repo.loadRecentDurations(), repo.countPending(),
    repo.countUnreconciled(), repo.countStaleClients(1), repo.countHighVarFuel(7), repo.loadJobRuns24h(),
  ]);
  const { total, s5xx } = httpTotals();
  const byStatus: Record<string, number> = {}; for (const s of solveJobs) byStatus[s.status] = s.count;
  const avg = durations.length > 0 ? durations.reduce((s, x) => s + x, 0) / durations.length : 0;
  const p95 = computeQuantileFromValues(durations, 0.95);
  return {
    as_of: new Date().toISOString(), uptime_seconds: getUptimeSeconds(),
    http_requests_total: total, http_5xx_total: s5xx, http_error_rate_pct: total > 0 ? Math.round((s5xx / total) * 10000) / 100 : 0,
    solve_jobs_by_status: byStatus, solve_duration_avg_ms: Math.round(avg), solve_duration_p95_ms: Math.round(p95),
    pending_orders: pending, unreconciled_payments: unrecon, stale_sync_clients: stale, high_variance_fuel_logs_7d: highFuel,
    job_runs_24h: jobRuns.map((r) => ({ job: r.jobKey, status: r.status, count: r.count })),
  };
}
