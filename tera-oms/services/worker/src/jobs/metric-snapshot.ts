import * as repo from './repository.js';
import { computeVariableCostEtb, computeKmPerDelivery, computeMedianDeliveryHours, computeOnTimeSlaPct, computeStockoutSkuDays, computeDockTurnaroundMinutes, computeReserveViolations, computeDeliveriesPerVehiclePerDay, computeCleanEpodRatePct, computeCreditBlockedPreDispatchPct, type SourceData } from './metric-computers.js';
const WINDOW = 30;
export async function runMetricSnapshot(triggeredBy: string): Promise<{ processed: number; skipped: number }> {
  const run = await repo.createJobRun('metric_snapshot', triggeredBy);
  const since = new Date(Date.now() - WINDOW * 86_400_000);
  const today = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()));
  try {
    const [routes, stops, fuelCost, fuelVar, proofCount, decisions, slots, vehicles, stockout, assumptions] = await Promise.all([
      repo.loadRoutePlans(since), repo.loadDeliveredStops(since), repo.loadFuelCost(since), repo.loadFuelVariance(since), repo.loadProofCount(since), repo.loadCreditDecisions(since), repo.loadConfirmedSlots(since), repo.loadActiveVehicleIds(since), repo.countStockoutSkus(), repo.loadAssumptions(),
    ]);
    const blockedIds = decisions.filter((d) => d.outcome === 'BLOCKED' && d.orderId).map((d) => d.orderId!);
    const dispatched = blockedIds.length > 0 ? await repo.loadDispatchedRoutes(blockedIds) : [];
    const dispatchedSet = new Set(dispatched.flatMap((r) => r.stops.map((s) => s.orderId)));
    const assumptionMap = new Map(assumptions.map((a) => [a.key, a.value]));
    const data: SourceData = {
      routePlans: routes.map((r) => ({ plannedKm: Number(r.plannedKm), plannedMin: r.plannedMin, status: r.status })),
      deliveredStops: stops.map((s) => ({ statusUpdatedAt: s.statusUpdatedAt, plannedEta: s.plannedEta })),
      fuelCostEtb: Number(fuelCost._sum.amountEtb ?? 0),
      highVar: fuelVar.filter((f) => f.varianceFlag === 'HIGH').length,
      routeCount: routes.length, proofCount,
      blocked: decisions.filter((d) => d.outcome === 'BLOCKED').length,
      blockedDispatched: blockedIds.filter((id) => dispatchedSet.has(id)).length,
      stockoutDays: stockout,
      confirmedSlots: slots.map((s) => ({ startAt: s.startAt, confirmedAt: s.confirmedAt! })),
      vehicles: new Set(vehicles.map((v) => v.vehicleId)).size,
      days: WINDOW, wearRate: assumptionMap.get('vehicle_wear_etb_per_km') ?? 3.5,
    };
    const computations = [
      { key: 'variable_cost_per_month_etb', value: computeVariableCostEtb(data) },
      { key: 'km_per_delivery', value: computeKmPerDelivery(data) },
      { key: 'median_delivery_hours', value: computeMedianDeliveryHours(data) },
      { key: 'on_time_sla_pct', value: computeOnTimeSlaPct(data) },
      { key: 'stockout_sku_days_per_month', value: computeStockoutSkuDays(data) },
      { key: 'dock_turnaround_minutes', value: computeDockTurnaroundMinutes(data) },
      { key: 'reserve_violations_per_100_routes', value: computeReserveViolations(data) },
      { key: 'deliveries_per_vehicle_per_day', value: computeDeliveriesPerVehiclePerDay(data) },
      { key: 'clean_epod_rate_pct', value: computeCleanEpodRatePct(data) },
      { key: 'credit_blocked_pre_dispatch_pct', value: computeCreditBlockedPreDispatchPct(data) },
    ];
    let processed = 0, skipped = 0;
    for (const c of computations) { if (c.value === null) { skipped++; continue; } await repo.upsertSnapshot(today, c.key, c.value); processed++; }
    await repo.finishJobRun(run.id, { status: 'DONE', processedCount: processed, skippedCount: skipped });
    return { processed, skipped };
  } catch (err) {
    await repo.finishJobRun(run.id, { status: 'FAILED', processedCount: 0, skippedCount: 0, error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
