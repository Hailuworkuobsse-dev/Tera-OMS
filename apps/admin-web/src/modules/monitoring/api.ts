import { api } from '../../api/client';
import type { MonitoringSnapshot } from './types';
export const monitoringKeys = { all: ['monitoring'] as const, snapshot: () => [...monitoringKeys.all, 'snapshot'] as const };
export const fetchSnapshot = (signal?: AbortSignal) => api<MonitoringSnapshot>({ path: '/admin/monitoring/v1/snapshot', signal });
