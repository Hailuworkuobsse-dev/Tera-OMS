export type SlotStatus = 'AVAILABLE' | 'ALLOCATED' | 'CONFIRMED' | 'COMPLETED';
export type RouteStatus = 'PLANNED' | 'DISPATCHED' | 'COMPLETED';

export interface GateInput { routeStatus: RouteStatus; slotStatus: SlotStatus | null; }
export interface GateResult { allowed: boolean; reason: string | null; }

export function canDispatch(input: GateInput): GateResult {
  if (input.routeStatus === 'DISPATCHED' || input.routeStatus === 'COMPLETED') return { allowed: false, reason: 'route already dispatched or completed' };
  if (input.slotStatus === null) return { allowed: false, reason: 'no dock slot allocated' };
  if (input.slotStatus === 'AVAILABLE') return { allowed: false, reason: 'slot not allocated to a route' };
  if (input.slotStatus === 'ALLOCATED') return { allowed: false, reason: 'loading not confirmed by warehouse' };
  return { allowed: true, reason: null };
}

export function nextRouteStatus(): RouteStatus { return 'DISPATCHED'; }
export function nextSlotStatus(): SlotStatus { return 'COMPLETED'; }

export interface ConfirmLoadingInput { slotStatus: SlotStatus; pickedCount: number; totalCount: number; }
export interface ConfirmLoadingResult { allowed: boolean; reason: string | null; }

export function canConfirmLoading(input: ConfirmLoadingInput): ConfirmLoadingResult {
  if (input.slotStatus !== 'ALLOCATED') return { allowed: false, reason: `cannot confirm: slot is ${input.slotStatus}` };
  if (input.totalCount === 0) return { allowed: false, reason: 'cannot confirm: route has no stops' };
  if (input.pickedCount < input.totalCount) return { allowed: false, reason: `cannot confirm: ${input.pickedCount} of ${input.totalCount} stops picked` };
  return { allowed: true, reason: null };
}

export interface MarkPickedInput { slotStatus: SlotStatus | null; currentPickedAt: string | null; }
export interface MarkPickedResult { allowed: boolean; reason: string | null; already_picked_at: string | null; }

export function canMarkPicked(input: MarkPickedInput): MarkPickedResult {
  if (input.slotStatus === null) return { allowed: false, reason: 'no dock slot allocated to this route', already_picked_at: null };
  if (input.slotStatus === 'AVAILABLE') return { allowed: false, reason: 'slot not allocated to a route', already_picked_at: null };
  if (input.slotStatus === 'CONFIRMED' || input.slotStatus === 'COMPLETED') return { allowed: false, reason: 'loading already confirmed — cannot pick', already_picked_at: null };
  if (input.currentPickedAt !== null) return { allowed: true, reason: null, already_picked_at: input.currentPickedAt };
  return { allowed: true, reason: null, already_picked_at: null };
}
