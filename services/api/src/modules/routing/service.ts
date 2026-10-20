import { solve } from '@tera/solver';
import type {
  RoutePlan, Vehicle, SolveResponse, AcceptRouteRequest, AcceptRouteResponse,
  PickListResponse, PickListStop, MarkPickedResponse,
} from '@tera/contracts';
import * as repo from './repository.js';
import * as ordersRepo from '../orders/repository.js';
import { getCurfewZones } from '../geo/service.js';
import { canConfirmLoading, canMarkPicked } from '../dispatch/rules.js';

function startOfTodayUTC(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

export async function getTodayRoutes(): Promise<{ as_of: string; routes: RoutePlan[] }> {
  const rows = await repo.findRoutesForDate(startOfTodayUTC());
  return {
    as_of: new Date().toISOString(),
    routes: rows.map((r) => ({
      id: r.id, vehicle_id: r.vehicleId, driver_id: r.driverId,
      status: r.status as RoutePlan['status'],
      planned_km: Number(r.plannedKm), planned_min: r.plannedMin,
      start_lat: Number(r.startLat), start_lng: Number(r.startLng),
      stops: r.stops.map((s) => ({
        id: s.id, seq: s.seq,
        distributor_id: s.distributorId, distributor_name: s.distributorName,
        lat: Number(s.lat), lng: Number(s.lng),
        planned_eta: s.plannedEta.toISOString(),
        actual_arrival: s.actualArrival ? s.actualArrival.toISOString() : null,
        status: s.status as any,
      })),
    })),
  };
}

export async function getVehicles(): Promise<{ vehicles: Vehicle[] }> {
  const rows = await repo.findVehicles();
  return {
    vehicles: rows.map((v) => ({
      id: v.id, plate: v.plate,
      capacity_kg: Number(v.capacityKg), capacity_m3: Number(v.capacityM3),
      shift_start_h: v.shiftStartH, shift_end_h: v.shiftEndH,
      start_lat: Number(v.startLat), start_lng: Number(v.startLng),
    })),
  };
}

async function solveCore(orderIds: string[], vehicleId: string) {
  const [vehicle, orderRows, zones] = await Promise.all([
    repo.findVehicleById(vehicleId),
    ordersRepo.findOrdersByIds(orderIds),
    getCurfewZones(),
  ]);
  if (!vehicle) { const e = new Error('vehicle not found') as any; e.statusCode = 404; throw e; }
  if (orderRows.length < 2) { const e = new Error('at least 2 pending orders required') as any; e.statusCode = 400; throw e; }
  const result = solve(
    orderRows.map((o) => ({
      id: o.id, distributor_name: o.distributorName,
      lat: Number(o.lat), lng: Number(o.lng),
      weight_kg: Number(o.weightKg), volume_m3: Number(o.volumeM3),
      priority: o.priority,
      time_window_start: o.timeWindowStart.toISOString(),
      time_window_end: o.timeWindowEnd.toISOString(),
    })),
    {
      id: vehicle.id, lat: Number(vehicle.startLat), lng: Number(vehicle.startLng),
      capacity_kg: Number(vehicle.capacityKg), capacity_m3: Number(vehicle.capacityM3),
      shift_start_h: vehicle.shiftStartH, shift_end_h: vehicle.shiftEndH,
    },
    {
      curfew_zones: zones.zones.map((z) => ({
        id: z.id, name: z.name, polygon: z.polygon,
        start_hour: z.start_hour, end_hour: z.end_hour,
      })),
    },
  );
  return { result, vehicle, orderRows };
}

export async function solveRoutes(orderIds: string[], vehicleId: string): Promise<SolveResponse> {
  const { result } = await solveCore(orderIds, vehicleId);
  return result;
}

export async function acceptRoute(req: AcceptRouteRequest): Promise<AcceptRouteResponse> {
  const { result, vehicle, orderRows } = await solveCore(req.order_ids, req.vehicle_id);
  if (result.infeasible) {
    const e = new Error(`cannot accept: ${result.infeasible.reason}`) as any; e.statusCode = 400; throw e;
  }
  const chosen = req.mode === 'optimized' ? result.optimized : result.manual;
  const byId = new Map(orderRows.map((o) => [o.id, o]));

  const plan = await repo.createRoutePlanWithStops({
    date: startOfTodayUTC(),
    vehicleId: req.vehicle_id,
    driverId: req.driver_id,
    plannedKm: chosen.total_km, plannedMin: chosen.total_min,
    startLat: Number(vehicle.startLat), startLng: Number(vehicle.startLng),
    baselineKm: result.manual.total_km,
    stops: chosen.stops.map((s) => {
      const o = byId.get(s.order_id)!;
      return {
        orderId: s.order_id, seq: s.seq,
        distributorId: o.distributorId, distributorName: o.distributorName,
        lat: s.lat, lng: s.lng, plannedEta: new Date(s.eta),
        quantityOrdered: (o as any).totalQuantity || 10,
      };
    }),
  });

  return { route_id: plan.id, planned_km: chosen.total_km, planned_min: chosen.total_min };
}

export async function getPickList(routeId: string): Promise<PickListResponse> {
  const route = await repo.findRouteWithStops(routeId);
  if (!route) { const e = new Error('route not found') as any; e.statusCode = 404; throw e; }
  const slot = await repo.findSlotForRoute(routeId);
  const stops: PickListStop[] = route.stops.map((s) => ({
    stop_id: s.id, seq: s.seq,
    distributor_name: s.distributorName,
    quantity_ordered: s.quantityOrdered,
    picked_at: s.pickedAt ? s.pickedAt.toISOString() : null,
  }));
  const pickedCount = stops.filter((s) => s.picked_at !== null).length;
  const totalCount = stops.length;
  const gate = canConfirmLoading({
    slotStatus: (slot?.status ?? 'AVAILABLE') as any,
    pickedCount, totalCount,
  });
  return {
    route_id: route.id, vehicle_id: route.vehicleId, driver_id: route.driverId,
    slot_id: slot?.id ?? null,
    slot_status: (slot?.status as any) ?? null,
    stops, picked_count: pickedCount, total_count: totalCount,
    can_confirm_loading: gate.allowed,
  };
}

export async function markStopPicked(routeId: string, stopId: string): Promise<MarkPickedResponse> {
  const stop = await repo.findStopById(stopId);
  if (!stop) { const e = new Error('stop not found') as any; e.statusCode = 404; throw e; }
  if (stop.routePlanId !== routeId) { const e = new Error('stop does not belong to this route') as any; e.statusCode = 400; throw e; }
  const slot = await repo.findSlotForRoute(routeId);
  const gate = canMarkPicked({
    slotStatus: (slot?.status as any) ?? null,
    currentPickedAt: stop.pickedAt ? stop.pickedAt.toISOString() : null,
  });
  if (!gate.allowed) { const e = new Error(gate.reason!) as any; e.statusCode = 400; throw e; }
  let pickedAt = gate.already_picked_at;
  if (pickedAt === null) {
    const updated = await repo.markStopPicked(stopId);
    pickedAt = updated.pickedAt!.toISOString();
  }
  const pickedCount = await repo.countPickedStopsForRoute(routeId);
  const totalCount = await repo.countStopsForRoute(routeId);
  const confirmGate = canConfirmLoading({
    slotStatus: (slot?.status as any) ?? 'AVAILABLE',
    pickedCount, totalCount,
  });
  return {
    stop_id: stopId, picked_at: pickedAt,
    picked_count: pickedCount, total_count: totalCount,
    can_confirm_loading: confirmGate.allowed,
  };
}
