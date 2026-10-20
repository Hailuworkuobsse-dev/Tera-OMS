import type { DashboardResponse, Tile, CostAssumption, FreezeBaselineRequest } from '@tera/contracts';
import * as repo from './repository.js';
import { METRIC_SPECS, DEFAULT_ASSUMPTIONS, buildTile, computeHero, type Assumptions } from './metrics.js';

function assumptionsFromRows(rows: { key: string; value: number }[]): Assumptions {
  const m = new Map(rows.map((r) => [r.key, r.value]));
  return {
    monthlyDeliveries: m.get('monthly_deliveries') ?? DEFAULT_ASSUMPTIONS.monthlyDeliveries,
    monthlyRoutes: m.get('monthly_routes') ?? DEFAULT_ASSUMPTIONS.monthlyRoutes,
    dailyVehicles: m.get('daily_vehicles') ?? DEFAULT_ASSUMPTIONS.dailyVehicles,
    vehicleWearEtbPerKm: m.get('vehicle_wear_etb_per_km') ?? DEFAULT_ASSUMPTIONS.vehicleWearEtbPerKm,
    marginPerSkuDayEtb: m.get('margin_per_sku_day_etb') ?? DEFAULT_ASSUMPTIONS.marginPerSkuDayEtb,
    costPerFuelIncidentEtb: m.get('cost_per_fuel_incident_etb') ?? DEFAULT_ASSUMPTIONS.costPerFuelIncidentEtb,
    avgMarginPerDeliveryEtb: m.get('avg_margin_per_delivery_etb') ?? DEFAULT_ASSUMPTIONS.avgMarginPerDeliveryEtb,
  };
}
async function isDemoMode() { const r = await repo.getFlag('analytics.demoMode'); return r?.value === 'true'; }

export async function getDashboard(): Promise<DashboardResponse> {
  const [baselineRows, assumptionRows, demoMode] = await Promise.all([repo.findBaselines(), repo.getAssumptions(), isDemoMode()]);
  if (baselineRows.length === 0) return { as_of: new Date().toISOString(), baseline_frozen_at: null, is_demo: demoMode, hero: null, tiles: [] };
  const assumptions = assumptionsFromRows(assumptionRows);
  const baselineMap = new Map(baselineRows.map((b) => [b.key, b]));
  const frozenAt = baselineRows[0]!.frozenAt;
  const tiles: Tile[] = [];
  for (const spec of METRIC_SPECS) {
    const b = baselineMap.get(spec.key); if (!b) continue;
    const current = await repo.getLatestSnapshot(spec.key); if (!current) continue;
    const trendRows = await repo.getLastNDays(spec.key, 7);
    const trend = trendRows.slice().reverse().map((r) => Math.round(r.value * 100) / 100);
    tiles.push(buildTile(spec, b.value, current.value, trend, assumptions));
  }
  return { as_of: new Date().toISOString(), baseline_frozen_at: frozenAt.toISOString(), is_demo: demoMode, hero: computeHero(tiles, frozenAt), tiles };
}

export async function freezeBaseline(input: FreezeBaselineRequest, actorId: string): Promise<DashboardResponse> {
  for (const spec of METRIC_SPECS) {
    const current = await repo.getLatestSnapshot(spec.key);
    if (!current) continue;
    await repo.upsertBaseline({ key: spec.key, value: current.value, unit: spec.unit, notes: input.notes ?? null, frozenAt: new Date(), frozenBy: actorId });
  }
  await repo.setFlag('analytics.demoMode', 'false');
  return getDashboard();
}

export async function listAssumptions(): Promise<{ assumptions: CostAssumption[] }> {
  const rows = await repo.getAssumptions();
  return { assumptions: rows.map((r) => ({ key: r.key, value: r.value, unit: r.unit, updated_at: r.updatedAt.toISOString() })) };
}
export async function updateAssumption(key: string, value: number): Promise<CostAssumption> {
  const existing = await repo.getAssumptions();
  const cur = existing.find((r) => r.key === key);
  if (!cur) { const e = new Error(`assumption "${key}" not found`) as any; e.statusCode = 404; throw e; }
  const u = await repo.upsertAssumption(key, value, cur.unit);
  return { key: u.key, value: u.value, unit: u.unit, updated_at: u.updatedAt.toISOString() };
}
