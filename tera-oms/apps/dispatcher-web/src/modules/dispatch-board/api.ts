import { api } from '../../api/client';
import type { BoardResponse } from './types';

export const dispatchKeys = { all: ['dispatch-board'] as const, board: () => [...dispatchKeys.all, 'board'] as const };
export function fetchBoard(signal?: AbortSignal) { return api<BoardResponse>({ path: '/dispatch/v1/board', signal }); }
export function allocateAll() { return api<{ allocated: number; skipped_unallocatable: number }>({ method: 'POST', path: '/dispatch/v1/slots/allocate' }); }
export function confirmSlot(slotId: string) { return api<{ slot_id: string; status: string; confirmed_at: string }>({ method: 'POST', path: `/dispatch/v1/slots/${slotId}/confirm` }); }
export function dispatchRoute(routeId: string) { return api<{ route_id: string; status: string; slot_status: string }>({ method: 'POST', path: `/dispatch/v1/routes/${routeId}/dispatch` }); }
