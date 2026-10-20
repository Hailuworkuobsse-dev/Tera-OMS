import { api } from '../../../../api/client';
import type { UnreconciledPaymentsResponse } from '@tera/contracts';
export const reconciliationKeys = { all: ['reconciliation'] as const, list: () => [...reconciliationKeys.all, 'unreconciled'] as const };
export const fetchUnreconciled = (signal?: AbortSignal) => api<UnreconciledPaymentsResponse>({ path: '/payments/v1/unreconciled', signal });
export function reconcilePayment(id: string, notes?: string) { return api<{ ok: true; reconciled_at: string }>({ method: 'POST', path: `/payments/v1/${id}/reconcile`, body: notes ? { notes } : {} }); }
