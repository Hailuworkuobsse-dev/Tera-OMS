import { db } from '@tera/db';
export function findUnreconciled(limit: number) { return db().payment.findMany({ where: { reconciledAt: null }, orderBy: { receivedAt: 'desc' }, take: limit }); }
export function findRouteStopsByIds(ids: string[]) { return db().routeStop.findMany({ where: { id: { in: ids } }, include: { routePlan: { select: { driverId: true, vehicleId: true } } } }); }
export function findById(id: string) { return db().payment.findUnique({ where: { id } }); }
export function reconcile(id: string, actorId: string, notes: string | null) {
  return db().payment.update({ where: { id }, data: { reconciledAt: new Date(), reconciledBy: actorId, reconcileNotes: notes } });
}
