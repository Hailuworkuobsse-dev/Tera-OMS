import type { Tile } from '@tera/contracts';

export interface MetricSpec {
  key: Tile['metric_key']; labelKey: string; unit: string;
  direction: 'up' | 'down'; targetMode: 'relative' | 'absolute';
  targetMin: number; targetMax: number;
}

export const METRIC_SPECS: MetricSpec[] = [
  { key: 'variable_cost_per_month_etb',       labelKey: 'exec.tile.variable_cost', unit: 'ETB',         direction: 'down', targetMode: 'relative', targetMin: 15, targetMax: 20 },
  { key: 'km_per_delivery',                    labelKey: 'exec.tile.km',            unit: 'km',          direction: 'down', targetMode: 'relative', targetMin: 10, targetMax: 15 },
  { key: 'median_delivery_hours',              labelKey: 'exec.tile.delivery_time', unit: 'h',           direction: 'down', targetMode: 'relative', targetMin: 15, targetMax: 35 },
  { key: 'on_time_sla_pct',                    labelKey: 'exec.tile.on_time',       unit: '%',           direction: 'up',   targetMode: 'relative', targetMin: 20, targetMax: 30 },
  { key: 'stockout_sku_days_per_month',        labelKey: 'exec.tile.stockout',      unit: 'SKU-days',    direction: 'down', targetMode: 'relative', targetMin: 25, targetMax: 40 },
  { key: 'dock_turnaround_minutes',            labelKey: 'exec.tile.dock',          unit: 'min',         direction: 'down', targetMode: 'relative', targetMin: 20, targetMax: 30 },
  { key: 'reserve_violations_per_100_routes',  labelKey: 'exec.tile.fuel_risk',     unit: '/100',        direction: 'down', targetMode: 'relative', targetMin: 10, targetMax: 25 },
  { key: 'deliveries_per_vehicle_per_day',     labelKey: 'exec.tile.fleet',         unit: 'del',         direction: 'up',   targetMode: 'relative', targetMin: 15, targetMax: 20 },
  { key: 'clean_epod_rate_pct',                labelKey: 'exec.tile.accuracy',      unit: '%',           direction: 'up',   targetMode: 'absolute', targetMin: 95, targetMax: 99 },
  { key: 'credit_blocked_pre_dispatch_pct',    labelKey: 'exec.tile.credit',        unit: '%',           direction: 'up',   targetMode: 'absolute', targetMin: 99, targetMax: 100 },
];

export interface Assumptions {
  monthlyDeliveries: number; monthlyRoutes: number; dailyVehicles: number;
  vehicleWearEtbPerKm: number; marginPerSkuDayEtb: number;
  costPerFuelIncidentEtb: number; avgMarginPerDeliveryEtb: number;
}

export const DEFAULT_ASSUMPTIONS: Assumptions = {
  monthlyDeliveries: 1200, monthlyRoutes: 120, dailyVehicles: 10,
  vehicleWearEtbPerKm: 3.5, marginPerSkuDayEtb: 500,
  costPerFuelIncidentEtb: 2000, avgMarginPerDeliveryEtb: 250,
};

export function computeImprovement(spec: MetricSpec, baseline: number, current: number): number {
  if (spec.targetMode === 'absolute') return spec.direction === 'up' ? current - baseline : baseline - current;
  if (baseline === 0) return 0;
  return spec.direction === 'up' ? ((current - baseline) / baseline) * 100 : ((baseline - current) / baseline) * 100;
}
export function isInTarget(spec: MetricSpec, baseline: number, current: number): boolean {
  if (spec.targetMode === 'absolute') return spec.direction === 'up' ? current >= spec.targetMin : current <= spec.targetMax;
  return computeImprovement(spec, baseline, current) >= spec.targetMin;
}
export function isFullyInTarget(spec: MetricSpec, baseline: number, current: number): boolean {
  if (spec.targetMode === 'absolute') return spec.direction === 'up' ? current >= spec.targetMax : current <= spec.targetMin;
  return computeImprovement(spec, baseline, current) >= spec.targetMax;
}
export function computeEtbImpact(spec: MetricSpec, baseline: number, current: number, a: Assumptions): number | null {
  switch (spec.key) {
    case 'variable_cost_per_month_etb': return Math.max(0, baseline - current);
    case 'km_per_delivery': return Math.max(0, baseline - current) * a.monthlyDeliveries * a.vehicleWearEtbPerKm;
    case 'stockout_sku_days_per_month': return Math.max(0, baseline - current) * a.marginPerSkuDayEtb;
    case 'reserve_violations_per_100_routes': return (Math.max(0, baseline - current) / 100) * a.monthlyRoutes * a.costPerFuelIncidentEtb;
    case 'deliveries_per_vehicle_per_day': return Math.max(0, current - baseline) * a.dailyVehicles * a.avgMarginPerDeliveryEtb * 30;
    default: return null;
  }
}
export function buildTile(spec: MetricSpec, baseline: number, current: number, trend: number[], assumptions: Assumptions): Tile {
  return {
    metric_key: spec.key, label_key: spec.labelKey, unit: spec.unit,
    baseline, current, target_min: spec.targetMin, target_max: spec.targetMax,
    direction: spec.direction, target_mode: spec.targetMode,
    improvement_pct: Math.round(computeImprovement(spec, baseline, current) * 100) / 100,
    in_target: isInTarget(spec, baseline, current),
    fully_in_target: isFullyInTarget(spec, baseline, current),
    trend_7d: trend,
    etb_impact: computeEtbImpact(spec, baseline, current, assumptions),
  };
}
export function computeHero(tiles: Tile[], baselineFrozenAt: Date, now: Date = new Date()) {
  const cost = tiles.find((t) => t.metric_key === 'variable_cost_per_month_etb');
  if (!cost || cost.etb_impact === null) return null;
  const days = Math.max(0, Math.floor((now.getTime() - baselineFrozenAt.getTime()) / 86_400_000));
  const monthly = cost.etb_impact;
  return { monthly_savings_etb: Math.round(monthly), cumulative_savings_etb: Math.round((monthly / 30) * days), annualized_savings_etb: Math.round(monthly * 12), days_since_baseline: days };
}
