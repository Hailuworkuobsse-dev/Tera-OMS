import { db } from '@tera/db';

export function findRoutesForDate(date: Date) {
  return db().routePlan.findMany({
    where: { date },
    include: { stops: { orderBy: { seq: 'asc' } } },
    orderBy: { vehicleId: 'asc' },
  });
}

export function findVehicles() {
  return db().vehicle.findMany({ where: { active: true }, orderBy: { plate: 'asc' } });
}

export function findVehicleById(id: string) {
  return db().vehicle.findUnique({ where: { id } });
}

export function findRouteWithStops(id: string) {
  return db().routePlan.findUnique({
    where: { id },
    include: { stops: { orderBy: { seq: 'asc' } } },
  });
}

export function findStopById(stopId: string) { return db().routeStop.findUnique({ where: { id } }); }
export function findSlotForRoute(routeId: string) { return db().dispatchDockSlot.findUnique({ where: { routePlanId: routeId } }); }
export function countPickedStopsForRoute(routeId: string) {
  return db().routeStop.count({ where: { routePlanId: routeId, pickedAt: { not: null } } });
}
export function countStopsForRoute(routeId: string) {
  return db().routeStop.count({ where: { routePlanId: routeId } });
}

export async function markStopPicked(stopId: string) {
  return db().routeStop.update({ where: { id: stopId }, data: { pickedAt: new Date() } });
}

export async function createRoutePlanWithStops(input: {
  date: Date; vehicleId: string; driverId: string;
  plannedKm: number; plannedMin: number;
  startLat: number; startLng: number; baselineKm: number;
  stops: {
    orderId: string; seq: number; distributorId: string; distributorName: string;
    lat: number; lng: number; plannedEta: Date; quantityOrdered?: number;
  }[];
}) {
  return db().$transaction(async (tx) => {
    const plan = await tx.routePlan.create({
      data: {
        date: input.date, vehicleId: input.vehicleId, driverId: input.driverId,
        status: 'PLANNED', version: 1,
        plannedKm: input.plannedKm, plannedMin: input.plannedMin,
        startLat: input.startLat, startLng: input.startLng,
        baselineKm: input.baselineKm,
      },
    });
    for (const s of input.stops) {
      await tx.routeStop.create({
        data: {
          routePlanId: plan.id, orderId: s.orderId, seq: s.seq,
          distributorId: s.distributorId, distributorName: s.distributorName,
          lat: s.lat, lng: s.lng, plannedEta: s.plannedEta,
          status: 'PENDING', quantityOrdered: s.quantityOrdered ?? 0,
        },
      });
    }
    await tx.order.updateMany({
      where: { id: { in: input.stops.map((s) => s.orderId) } },
      data: { status: 'ROUTED' },
    });
    return plan;
  });
}
