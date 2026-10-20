import type { BoardResponse, Dock, DockSlot, RouteSummary, ConfirmSlotResponse, DispatchRouteResponse } from '@tera/contracts';
import * as repo from './repository.js';
import { canDispatch, nextRouteStatus, nextSlotStatus, canConfirmLoading } from './rules.js';
import { writeAudit } from '../../core/audit.js';

function startOfTodayUTC(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

function summarizeRoute(route: {
  id: string; vehicleId: string; driverId: string; status: string;
  plannedKm: any; plannedMin: number; stops: { id: string; pickedAt: Date | null }[];
}): RouteSummary {
  return {
    id: route.id, vehicle_id: route.vehicleId, driver_id: route.driverId,
    status: route.status as RouteSummary['status'],
    planned_km: Number(route.plannedKm), planned_min: route.plannedMin,
    stop_count: route.stops.length,
    picked_count: route.stops.filter((s) => s.pickedAt !== null).length,
  };
}

export async function getBoard(): Promise<BoardResponse> {
  const date = startOfTodayUTC();
  const [docks, allRoutes, allSlots] = await Promise.all([
    repo.findDocksWithTodaySlots(date),
    repo.findAllRoutesForDate(date),
    repo.findAllSlotsForDate(date),
  ]);
  const routeById = new Map(allRoutes.map((r) => [r.id, r]));
  const dockViews: Dock[] = docks.map((d) => ({
    id: d.id, name: d.name,
    slots: d.slots.map((s): DockSlot => {
      const route = s.routePlanId ? routeById.get(s.routePlanId) : null;
      return {
        id: s.id, start_at: s.startAt.toISOString(), end_at: s.endAt.toISOString(),
        status: s.status as DockSlot['status'],
        confirmed_at: s.confirmedAt ? s.confirmedAt.toISOString() : null,
        confirmed_by: s.confirmedBy,
        route: route ? summarizeRoute(route) : null,
      };
    }),
  }));
  const allocatedRouteIds = new Set(allSlots.map((s) => s.routePlanId).filter((x): x is string => !!x));
  return {
    as_of: new Date().toISOString(),
    summary: {
      routes_planned: allRoutes.filter((r) => r.status === 'PLANNED').length,
      routes_dispatched: allRoutes.filter((r) => r.status === 'DISPATCHED').length,
      slots_available: allSlots.filter((s) => s.status === 'AVAILABLE').length,
      slots_allocated: allSlots.filter((s) => s.status === 'ALLOCATED').length,
      slots_confirmed: allSlots.filter((s) => s.status === 'CONFIRMED').length,
      unallocated_routes: allRoutes.filter((r) => r.status === 'PLANNED' && !allocatedRouteIds.has(r.id)).length,
    },
    docks: dockViews,
  };
}

export async function allocateAll(): Promise<{ allocated: number; skipped_unallocatable: number }> {
  const date = startOfTodayUTC();
  const [planned, available] = await Promise.all([repo.findPlannedRoutes(date), repo.findAvailableSlots(date)]);
  let allocated = 0; let skipped = 0;
  for (let i = 0; i < planned.length; i++) {
    const slot = available[i];
    if (!slot) { skipped = planned.length - i; break; }
    await repo.allocateSlot(slot.id, planned[i]!.id);
    allocated++;
  }
  return { allocated, skipped_unallocatable: skipped };
}

export async function confirmSlot(slotId: string, actorId: string): Promise<ConfirmSlotResponse> {
  const slot = await repo.findSlotById(slotId);
  if (!slot) { const e = new Error('slot not found') as any; e.statusCode = 404; throw e; }
  if (!slot.routePlanId) { const e = new Error('cannot confirm: no route on this slot') as any; e.statusCode = 400; throw e; }
  const route = await repo.findRoutePlanById(slot.routePlanId);
  if (!route) { const e = new Error('cannot confirm: route not found') as any; e.statusCode = 404; throw e; }
  const pickedCount = route.stops.filter((s) => s.pickedAt !== null).length;
  const gate = canConfirmLoading({ slotStatus: slot.status as any, pickedCount, totalCount: route.stops.length });
  if (!gate.allowed) { const e = new Error(gate.reason!) as any; e.statusCode = 400; throw e; }
  const updated = await repo.confirmSlot(slotId, actorId);
  await writeAudit({ actorId, entity: 'dock_slot', entityId: slotId, action: 'confirmed', reason: `all ${pickedCount} stops picked`, meta: { slotId } });
  return { slot_id: updated.id, status: updated.status as any, confirmed_at: updated.confirmedAt!.toISOString() };
}

export async function dispatchRoute(routeId: string, actorId: string): Promise<DispatchRouteResponse> {
  const route = await repo.findRoutePlanById(routeId);
  if (!route) { const e = new Error('route not found') as any; e.statusCode = 404; throw e; }
  const slot = await repo.findSlotForRoute(routeId);
  const gate = canDispatch({ routeStatus: route.status as any, slotStatus: (slot?.status ?? null) as any });
  if (!gate.allowed) { const e = new Error(`cannot dispatch: ${gate.reason}`) as any; e.statusCode = 400; throw e; }
  await repo.dispatchRoute(routeId, slot!.id);
  await writeAudit({ actorId, entity: 'route', entityId: routeId, action: 'dispatched', reason: `slot ${slot!.id} confirmed`, meta: { slotId: slot!.id } });
  return { route_id: routeId, status: nextRouteStatus(), slot_status: nextSlotStatus() };
}
