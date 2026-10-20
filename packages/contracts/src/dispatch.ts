import { z } from 'zod';

export const SlotStatusEnum = z.enum(['AVAILABLE', 'ALLOCATED', 'CONFIRMED', 'COMPLETED']);
export const RouteBoardStatusEnum = z.enum(['PLANNED', 'DISPATCHED', 'COMPLETED']);

export const RouteSummarySchema = z.object({
  id: z.string(), vehicle_id: z.string(), driver_id: z.string(),
  status: RouteBoardStatusEnum, planned_km: z.number(), planned_min: z.number().int(),
  stop_count: z.number().int(), picked_count: z.number().int(),
});

export const DockSlotSchema = z.object({
  id: z.string(), start_at: z.string().datetime(), end_at: z.string().datetime(),
  status: SlotStatusEnum,
  confirmed_at: z.string().datetime().nullable(),
  confirmed_by: z.string().nullable(),
  route: RouteSummarySchema.nullable(),
});

export const DockSchema = z.object({
  id: z.string(), name: z.string(), slots: z.array(DockSlotSchema),
});

export const BoardResponseSchema = z.object({
  as_of: z.string().datetime(),
  summary: z.object({
    routes_planned: z.number().int(), routes_dispatched: z.number().int(),
    slots_available: z.number().int(), slots_allocated: z.number().int(),
    slots_confirmed: z.number().int(), unallocated_routes: z.number().int(),
  }),
  docks: z.array(DockSchema),
});

export const AllocateResponseSchema = z.object({
  allocated: z.number().int(), skipped_unallocatable: z.number().int(),
});
export const ConfirmSlotResponseSchema = z.object({
  slot_id: z.string(), status: SlotStatusEnum, confirmed_at: z.string().datetime(),
});
export const DispatchRouteResponseSchema = z.object({
  route_id: z.string(), status: RouteBoardStatusEnum, slot_status: SlotStatusEnum,
});

export const PickListStopSchema = z.object({
  stop_id: z.string(), seq: z.number().int(),
  distributor_name: z.string(), quantity_ordered: z.number().int(),
  picked_at: z.string().datetime().nullable(),
});
export const PickListResponseSchema = z.object({
  route_id: z.string(), vehicle_id: z.string(), driver_id: z.string(),
  slot_id: z.string().nullable(), slot_status: SlotStatusEnum.nullable(),
  stops: z.array(PickListStopSchema),
  picked_count: z.number().int(), total_count: z.number().int(),
  can_confirm_loading: z.boolean(),
});
export const MarkPickedResponseSchema = z.object({
  stop_id: z.string(), picked_at: z.string().datetime(),
  picked_count: z.number().int(), total_count: z.number().int(),
  can_confirm_loading: z.boolean(),
});

export type RouteSummary = z.infer<typeof RouteSummarySchema>;
export type DockSlot = z.infer<typeof DockSlotSchema>;
export type Dock = z.infer<typeof DockSchema>;
export type BoardResponse = z.infer<typeof BoardResponseSchema>;
export type PickListStop = z.infer<typeof PickListStopSchema>;
export type PickListResponse = z.infer<typeof PickListResponseSchema>;
