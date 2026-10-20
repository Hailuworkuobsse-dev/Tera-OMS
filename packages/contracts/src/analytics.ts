import { z } from 'zod';

export const MetricKeyEnum = z.enum([
  'variable_cost_per_month_etb', 'km_per_delivery', 'median_delivery_hours',
  'on_time_sla_pct', 'stockout_sku_days_per_month', 'dock_turnaround_minutes',
  'reserve_violations_per_100_routes', 'deliveries_per_vehicle_per_day',
  'clean_epod_rate_pct', 'credit_blocked_pre_dispatch_pct',
]);

export const TileSchema = z.object({
  metric_key: MetricKeyEnum, label_key: z.string(), unit: z.string(),
  baseline: z.number(), current: z.number(),
  target_min: z.number(), target_max: z.number(),
  direction: z.enum(['up', 'down']),
  target_mode: z.enum(['relative', 'absolute']),
  improvement_pct: z.number(), in_target: z.boolean(), fully_in_target: z.boolean(),
  trend_7d: z.array(z.number()),
  etb_impact: z.number().nullable(),
});

export const HeroSchema = z.object({
  monthly_savings_etb: z.number(), cumulative_savings_etb: z.number(),
  annualized_savings_etb: z.number(), days_since_baseline: z.number().int(),
});

export const DashboardResponseSchema = z.object({
  as_of: z.string().datetime(),
  baseline_frozen_at: z.string().datetime().nullable(),
  is_demo: z.boolean(),
  hero: HeroSchema.nullable(),
  tiles: z.array(TileSchema),
});

export const FreezeBaselineRequestSchema = z.object({ notes: z.string().max(500).optional() });

export const CostAssumptionSchema = z.object({
  key: z.string(), value: z.number(), unit: z.string(), updated_at: z.string().datetime(),
});
export const CostAssumptionsResponseSchema = z.object({ assumptions: z.array(CostAssumptionSchema) });
export const UpdateCostAssumptionSchema = z.object({ value: z.number() });

export type MetricKey = z.infer<typeof MetricKeyEnum>;
export type Tile = z.infer<typeof TileSchema>;
export type Hero = z.infer<typeof HeroSchema>;
export type DashboardResponse = z.infer<typeof DashboardResponseSchema>;
export type CostAssumption = z.infer<typeof CostAssumptionSchema>;
