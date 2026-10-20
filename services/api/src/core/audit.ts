import { db } from '@tera/db';

export interface AuditEntry {
  actorId: string;
  entity: string;
  entityId: string;
  action: string;
  reason: string;
  meta?: Record<string, unknown>;
}

export async function writeAudit(entry: AuditEntry): Promise<void> {
  await db().auditLog.create({
    data: {
      actorId: entry.actorId,
      entity: entry.entity,
      entityId: entry.entityId,
      action: entry.action,
      reason: entry.reason,
      metaJson: (entry.meta ?? undefined) as any,
    },
  });
}
