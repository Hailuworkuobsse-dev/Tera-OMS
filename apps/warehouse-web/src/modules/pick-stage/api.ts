import { api } from '../../api/client';
import type { PickListResponse, MarkPickedResponse } from './types';
export const pickKeys = { all: ['pick-stage'] as const, list: (routeId: string) => [...pickKeys.all, 'list', routeId] as const };
export function fetchPickList(routeId: string, signal?: AbortSignal) { return api<PickListResponse>({ path: `/routing/v1/routes/${routeId}/pick-list`, signal }); }
export function markPicked(routeId: string, stopId: string) {
  return api<MarkPickedResponse>({ method: 'POST', path: `/routing/v1/routes/${routeId}/stops/${stopId}/picked` });
}
export function confirmLoading(slotId: string) { return api<{ slot_id: string; status: string; confirmed_at: string }>({ method: 'POST', path: `/dispatch/v1/slots/${slotId}/confirm` }); }
