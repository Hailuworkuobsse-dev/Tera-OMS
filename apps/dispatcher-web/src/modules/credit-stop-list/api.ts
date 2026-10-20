import { api } from '../../api/client';
import type { CreditStopListResponse, OverrideRequest } from './types';

export const creditKeys = {
  all: ['credit'] as const,
  stopList: () => [...creditKeys.all, 'stop-list', 'today'] as const,
};
export function fetchCreditStopList(signal?: AbortSignal) {
  return api<CreditStopListResponse>({ path: '/credit/v1/stop-list', signal });
}
export function overrideCredit(req: OverrideRequest) {
  return api<{ ok: true; expires_at: string }>({ method: 'POST', path: '/credit/v1/overrides', body: req });
}
