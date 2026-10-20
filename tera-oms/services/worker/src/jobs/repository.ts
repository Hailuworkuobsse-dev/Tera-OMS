import { db } from '@tera/db';
export const createJobRun = (k: string, t: string) => db().jobRun.create({ data: { jobKey: k, triggeredBy: t, status: 'RUNNING' } });
export async function finishJobRun(id: string, i: { status: string; processedCount: number; skippedCount: number; error?: string | null }) {
  const fin = new Date();
  const row = await db().jobRun.update({ where: { id }, data: { status: i.status, finishedAt: fin, processedCount: i.processedCount, skippedCount: i.skippedCount, error: i.error ?? null } });
  await db().jobRun.update({ where: { id }, data: { durationMs: fin.getTime() - row.startedAt.getTime() } });
}
export const upsertSnapshot = (date: Date, key: string, value: number) => db().metricSnapshot.upsert({ where: { date_key: { date, key } }, create: { date, key, value }, update: { value } });
export const loadAssumptions = () => db().costAssumption.findMany();
export const loadActiveVehicles = () => db().vehicle.findMany({ where: { active: true, baselineLPer100Km: { not: null } } });
export const loadFuelFillsForVehicle = (id: string, since: Date) => db().fuelLog.findMany({ where: { vehicleId: id, capturedAt: { gte: since } }, select: { liters: true, odometerKm: true, capturedAt: true }, orderBy: { capturedAt: 'asc' } });
export const loadAllCreditAccounts = () => db().creditAccount.findMany();
export const loadUnreconciledPaymentsForDistributor = (distId: string) => db().payment.findMany({ where: { reconciledAt: null, routeStop: { distributorId: distId } }, select: { capturedAt: true, amountEtb: true } });
export const loadDeliveredStopsForDistributor = (distId: string) => db().routeStop.findMany({ where: { distributorId: distId, status: 'DELIVERED' }, select: { id: true, statusUpdatedAt: true } });
export const loadReconciledStopsForDistributor = (distId: string) => db().payment.findMany({ where: { reconciledAt: { not: null }, routeStop: { distributorId: distId } }, select: { routeStopId: true } });
export const updateCreditAccount = (id: string, i: { oldestUnpaidAt: Date | null; exposureEtb: number }) => db().creditAccount.update({ where: { id }, data: i });
export const createAudit = (i: any) => db().auditLog.create({ data: { actorId: i.actorId, entity: i.entity, entityId: i.entityId, action: i.action, reason: i.reason, metaJson: i.meta as any } });
export const loadRoutePlans = (since: Date) => db().routePlan.findMany({ where: { date: { gte: since } } });
export const loadDeliveredStops = (since: Date) => db().routeStop.findMany({ where: { status: 'DELIVERED', statusUpdatedAt: { gte: since } }, select: { statusUpdatedAt: true, plannedEta: true } });
export const loadFuelCost = (since: Date) => db().fuelLog.aggregate({ where: { capturedAt: { gte: since } }, _sum: { amountEtb: true } });
export const loadFuelVariance = (since: Date) => db().fuelLog.findMany({ where: { capturedAt: { gte: since } }, select: { varianceFlag: true } });
export const loadProofCount = (since: Date) => db().proofOfDelivery.count({ where: { capturedAt: { gte: since } } });
export const loadCreditDecisions = (since: Date) => db().creditDecision.findMany({ where: { createdAt: { gte: since } }, select: { outcome: true, orderId: true } });
export const loadDispatchedRoutes = (orderIds: string[]) => db().routePlan.findMany({ where: { stops: { some: { orderId: { in: orderIds } } } }, select: { stops: { select: { orderId: true } } } });
export const loadConfirmedSlots = (since: Date) => db().dispatchDockSlot.findMany({ where: { status: 'CONFIRMED', confirmedAt: { gte: since, not: null } }, select: { startAt: true, confirmedAt: true } });
export const loadActiveVehicleIds = (since: Date) => db().routePlan.findMany({ where: { date: { gte: since } }, select: { vehicleId: true } });
export async function countStockoutSkus(): Promise<number> { const s = await db().sku.findMany({ where: { active: true }, select: { stockOnHand: true, safetyStock: true } }); return s.filter((x) => x.stockOnHand < x.safetyStock).length > 0 ? 1 : 0; }
