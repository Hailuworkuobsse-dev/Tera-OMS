import { haversineKm } from './geo.js';
import type { Point, SolveOrder } from './types.js';
export function naiveSequence(orders: SolveOrder[]): SolveOrder[] {
  return [...orders].sort((a, b) => a.time_window_start.localeCompare(b.time_window_start));
}
export function nearestNeighbor(orders: SolveOrder[], depot: Point): number[] {
  const remaining = new Set(orders.map((_, i) => i));
  const sequence: number[] = [];
  let current: Point = depot;
  while (remaining.size > 0) {
    let bestIdx = -1; let bestDist = Infinity;
    for (const i of remaining) {
      const d = haversineKm(current, orders[i]!);
      if (d < bestDist) { bestDist = d; bestIdx = i; }
    }
    remaining.delete(bestIdx);
    sequence.push(bestIdx);
    current = orders[bestIdx]!;
  }
  return sequence;
}
export function twoOpt(points: SolveOrder[], order: number[], maxIterations = 200): number[] {
  let best = [...order];
  let improved = true;
  let iter = 0;
  while (improved && iter < maxIterations) {
    improved = false;
    for (let i = 0; i < best.length - 1; i++) {
      for (let j = i + 2; j < best.length; j++) {
        const a = i > 0 ? points[best[i - 1]!]! : null;
        const b = points[best[i]!]!;
        const c = points[best[j]!]!;
        const d = j < best.length - 1 ? points[best[j + 1]!]! : null;
        const before = (a ? haversineKm(a, b) : 0) + (d ? haversineKm(c, d) : 0);
        const after = (a ? haversineKm(a, c) : 0) + (d ? haversineKm(b, d) : 0);
        if (after + 1e-9 < before) {
          best = [...best.slice(0, i), ...best.slice(i, j + 1).reverse(), ...best.slice(j + 1)];
          improved = true;
        }
      }
    }
    iter++;
  }
  return best;
}
