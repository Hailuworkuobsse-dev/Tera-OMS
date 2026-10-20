import { haversineKm, pointInPolygon, hourInWindow } from './geo.js';
import { nearestNeighbor, twoOpt, naiveSequence } from './algorithms.js';
import type { SolveOrder, SolveVehicle, SolveConstraints, SolveResult, SolveSequence, Infeasible, SolveStop } from './types.js';
const DEFAULT_SPEED_KMH = 25;
const DEFAULT_SERVICE_MIN = 10;
interface SequenceInput { orders: SolveOrder[]; vehicle: SolveVehicle; constraints: SolveConstraints; }
function sequenceToResult(input: SequenceInput, order: SolveOrder[]): { result: SolveSequence; infeasible: Infeasible | null } {
  const { vehicle, constraints } = input;
  const speed = constraints.avg_speed_kmh ?? DEFAULT_SPEED_KMH;
  const service = constraints.service_min_per_stop ?? DEFAULT_SERVICE_MIN;
  const stops: SolveStop[] = [];
  let totalKm = 0;
  let clock = new Date();
  clock.setHours(vehicle.shift_start_h, 0, 0, 0);
  let prev: { lat: number; lng: number } = vehicle;
  for (let i = 0; i < order.length; i++) {
    const o = order[i]!;
    const km = haversineKm(prev, o);
    totalKm += km;
    const legMin = (km / speed) * 60;
    clock = new Date(clock.getTime() + legMin * 60_000);
    const eta = new Date(clock);
    const twStart = new Date(o.time_window_start);
    const twEnd = new Date(o.time_window_end);
    if (eta < twStart || eta > twEnd) {
      return { result: { stops: [], total_km: 0, total_min: 0 }, infeasible: { order_id: o.id, reason: `ETA ${eta.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })} outside window` } };
    }
    for (const zone of constraints.curfew_zones) {
      if (pointInPolygon(o, zone.polygon) && hourInWindow(eta.getHours(), zone.start_hour, zone.end_hour)) {
        return { result: { stops: [], total_km: 0, total_min: 0 }, infeasible: { order_id: o.id, reason: `curfew "${zone.name}"` } };
      }
    }
    stops.push({ order_id: o.id, distributor_name: o.distributor_name, seq: i + 1, eta: eta.toISOString(), lat: o.lat, lng: o.lng });
    prev = o;
    clock = new Date(clock.getTime() + service * 60_000);
  }
  return { result: { stops, total_km: round(totalKm), total_min: Math.round((totalKm / speed) * 60) }, infeasible: null };
}
export function solve(orders: SolveOrder[], vehicle: SolveVehicle, constraints: SolveConstraints): SolveResult {
  if (orders.length === 0) {
    const empty: SolveSequence = { stops: [], total_km: 0, total_min: 0 };
    return { manual: empty, optimized: empty, savings_km_pct: 0, savings_time_pct: 0, infeasible: null };
  }
  const input: SequenceInput = { orders, vehicle, constraints };
  const manualSeq = sequenceToResult(input, naiveSequence(orders));
  const nn = nearestNeighbor(orders, vehicle);
  const improved = twoOpt(orders, nn);
  const optimizedSeq = sequenceToResult(input, improved.map((i) => orders[i]!));
  const infeasible = optimizedSeq.infeasible ?? manualSeq.infeasible;
  const manualKm = manualSeq.result.total_km;
  const optKm = optimizedSeq.result.total_km;
  const manualMin = manualSeq.result.total_min;
  const optMin = optimizedSeq.result.total_min;
  return {
    manual: manualSeq.result, optimized: optimizedSeq.result,
    savings_km_pct: manualKm > 0 ? round(((manualKm - optKm) / manualKm) * 100) : 0,
    savings_time_pct: manualMin > 0 ? round(((manualMin - optMin) / manualMin) * 100) : 0,
    infeasible,
  };
}
function round(n: number): number { return Math.round(n * 100) / 100; }
