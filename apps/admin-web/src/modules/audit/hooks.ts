import { useQuery } from '@tanstack/react-query';
import { auditKeys, fetchAuditLog } from './api';
export const useAuditLog = (f: { entity?: string; actor?: string }) => useQuery({ queryKey: auditKeys.list(f.entity ?? '', f.actor ?? ''), queryFn: () => fetchAuditLog(f) });
