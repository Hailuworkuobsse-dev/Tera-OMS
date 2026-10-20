import { z } from 'zod';

export const GeoJsonPolygonSchema = z.object({
  type: z.literal('Polygon'),
  coordinates: z.array(z.array(z.tuple([z.number(), z.number()]))),
});

export const CurfewZoneSchema = z.object({
  id: z.string(), name: z.string(), polygon: GeoJsonPolygonSchema,
  start_hour: z.number().int().min(0).max(23),
  end_hour: z.number().int().min(0).max(23),
  reason: z.string(), active: z.boolean(),
});

export const CurfewZonesResponseSchema = z.object({ zones: z.array(CurfewZoneSchema) });
export const CreateCurfewZoneSchema = z.object({
  name: z.string().trim().min(1).max(200),
  polygon: GeoJsonPolygonSchema,
  start_hour: z.number().int().min(0).max(23),
  end_hour: z.number().int().min(0).max(23),
  reason: z.string().trim().min(1).max(200),
});
export const UpdateCurfewHoursSchema = z.object({
  start_hour: z.number().int().min(0).max(23),
  end_hour: z.number().int().min(0).max(23),
  reason: z.string().trim().min(1).max(200),
});

export const FuelStationStatusEnum = z.enum(['operational', 'queued', 'dry']);
export const FuelStationSchema = z.object({
  id: z.string(), name: z.string(), lat: z.number(), lng: z.number(),
  status: FuelStationStatusEnum, active: z.boolean(), updated_at: z.string().datetime(),
});
export const FuelStationsResponseSchema = z.object({ stations: z.array(FuelStationSchema) });
export const CreateFuelStationSchema = z.object({
  name: z.string().trim().min(1).max(200),
  lat: z.number().gte(-90).lte(90), lng: z.number().gte(-180).lte(180),
  status: FuelStationStatusEnum.default('operational'),
});
export const UpdateStationStatusSchema = z.object({ status: FuelStationStatusEnum });
export const ToggleActiveSchema = z.object({ active: z.boolean() });

export type GeoJsonPolygon = z.infer<typeof GeoJsonPolygonSchema>;
export type CurfewZone = z.infer<typeof CurfewZoneSchema>;
export type CreateCurfewZone = z.infer<typeof CreateCurfewZoneSchema>;
export type UpdateCurfewHours = z.infer<typeof UpdateCurfewHoursSchema>;
export type FuelStation = z.infer<typeof FuelStationSchema>;
export type FuelStationStatus = z.infer<typeof FuelStationStatusEnum>;
export type CreateFuelStation = z.infer<typeof CreateFuelStationSchema>;
