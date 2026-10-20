import { z } from 'zod';

export const AuditLogEntrySchema = z.object({
  id: z.string(), actor_id: z.string(),
  entity: z.string(), entity_id: z.string(), action: z.string(),
  reason: z.string(), meta: z.record(z.unknown()).nullable(),
  created_at: z.string().datetime(),
});
export const AuditListResponseSchema = z.object({
  total: z.number().int(), entries: z.array(AuditLogEntrySchema),
});
export const AuditFilterQuerySchema = z.object({
  entity: z.string().optional(), actor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

export type AuditLogEntry = z.infer<typeof AuditLogEntrySchema>;
export type AuditListResponse = z.infer<typeof AuditListResponseSchema>;
