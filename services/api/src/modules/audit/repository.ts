import { db } from '@tera/db';
export function findEntries(input: { entity?: string; actor?: string; limit: number }) {
  return db().auditLog.findMany({ where: { ...(input.entity ? { entity: input.entity } : {}), ...(input.actor ? { actorId: input.actor } : {}) }, orderBy: { createdAt: 'desc' }, take: input.limit });
}
