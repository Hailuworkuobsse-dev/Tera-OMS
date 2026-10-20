export interface HistogramState { counts: number[]; sum: number; count: number; }
export const emptyHistogram = (buckets: number[]): HistogramState => ({ counts: new Array(buckets.length).fill(0), sum: 0, count: 0 });
export function observeHistogram(s: HistogramState, buckets: number[], v: number): void {
  s.sum += v; s.count += 1;
  for (let i = 0; i < buckets.length; i++) if (v <= buckets[i]!) s.counts[i]! += 1;
}
export function computeQuantileFromValues(values: number[], q: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))]!;
}
