import { z } from 'zod';

export const VarianceFlagEnum = z.enum(['OK', 'HIGH', 'LOW', 'NO_BASELINE']);

export const FuelLogOpSchema = z.object({
  client_op_id: z.string().min(8), op_type: z.literal('driver.fuel_log'),
  entity_id: z.string(),
  payload: z.object({
    vehicle_id: z.string().min(1),
    liters: z.number().positive(),
    amount_etb: z.number().positive(),
    odometer_km: z.number().positive(),
    station_name: z.string().min(1).max(100),
    station_id: z.string().nullable(),
    captured_at: z.string().datetime(),
  }),
});

export type FuelLogOp = z.infer<typeof FuelLogOpSchema>;
export type VarianceFlag = z.infer<typeof VarianceFlagEnum>;
