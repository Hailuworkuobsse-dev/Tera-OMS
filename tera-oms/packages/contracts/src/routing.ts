import { z } from 'zod';

export const StopStatusEnum = z.enum(['PENDING', 'ARRIVED', 'DELIVERED', 'FAILED']);
export const RouteStatusEnum = z.enum(['PLANNED', 'DISPATCHED', 'COMPLETED']);

export const RouteStopSchema = z.object({
  id: z.string(), seq: z.number().int(),
  distributor_id: z.string(), distributor_name: z.string(),
  lat: z.number(), lng: z.number(),
  planned_eta: z.string().datetime(), actual_arrival: z.string().datetime().nullable(),
  status: StopStatusEnum,
});

export const RoutePlanSchema = z.object({
  id: z.string(), vehicle_id: z.string(), driver_id: z.string(),
  status: RouteStatusEnum, planned_km: z.number(), planned_min: z.number().int(),
  start_lat: z.number(), start_lng: z.number(),
  stops: z.array(RouteStopSchema),
});

export const TodayRoutesResponseSchema = z.object({
  as_of: z.string().datetime(),
  routes: z.array(RoutePlanSchema),
});

export type RouteStop = z.infer<typeof RouteStopSchema>;
export type RoutePlan = z.infer<typeof RoutePlanSchema>;
