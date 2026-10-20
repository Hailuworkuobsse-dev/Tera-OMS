import { httpCounters, httpHistograms, httpTotals, HTTP_BUCKETS } from './metrics-state.js';
import { renderPrometheus, renderHistogram, type Metric, type HistSeries } from './prometheus-format.js';
import { buildDbGauges } from './db-gauges.js';
import * as repo from './repository.js';
const START = Date.now();
export async function getMetricsText(): Promise<string> {
  const metrics: Metric[] = [];
  const c: { labels: Record<string, string>; value: number }[] = [];
  for (const [k, v] of httpCounters) { const [m, r, s] = k.split('|'); c.push({ labels: { method: m!, route: r!, status: s! }, value: v }); }
  metrics.push({ name: 'tera_http_requests_total', help: 'Total HTTP requests', type: 'counter', samples: c });
  metrics.push(...buildDbGauges({
    solveJobs: await repo.loadSolveJobsByStatus(),
    solveDurationsMs: await repo.loadRecentDurations(),
    pendingOrders: await repo.countPending(),
    unreconciledPayments: await repo.countUnreconciled(),
    staleSyncClients: await repo.countStaleClients(1),
    highVarianceFuelLogs7d: await repo.countHighVarFuel(7),
    jobRuns24h: await repo.loadJobRuns24h(),
  }));
  const mem = process.memoryUsage();
  metrics.push({ name: 'tera_process_uptime_seconds', help: 'Uptime', type: 'gauge', samples: [{ labels: {}, value: Math.round((Date.now() - START) / 1000) }] });
  metrics.push({ name: 'tera_process_memory_bytes', help: 'Memory', type: 'gauge', samples: [
    { labels: { type: 'rss' }, value: mem.rss }, { labels: { type: 'heap_used' }, value: mem.heapUsed }, { labels: { type: 'heap_total' }, value: mem.heapTotal },
  ]});
  let out = renderPrometheus(metrics);
  const hs: HistSeries[] = [];
  for (const [route, s] of httpHistograms) if (s.count > 0) hs.push({ labels: { route }, bounds: HTTP_BUCKETS, cumulative: s.counts, total: s.count, sum: s.sum });
  if (hs.length > 0) out += renderHistogram('tera_http_request_duration_seconds', 'HTTP duration', hs);
  return out;
}
export function getUptimeSeconds() { return Math.round((Date.now() - START) / 1000); }
export function getHttpTotals() { return httpTotals(); }
