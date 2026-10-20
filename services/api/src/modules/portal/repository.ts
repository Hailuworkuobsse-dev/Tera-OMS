import { db } from '@tera/db';
export const findDistributorWithCredit = (id: string) => db().distributor.findUnique({ where: { id }, include: { creditAccounts: true } });
export const findActiveSkus = () => db().sku.findMany({ where: { active: true }, orderBy: { code: 'asc' } });
export const findSkuByIds = (ids: string[]) => db().sku.findMany({ where: { id: { in: ids } } });
export const findOrdersByDistributor = (id: string) => db().order.findMany({ where: { distributorId: id }, include: { lines: true }, orderBy: { createdAt: 'desc' }, take: 50 });
export const findOrderByIdAndDistributor = (orderId: string, distId: string) => db().order.findFirst({ where: { id: orderId, distributorId: distId }, include: { lines: true } });
export const findRouteStopByOrderId = (orderId: string) => db().routeStop.findFirst({ where: { orderId }, include: { routePlan: { select: { driverId: true, vehicleId: true, status: true } } } });
export const findRecentDeliveries = (distId: string, limit: number) => db().routeStop.findMany({ where: { distributorId: distId, status: 'DELIVERED' }, include: { routePlan: { select: { vehicleId: true } } }, orderBy: { statusUpdatedAt: 'desc' }, take: limit });
export const findDisputes = (distId: string) => db().dispute.findMany({ where: { distributorId: distId }, orderBy: { createdAt: 'desc' } });
export const findLatestProofForOrder = (orderId: string) => db().proofOfDelivery.findFirst({ where: { orderId }, orderBy: { capturedAt: 'desc' } });
export async function createOrderWithLines(input: any) {
  const now = new Date();
  return db().order.create({ data: {
    distributorId: input.distributorId, distributorName: input.distributorName,
    lat: input.lat, lng: input.lng, weightKg: input.weightKg, volumeM3: input.volumeM3,
    priority: 5, timeWindowStart: new Date(now.getTime() + 3600_000), timeWindowEnd: new Date(now.getTime() + 86_400_000),
    status: 'PENDING', totalQuantity: input.totalQuantity,
    lines: { create: input.lines },
  }, include: { lines: true } });
}
export const createDispute = (input: any) => db().dispute.create({ data: input });
