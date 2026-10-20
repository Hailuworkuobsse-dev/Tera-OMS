import { z } from 'zod';

export const VehicleSchema = z.object({
  id: z.string(), plate: z.string(),
  capacity_kg: z.number(), capacity_m3: z.number(),
  shift_start_h: z.number().int(), shift_end_h: z.number().int(),
  start_lat: z.number(), start_lng: z.number(),
});
export const VehiclesResponseSchema = z.object({ vehicles: z.array(VehicleSchema) });

export const SolveRequestSchema = z.object({
  order_ids: z.array(z.string()).min(2),
  vehicle_id: z.string().min(1),
});

export const SolveStopSchema = z.object({
  order_id: z.string(), distributor_name: z.string(),
  seq: z.number().int().positive(),
  eta: z.string(), lat: z.number(), lng: z.number(),
});
export const SolveSequenceSchema = z.object({
  stops: z.array(SolveStopSchema),
  total_km: z.number(), total_min: z.number().int(),
});
export const SolveResponseSchema = z.object({
  manual: SolveSequenceSchema, optimized: SolveSequenceSchema,
  savings_km_pct: z.number(), savings_time_pct: z.number(),
  infeasible: z.object({ order_id: z.string(), reason: z.string() }).nullable(),
});

export const AcceptRouteRequestSchema = z.object({
  order_ids: z.array(z.string()).min(2),
  vehicle_id: z.string().min(1),
  driver_id: z.string().min(1),
  mode: z.enum(['optimized', 'manual']),
});
export const AcceptRouteResponseSchema = z.object({
  route_id: z.string(), planned_km: z.number(), planned_min: z.number().int(),
});

export const AsyncSolveStatusEnum = z.enum(['QUEUED', 'RUNNING', 'DONE', 'FAILED', 'TIMEOUT']);
export const AsyncSolveRequestSchema = z.object({
  order_ids: z.array(z.string()).min(2).max(500),
  vehicle_id: z.string().min(1),
});
export const AsyncSolveSubmitResponseSchema = z.object({
  job_id: z.string(), status: AsyncSolveStatusEnum,
});
export const AsyncSolveJobResponseSchema = z.object({
  job_id: z.string(), status: AsyncSolveStatusEnum,
  submitted_at: z.string().datetime(),
  started_at: z.string().datetime().nullable(),
  finished_at: z.string().datetime().nullable(),
  duration_ms: z.number().int().nullable(),
  result: SolveResponseSchema.nullable(),
  error: z.string().nullable(),
});

export type Vehicle = z.infer<typeof VehicleSchema>;
export type SolveRequest = z.infer<typeof SolveRequestSchema>;
export type SolveResponse = z.infer<typeof SolveResponseSchema>;
export type SolveSequence = z.infer<typeof SolveSequenceSchema>;
export type AcceptRouteRequest = z.infer<typeof AcceptRouteRequestSchema>;
export type AcceptRouteResponse = z.infer<typeof AcceptRouteResponseSchema>;
export type AsyncSolveStatus = z.infer<typeof AsyncSolveStatusEnum>;
export type AsyncSolveSubmitResponse = z.infer<typeof AsyncSolveSubmitResponseSchema>;
export type AsyncSolveJobResponse = z.infer<typeof AsyncSolveJobResponseSchema>;
