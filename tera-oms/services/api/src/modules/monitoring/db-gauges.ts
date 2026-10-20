import { computeQuantileFromValues } from './histogram.js';
import type { Metric } from './prometheus-format.js';
export interface Input {
  solveJobs: { status: string; count: number }[];
  solveDurationsMs: number[];
  pendingOrders: number; unreconciledPayments: number;
  staleSyncClients: number; highVarianceFuelLogs7d: number;
  jobRuns24h: { jobKey: string; status: string; count: number }[];
}
export function buildDbGauges(i: Input): Metric[] {
  const out: Metric[] = [];
  out.push({ name: 'tera_solve_jobs', help: 'Current solve jobs by status', type: 'gauge', samples: i.solveJobs.map((r) => ({ labels: { status: r.status }, value: r.count })) });
  if (i.solveDurationsMs.length > 0) {
    const avg = i.solveDurationsMs.reduce((s, x) => s + x, 0) / i.solveDurationsMs.length;
    const p95 = computeQuantileFromValues(i.solveDurationsMs, 0.95);
    out.push({ name: 'tera_solve_job_duration_seconds', help: 'Solve job duration', type: 'gauge', samples: [
      { labels: { quantile: 'avg' }, value: Math.round(avg / 10) / 100 },
      { labels: { quantile: 'p95' }, value: Math.round(p95 / 10) / 100 },
    ]});
  }
  out.push({ name: 'tera_pending_orders', help: 'Orders PENDING', type: 'gauge', samples: [{ labels: {}, value: i.pendingOrders }] });
  out.push({ name: 'tera_unreconciled_payments', help: 'Payments awaiting reconcile', type: 'gauge', samples: [{ labels: {}, value: i.unreconciledPayments }] });
  out.push({ name: 'tera_stale_sync_clients', help: 'Sync clients stale > 1h', type: 'gauge', samples: [{ labels: {}, value: i.staleSyncClients }] });
  out.push({ name: 'tera_high_variance_fuel_logs_7d', help: 'High-variance fuel last 7d', type: 'gauge', samples: [{ labels: {}, value: i.highVarianceFuelLogs7d }] });
  out.push({ name: 'tera_job_runs_24h', help: 'Job runs last 24h', type: 'gauge', samples: i.jobRuns24h.map((r) => ({ labels: { job: r.jobKey, status: r.status }, value: r.count })) });
  return out;
}
