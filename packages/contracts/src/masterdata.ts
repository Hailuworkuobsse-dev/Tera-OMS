import { z } from 'zod';

export const DistributorSchema = z.object({
  id: z.string(), name: z.string(), region: z.string(),
  active: z.boolean(),
  created_at: z.string().datetime(), updated_at: z.string().datetime(),
});
export const DistributorsResponseSchema = z.object({ distributors: z.array(DistributorSchema) });

export const VehicleSchema = z.object({
  id: z.string(), plate: z.string(),
  capacity_kg: z.number(), capacity_m3: z.number(),
  shift_start_h: z.number().int(), shift_end_h: z.number().int(),
  start_lat: z.number(), start_lng: z.number(),
  baseline_l_per_100km: z.number().nullable(), active: z.boolean(),
  created_at: z.string().datetime(), updated_at: z.string().datetime(),
});
export const VehiclesResponseSchema = z.object({ vehicles: z.array(VehicleSchema) });

export const SkuSchema = z.object({
  id: z.string(), code: z.string(), name: z.string(), unit: z.string(),
  weight_kg: z.number(), volume_m3: z.number(),
  reorder_point: z.number().int(), safety_stock: z.number().int(), lead_time_days: z.number().int(),
  active: z.boolean(),
  created_at: z.string().datetime(), updated_at: z.string().datetime(),
});
export const SkusResponseSchema = z.object({ skus: z.array(SkuSchema) });

export const CreateDistributorSchema = z.object({
  name: z.string().trim().min(1).max(200), region: z.string().trim().min(1).max(100),
});
export const CreateVehicleSchema = z.object({
  plate: z.string().trim().min(1).max(20),
  capacity_kg: z.number().positive(), capacity_m3: z.number().positive(),
  shift_start_h: z.number().int().min(0).max(23), shift_end_h: z.number().int().min(0).max(23),
  start_lat: z.number().gte(-90).lte(90), start_lng: z.number().gte(-180).lte(180),
  baseline_l_per_100km: z.number().positive().nullable(),
});
export const CreateSkuSchema = z.object({
  code: z.string().trim().min(1).max(40),
  name: z.string().trim().min(1).max(200),
  unit: z.string().trim().min(1).max(20),
  weight_kg: z.number().positive(), volume_m3: z.number().positive(),
  reorder_point: z.number().int().nonnegative().default(0),
  safety_stock: z.number().int().nonnegative().default(0),
  lead_time_days: z.number().int().nonnegative().default(0),
});
export const ToggleActiveSchema = z.object({ active: z.boolean() });

export const MasterdataEntityTypeEnum = z.enum(['distributor', 'vehicle', 'sku']);
export const ImportRequestSchema = z.object({
  type: MasterdataEntityTypeEnum,
  rows: z.array(z.record(z.string())).min(1).max(1000),
});
export const ImportRowResultSchema = z.object({
  row_number: z.number().int(), data: z.record(z.string()),
  status: z.enum(['valid', 'invalid']), errors: z.array(z.string()),
});
export const ValidateImportResponseSchema = z.object({
  type: MasterdataEntityTypeEnum,
  total_rows: z.number().int(), valid_rows: z.number().int(), invalid_rows: z.number().int(),
  rows: z.array(ImportRowResultSchema),
});
export const CommitImportResponseSchema = z.object({
  inserted: z.number().int(), skipped: z.number().int(),
  errors: z.array(z.object({ row_number: z.number().int(), error: z.string() })),
});

export type Distributor = z.infer<typeof DistributorSchema>;
export type Vehicle = z.infer<typeof VehicleSchema>;
export type Sku = z.infer<typeof SkuSchema>;
export type CreateDistributor = z.infer<typeof CreateDistributorSchema>;
export type CreateVehicle = z.infer<typeof CreateVehicleSchema>;
export type CreateSku = z.infer<typeof CreateSkuSchema>;
export type MasterdataEntityType = z.infer<typeof MasterdataEntityTypeEnum>;
export type ImportRowResult = z.infer<typeof ImportRowResultSchema>;
export type ValidateImportResponse = z.infer<typeof ValidateImportResponseSchema>;
export type CommitImportResponse = z.infer<typeof CommitImportResponseSchema>;
