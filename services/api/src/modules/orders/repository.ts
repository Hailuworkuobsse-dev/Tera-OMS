import { db } from '@tera/db';

export function findPendingOrders() {
  return db().order.findMany({ where: { status: 'PENDING' }, orderBy: { createdAt: 'asc' } });
}

export function findOrdersByIds(ids: string[]) {
  return db().order.findMany({ where: { id: { in: ids }, status: 'PENDING' } });
}

export function markOrdersRouted(orderIds: string[]) {
  return db().order.updateMany({ where: { id: { in: orderIds } }, data: { status: 'ROUTED' } });
}
