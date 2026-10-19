// Every override writes here — this is the tuning data for solver + credit.
export interface AuditEntry { actorId: string; entity: string; action: string; reason: string; meta?: Record<string, unknown>; }
export async function writeAudit(_entry: AuditEntry): Promise<void> { /* implement with @tera/db */ }
