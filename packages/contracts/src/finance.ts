import { z } from 'zod';

export const UnreconciledPaymentSchema = z.object({
  id: z.string(), route_stop_id: z.string(),
  driver_id: z.string(), vehicle_id: z.string(),
  distributor_name: z.string(),
  method: z.enum(['CASH', 'TELEBIRR']),
  amount_etb: z.number(), telebirr_ref: z.string().nullable(),
  captured_at: z.string().datetime(),
});
export const UnreconciledPaymentsResponseSchema = z.object({
  total: z.number().int(), payments: z.array(UnreconciledPaymentSchema),
});
export const ReconcileRequestSchema = z.object({ notes: z.string().max(500).optional() });
export const ReconcileResponseSchema = z.object({
  ok: z.literal(true), reconciled_at: z.string().datetime(),
});

export type UnreconciledPayment = z.infer<typeof UnreconciledPaymentSchema>;
export type UnreconciledPaymentsResponse = z.infer<typeof UnreconciledPaymentsResponseSchema>;
