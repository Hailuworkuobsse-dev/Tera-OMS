import { z } from 'zod';

export const JobRun24hRowSchema = z.object({
  job: z.string(), status: z.string(), count: z.number().int(),
});
export const MonitoringSnapshotSchema = z.object({
  as_of: z.string().datetime(), uptime_seconds: z.number(),
  http_requests_total: z.number().int(), http_5xx_total: z.number().int(),
  http_error_rate_pct: z.number(),
  solve_jobs_by_status: z.record(z.number().int()),
  solve_duration_avg_ms: z.number(), solve_duration_p95_ms: z.number(),
  pending_orders: z.number().int(),
  unreconciled_payments: z.number().int(),
  stale_sync_clients: z.number().int(),
  high_variance_fuel_logs_7d: z.number().int(),
  job_runs_24h: z.array(JobRun24hRowSchema),
});

export type JobRun24hRow = z.infer<typeof JobRun24hRowSchema>;
export type MonitoringSnapshot = z.infer<typeof MonitoringSnapshotSchema>;
