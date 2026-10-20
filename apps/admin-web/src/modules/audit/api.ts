import { api } from '../../api/client';
import type { AuditListResponse } from './types';
export const auditKeys = { all: ['audit'] as const, list: (e: string, a: string) => [...auditKeys.all, 'list', e, a] as const };
export function fetchAuditLog(f: { entity?: string; actor?: string; limit?: number }) {
  const p = new URLSearchParams(); if (f.entity) p.set('entity', f.entity); if (f.actor) p.set('actor', f.actor); p.set('limit', String(f.limit ?? 100));
  return api<AuditListResponse>({ path: `/audit/v1/log?${p}` });
}
