import type { PortalProfile, CatalogItem, PlaceOrderRequest, PlaceOrderResponse, PortalOrdersResponse, PortalOrderSummary, PortalOrderDetail, StatementResponse, DisputeRow, RaiseDisputeRequest } from '@tera/contracts';
import * as repo from './repository.js';
import { computeCartTotals, computeHeadroom, type CartLine } from './cart.js';

const r2 = (n: number) => Math.round(n * 100) / 100;
const DEFAULT_LAT = 9.0108; const DEFAULT_LNG = 38.7613;

export async function getProfile(distId: string): Promise<PortalProfile> {
  const d = await repo.findDistributorWithCredit(distId);
  if (!d) { const e = new Error('distributor not found') as any; e.statusCode = 404; throw e; }
  const a = d.creditAccounts[0];
  const limit = a ? Number(a.limitEtb) : 0; const exposure = a ? Number(a.exposureEtb) : 0;
  return { distributor_id: d.id, name: d.name, region: d.region, credit_limit_etb: r2(limit), exposure_etb: r2(exposure), headroom_etb: r2(Math.max(0, limit - exposure)), utilization_pct: limit > 0 ? r2((exposure / limit) * 100) : 0 };
}
export async function getCatalog(): Promise<{ items: CatalogItem[] }> {
  const skus = await repo.findActiveSkus();
  return { items: skus.map((s) => ({ sku_id: s.id, code: s.code, name: s.name, unit: s.unit, weight_kg: Number(s.weightKg), volume_m3: Number(s.volumeM3), unit_price_etb: Number(s.unitPriceEtb), stock_on_hand: s.stockOnHand })) };
}
export async function placeOrder(distId: string, input: PlaceOrderRequest): Promise<PlaceOrderResponse> {
  const profile = await getProfile(distId);
  const skus = await repo.findSkuByIds(input.lines.map((l) => l.sku_id));
  const byId = new Map(skus.map((s) => [s.id, s]));
  const cartLines: CartLine[] = [];
  for (const l of input.lines) {
    const sku = byId.get(l.sku_id);
    if (!sku) { const e = new Error(`unknown SKU ${l.sku_id}`) as any; e.statusCode = 400; throw e; }
    if (sku.stockOnHand <= 0) { const e = new Error(`${sku.name} is out of stock`) as any; e.statusCode = 400; throw e; }
    if (l.quantity > sku.stockOnHand) { const e = new Error(`${sku.name}: only ${sku.stockOnHand} in stock`) as any; e.statusCode = 400; throw e; }
    cartLines.push({ skuId: sku.id, quantity: l.quantity, unitPrice: Number(sku.unitPriceEtb), weightKg: Number(sku.weightKg), volumeM3: Number(sku.volumeM3) });
  }
  const totals = computeCartTotals(cartLines);
  const headroom = computeHeadroom({ limitEtb: profile.credit_limit_etb, exposureEtb: profile.exposure_etb, cartSubtotalEtb: totals.subtotalEtb });
  if (headroom.wouldExceed) { const e = new Error(`Order exceeds credit headroom. Cart: ${totals.subtotalEtb} ETB, Headroom: ${headroom.headroomEtb} ETB`) as any; e.statusCode = 400; throw e; }
  const d = await repo.findDistributorWithCredit(distId);
  const lat = d?.lat ? Number(d.lat) : DEFAULT_LAT; const lng = d?.lng ? Number(d.lng) : DEFAULT_LNG;
  const order = await repo.createOrderWithLines({
    distributorId: distId, distributorName: profile.name, lat, lng,
    weightKg: totals.totalWeightKg, volumeM3: totals.totalVolumeM3, totalQuantity: totals.totalQuantity,
    lines: cartLines.map((c) => { const s = byId.get(c.skuId)!; return { skuId: c.skuId, skuCode: s.code, skuName: s.name, quantity: c.quantity, unitPrice: c.unitPrice, lineTotal: r2(c.quantity * c.unitPrice) }; }),
  });
  return { order_id: order.id, status: order.status, total_etb: totals.subtotalEtb, total_quantity: totals.totalQuantity, eta: null };
}
function mapStatus(oStatus: string, stopStatus: string | null | undefined): PortalOrderSummary['status'] {
  if (oStatus === 'DELIVERED') return 'DELIVERED';
  if (stopStatus === 'DELIVERED') return 'DELIVERED';
  if (stopStatus === 'FAILED') return 'FAILED';
  if (stopStatus) return 'ROUTED';
  return 'PENDING';
}
export async function listOrders(distId: string): Promise<PortalOrdersResponse> {
  const rows = await repo.findOrdersByDistributor(distId);
  const active: PortalOrderSummary[] = []; const recent: PortalOrderSummary[] = [];
  for (const o of rows) {
    const total = o.lines.reduce((s, l) => s + Number(l.lineTotal), 0);
    const stop = await repo.findRouteStopByOrderId(o.id);
    const s: PortalOrderSummary = { order_id: o.id, status: mapStatus(o.status, stop?.status), created_at: o.createdAt.toISOString(), total_etb: r2(total), total_quantity: o.totalQuantity, line_count: o.lines.length, eta: stop ? stop.plannedEta.toISOString() : null, vehicle_id: stop?.routePlan.vehicleId ?? null, last_stop_status: stop?.status ?? null };
    if (s.status === 'PENDING' || s.status === 'ROUTED') active.push(s); else recent.push(s);
  }
  return { active, recent };
}
export async function getOrderDetail(distId: string, orderId: string): Promise<PortalOrderDetail> {
  const o = await repo.findOrderByIdAndDistributor(orderId, distId);
  if (!o) { const e = new Error('order not found') as any; e.statusCode = 404; throw e; }
  const stop = await repo.findRouteStopByOrderId(orderId);
  return { order_id: o.id, status: mapStatus(o.status, stop?.status), created_at: o.createdAt.toISOString(), total_etb: r2(o.lines.reduce((s, l) => s + Number(l.lineTotal), 0)), total_quantity: o.totalQuantity, line_count: o.lines.length, eta: stop ? stop.plannedEta.toISOString() : null, vehicle_id: stop?.routePlan.vehicleId ?? null, driver_id: stop?.routePlan.driverId ?? null, route_stop_id: stop?.id ?? null, last_stop_status: stop?.status ?? null, lines: o.lines.map((l) => ({ sku_id: l.skuId, sku_code: l.skuCode, sku_name: l.skuName, quantity: l.quantity, unit_price_etb: Number(l.unitPrice), line_total_etb: Number(l.lineTotal) })) };
}
export async function getStatement(distId: string): Promise<StatementResponse> {
  const d = await repo.findDistributorWithCredit(distId);
  if (!d) { const e = new Error('distributor not found') as any; e.statusCode = 404; throw e; }
  const a = d.creditAccounts[0];
  const limit = a ? Number(a.limitEtb) : 0; const exposure = a ? Number(a.exposureEtb) : 0;
  const oldest = a?.oldestUnpaidAt ?? null;
  const days = oldest ? Math.floor((Date.now() - oldest.getTime()) / 86_400_000) : null;
  const deliveries = await repo.findRecentDeliveries(distId, 10);
  return { as_of: new Date().toISOString(), balance_etb: r2(exposure), limit_etb: r2(limit), grace_days: a?.graceDays ?? 14, days_since_oldest_unpaid: days, recent_payments: [], recent_deliveries: deliveries.map((s) => ({ order_id: s.orderId ?? s.id, delivered_at: s.statusUpdatedAt.toISOString(), total_quantity: s.quantityOrdered, vehicle_id: s.routePlan.vehicleId })) };
}
export async function raiseDispute(distId: string, input: RaiseDisputeRequest): Promise<DisputeRow> {
  const o = await repo.findOrderByIdAndDistributor(input.order_id, distId);
  if (!o) { const e = new Error('order not found for this distributor') as any; e.statusCode = 404; throw e; }
  const proof = await repo.findLatestProofForOrder(input.order_id);
  const d = await repo.createDispute({ orderId: input.order_id, distributorId: distId, type: input.type, description: input.description, proofId: proof?.id ?? null });
  return { id: d.id, order_id: d.orderId, type: d.type as any, description: d.description, status: d.status as any, created_at: d.createdAt.toISOString(), resolution_notes: d.resolutionNotes };
}
export async function listDisputes(distId: string): Promise<{ disputes: DisputeRow[] }> {
  const rows = await repo.findDisputes(distId);
  return { disputes: rows.map((d) => ({ id: d.id, order_id: d.orderId, type: d.type as any, description: d.description, status: d.status as any, created_at: d.createdAt.toISOString(), resolution_notes: d.resolutionNotes })) };
}
