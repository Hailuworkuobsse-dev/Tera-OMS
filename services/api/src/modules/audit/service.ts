import type { AuditListResponse, AuditLogEntry } from '@tera/contracts';
import * as repo from './repository.js';
export async function listAudit(input: { entity?: string; actor?: string; limit: number }): Promise<AuditListResponse> {
  const rows = await repo.findEntries(input);
  return { total: rows.length, entries: rows.map(toEntry) };
}
function toEntry(row: any): AuditLogEntry {
  return { id: row.id, actor_id: row.actorId, entity: row.entity, entity_id: row.entityId, action: row.action, reason: row.reason, meta: row.metaJson as any, created_at: row.createdAt.toISOString() };
}
