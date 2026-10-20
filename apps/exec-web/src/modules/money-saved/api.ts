import { api } from '../../api/client';
import type { DashboardResponse, CostAssumption } from './types';
export const dashKeys = { all: ['dashboard'] as const, dashboard: () => [...dashKeys.all, 'dashboard'] as const, assumptions: () => [...dashKeys.all, 'assumptions'] as const };
export function fetchDashboard(signal?: AbortSignal) { return api<DashboardResponse>({ path: '/analytics/v1/dashboard', signal }); }
export function freezeBaseline(notes?: string) { return api<DashboardResponse>({ method: 'POST', path: '/analytics/v1/baseline/freeze', body: notes ? { notes } : {} }); }
export function fetchAssumptions(signal?: AbortSignal) { return api<{ assumptions: CostAssumption[] }>({ path: '/analytics/v1/cost-assumptions', signal }); }
export function updateAssumption(key: string, value: number) { return api<CostAssumption>({ method: 'PATCH', path: `/analytics/v1/cost-assumptions/${key}`, body: { value } }); }
