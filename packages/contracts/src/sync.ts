import { z } from 'zod';
import { FuelLogOpSchema } from './fuel.js';

export const SyncChangeSchema = z.object({
  cursor: z.string(), entity_type: z.string(), entity_id: z.string(),
  op: z.enum(['upsert', 'delete']),
  payload: z.record(z.unknown()),
  created_at: z.string().datetime(),
});

export const RegisterClientRequestSchema = z.object({
  device_id: z.string().min(3), driver_id: z.string().min(1),
});
export const RegisterClientResponseSchema = z.object({ client_id: z.string() });

export const PullRequestQuerySchema = z.object({
  client_id: z.string(), cursor: z.string().default('0'),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});
export const PullResponseSchema = z.object({
  changes: z.array(SyncChangeSchema),
  next_cursor: z.string(), server_time: z.string().datetime(),
});

export const RouteStopStatusUpdateOpSchema = z.object({
  client_op_id: z.string().min(8), op_type: z.literal('route_stop.status_update'),
  entity_id: z.string(),
  payload: z.object({
    status: z.enum(['PENDING', 'ARRIVED', 'DELIVERED', 'FAILED']),
    captured_at: z.string().datetime(),
  }),
});

export const ProofOutcomeEnum = z.enum(['DELIVERED', 'PARTIAL', 'NOT_AVAILABLE', 'RETURNED']);
export const PaymentMethodEnum = z.enum(['CASH', 'TELEBIRR']);

export const PaymentPayloadSchema = z.object({
  method: PaymentMethodEnum,
  amount_etb: z.number().positive(),
  telebirr_ref: z.string().min(6).max(40).nullable(),
}).refine(
  (d) => d.method === 'CASH' || (d.telebirr_ref !== null && d.telebirr_ref.trim().length >= 6),
  { message: 'telebirr_ref required for TELEBIRR', path: ['telebirr_ref'] },
);

export const RouteStopProofOpSchema = z.object({
  client_op_id: z.string().min(8), op_type: z.literal('route_stop.proof'),
  entity_id: z.string(),
  payload: z.object({
    outcome: ProofOutcomeEnum,
    qty_confirmed: z.number().int().nonnegative().nullable(),
    qty_ordered: z.number().int().nonnegative().nullable(),
    reason: z.string().max(500).nullable(),
    signature_base64: z.string().max(2_000_000).nullable(),
    photo_base64: z.string().max(3_000_000).nullable(),
    captured_at: z.string().datetime(),
    payment: z.union([PaymentPayloadSchema, z.null()]).optional(),
  }),
});

export const ClientOpSchema = z.discriminatedUnion('op_type', [
  RouteStopStatusUpdateOpSchema, RouteStopProofOpSchema, FuelLogOpSchema,
]);

export const PushRequestSchema = z.object({
  client_id: z.string(), ops: z.array(ClientOpSchema).min(1).max(100),
});
export const OpResultSchema = z.object({
  client_op_id: z.string(),
  status: z.enum(['accepted', 'rejected', 'conflict', 'duplicate']),
  server_cursor: z.string().nullable(), reason: z.string().nullable(),
});
export const PushResponseSchema = z.object({
  results: z.array(OpResultSchema), server_time: z.string().datetime(),
});

export type SyncChange = z.infer<typeof SyncChangeSchema>;
export type ClientOp = z.infer<typeof ClientOpSchema>;
export type ProofOutcome = z.infer<typeof ProofOutcomeEnum>;
export type PaymentMethod = z.infer<typeof PaymentMethodEnum>;
export type PaymentPayload = z.infer<typeof PaymentPayloadSchema>;
export type OpResult = z.infer<typeof OpResultSchema>;
export type PushResponse = z.infer<typeof PushResponseSchema>;
export type PullResponse = z.infer<typeof PullResponseSchema>;
