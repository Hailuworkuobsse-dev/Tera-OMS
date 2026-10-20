import { emptyHistogram, observeHistogram, type HistogramState } from './histogram.js';
export const HTTP_BUCKETS = [0.01, 0.05, 0.1, 0.5, 1, 5];
export const httpCounters = new Map<string, number>();
export const httpHistograms = new Map<string, HistogramState>();
export function recordHttpRequest(method: string, route: string, status: string, dur: number): void {
  const key = `${method}|${route}|${status}`;
  httpCounters.set(key, (httpCounters.get(key) ?? 0) + 1);
  let h = httpHistograms.get(route);
  if (!h) { h = emptyHistogram(HTTP_BUCKETS); httpHistograms.set(route, h); }
  observeHistogram(h, HTTP_BUCKETS, dur);
}
export function httpTotals() { let t = 0, s5 = 0; for (const [k, v] of httpCounters) { t += v; if ((k.split('|')[2] ?? '').startsWith('5')) s5 += v; } return { total: t, s5xx: s5 }; }
export function _reset() { httpCounters.clear(); httpHistograms.clear(); }
