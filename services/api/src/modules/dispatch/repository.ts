import { db } from '@tera/db';

export function findDocksWithTodaySlots(date: Date) {
  return db().dispatchDock.findMany({
    where: { active: true }, orderBy: { name: 'asc' },
    include: { slots: { where: { date }, orderBy: { startAt: 'asc' } } },
  });
}
export function findPlannedRoutes(date: Date) {
  return db().routePlan.findMany({
    where: { date, status: 'PLANNED' },
    include: { stops: { select: { id: true, pickedAt: true } } },
    orderBy: { vehicleId: 'asc' },
  });
}
export function findRoutePlanById(id: string) {
  return db().routePlan.findUnique({
    where: { id }, include: { stops: { select: { id: true, pickedAt: true } } },
  });
}
export function findSlotForRoute(routeId: string) {
  return db().dispatchDockSlot.findUnique({ where: { routePlanId: routeId } });
}
export function findAvailableSlots(date: Date) {
  return db().dispatchDockSlot.findMany({ where: { date, status: 'AVAILABLE' }, orderBy: { startAt: 'asc' } });
}
export function findSlotById(id: string) { return db().dispatchDockSlot.findUnique({ where: { id } }); }
export async function allocateSlot(slotId: string, routePlanId: string) {
  return db().dispatchDockSlot.update({ where: { id: slotId }, data: { status: 'ALLOCATED', routePlanId } });
}
export async function confirmSlot(slotId: string, confirmedBy: string) {
  return db().dispatchDockSlot.update({ where: { id: slotId }, data: { status: 'CONFIRMED', confirmedAt: new Date(), confirmedBy } });
}
export async function dispatchRoute(routeId: string, slotId: string) {
  return db().$transaction(async (tx) => {
    await tx.routePlan.update({ where: { id: routeId }, data: { status: 'DISPATCHED' } });
    await tx.dispatchDockSlot.update({ where: { id: slotId }, data: { status: 'COMPLETED' } });
  });
}
export function findAllRoutesForDate(date: Date) {
  return db().routePlan.findMany({
    where: { date }, include: { stops: { select: { id: true, pickedAt: true } } },
    orderBy: { vehicleId: 'asc' },
  });
}
export function findAllSlotsForDate(date: Date) {
  return db().dispatchDockSlot.findMany({ where: { date }, orderBy: { startAt: 'asc' } });
}
