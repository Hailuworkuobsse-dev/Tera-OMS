import { api } from '../../api/client';
import type { BoardResponse } from './types';
export const dockKeys = { all: ['dock-queue'] as const, board: () => [...dockKeys.all, 'board'] as const };
export function fetchBoard(signal?: AbortSignal) { return api<BoardResponse>({ path: '/dispatch/v1/board', signal }); }
export function confirmLoading(slotId: string) { return api<{ slot_id: string; status: string; confirmed_at: string }>({ method: 'POST', path: `/dispatch/v1/slots/${slotId}/confirm` }); }
