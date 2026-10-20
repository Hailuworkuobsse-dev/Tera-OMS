import { PrismaClient } from '../generated/client';

const prisma = new PrismaClient();
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);
const today = new Date();
const tw = (h: number) => { const x = new Date(today); x.setHours(h, 0, 0, 0); return x; };
const dateOnly = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));

async function main() {
  // ── Distributors + credit accounts ─────────────────────
  const dists = [
    { id: 'seed-dist-1', name: 'Abebe Distribution', region: 'Addis', lat: 9.0200, lng: 38.7800, limit: 100_000, exposure: 25_000,  oldestDays: 5,  grace: 14 },
    { id: 'seed-dist-2', name: 'Bole Wholesale Co.',  region: 'Addis', lat: null, lng: null,       limit: 200_000, exposure: 250_000, oldestDays: 65, grace: 14 },
    { id: 'seed-dist-3', name: 'Kazanchis Distributors', region: 'Addis', lat: null, lng: null,    limit: 100_000, exposure: 90_000,  oldestDays: 5,  grace: 14 },
    { id: 'seed-dist-4', name: 'Sarbet Traders',      region: 'Addis', lat: null, lng: null,       limit: 100_000, exposure: 20_000,  oldestDays: 3,  grace: 14 },
    { id: 'seed-dist-5', name: 'CMC Retailers',       region: 'Addis', lat: null, lng: null,       limit: 200_000, exposure: 180_000, oldestDays: 25, grace: 14 },
  ];
  for (const d of dists) {
    await prisma.distributor.upsert({
      where: { id: d.id },
      create: { id: d.id, name: d.name, region: d.region, lat: d.lat, lng: d.lng },
      update: {},
    });
    await prisma.creditAccount.upsert({
      where: { distributorId: d.id },
      create: { distributorId: d.id, limitEtb: d.limit, exposureEtb: d.exposure, oldestUnpaidAt: daysAgo(d.oldestDays), graceDays: d.grace },
      update: {},
    });
  }

  // ── Vehicles ───────────────────────────────────────────
  const vehicles = [
    { id: 'V-101', plate: 'AA-3-B-101', capacityKg: 1500, capacityM3: 8, shiftStartH: 7, shiftEndH: 18, startLat: 9.0108, startLng: 38.7613, baselineLPer100Km: 12 },
    { id: 'V-102', plate: 'AA-3-B-102', capacityKg: 1500, capacityM3: 8, shiftStartH: 7, shiftEndH: 18, startLat: 9.0108, startLng: 38.7613, baselineLPer100Km: 12 },
    { id: 'V-103', plate: 'AA-3-B-103', capacityKg: 1000, capacityM3: 5, shiftStartH: 7, shiftEndH: 17, startLat: 9.0108, startLng: 38.7613, baselineLPer100Km: 10 },
  ];
  for (const v of vehicles) {
    await prisma.vehicle.upsert({ where: { id: v.id }, create: v, update: {} });
  }

  // ── SKUs ───────────────────────────────────────────────
  const skus = [
    { code: 'SKU-COKE-500',  name: 'Coca-Cola 500ml',  unit: 'each', weightKg: 0.6, volumeM3: 0.0008, unitPriceEtb: 30, stockOnHand: 500, reorderPoint: 50, safetyStock: 20, leadTimeDays: 3 },
    { code: 'SKU-PEPSI-500', name: 'Pepsi 500ml',      unit: 'each', weightKg: 0.6, volumeM3: 0.0008, unitPriceEtb: 28, stockOnHand: 300, reorderPoint: 40, safetyStock: 15, leadTimeDays: 3 },
    { code: 'SKU-WATER-1L',  name: 'Ambo Water 1L',    unit: 'each', weightKg: 1.1, volumeM3: 0.0012, unitPriceEtb: 18, stockOnHand: 200, reorderPoint: 30, safetyStock: 10, leadTimeDays: 2 },
    { code: 'SKU-BREAD',     name: 'White Bread Loaf', unit: 'each', weightKg: 0.4, volumeM3: 0.003,  unitPriceEtb: 15, stockOnHand: 60,  reorderPoint: 20, safetyStock: 10, leadTimeDays: 1 },
    { code: 'SKU-MILK-1L',   name: 'Family Milk 1L',   unit: 'each', weightKg: 1.0, volumeM3: 0.0011, unitPriceEtb: 45, stockOnHand: 100, reorderPoint: 25, safetyStock: 12, leadTimeDays: 2 },
  ];
  for (const s of skus) {
    await prisma.sku.upsert({ where: { code: s.code }, create: s, update: {} });
  }

  // ── Curfew zones ───────────────────────────────────────
  const zones = [
    { id: 'zone-merkato', name: 'Merkato Heavy Truck Ban',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7400,9.0300],[38.7550,9.0300],[38.7550,9.0400],[38.7400,9.0400],[38.7400,9.0300]]] },
      startHour: 7, endHour: 10, reason: 'Morning peak truck restriction', active: true },
    { id: 'zone-piassa', name: 'Piassa Central Ban',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7450,9.0280],[38.7600,9.0280],[38.7600,9.0380],[38.7450,9.0380],[38.7450,9.0280]]] },
      startHour: 17, endHour: 20, reason: 'Evening pedestrian zone', active: true },
    { id: 'zone-bole-overnight', name: 'Bole Overnight Restriction',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7800,8.9900],[38.8000,8.9900],[38.8000,9.0100],[38.7800,9.0100],[38.7800,8.9900]]] },
      startHour: 22, endHour: 6, reason: 'Overnight residential noise ban', active: true },
    { id: 'zone-old-airport', name: 'Old Airport (decommissioned)',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7500,8.9800],[38.7700,8.9800],[38.7700,9.0000],[38.7500,9.0000],[38.7500,8.9800]]] },
      startHour: 12, endHour: 14, reason: 'Lifted', active: false },
  ];
  for (const z of zones) {
    await prisma.curfewZone.upsert({ where: { id: z.id }, create: z as any, update: {} });
  }

  // ── Fuel stations ──────────────────────────────────────
  const stations = [
    { id: 'fuel-1', name: 'Bole Total',  lat: 8.9948, lng: 38.7923, status: 'operational' },
    { id: 'fuel-2', name: 'Mexico Nile', lat: 9.0100, lng: 38.7500, status: 'queued' },
    { id: 'fuel-3', name: 'CMC NOC',     lat: 9.0200, lng: 38.8300, status: 'operational' },
    { id: 'fuel-4', name: 'Sarbet Shell', lat: 8.9950, lng: 38.7600, status: 'dry' },
  ];
  for (const s of stations) {
    await prisma.fuelStation.upsert({ where: { id: s.id }, create: s as any, update: {} });
  }

  // ── Docks + slots ──────────────────────────────────────
  const docks = [{ id: 'dock-a', name: 'Dock A' }, { id: 'dock-b', name: 'Dock B' }, { id: 'dock-c', name: 'Dock C' }];
  for (const dock of docks) {
    await prisma.dispatchDock.upsert({ where: { id: dock.id }, create: dock, update: {} });
  }
  const slotWindows = [{ s: 6, e: 7 }, { s: 7, e: 8 }, { s: 8, e: 9 }, { s: 9, e: 10 }];
  for (const dock of docks) {
    for (let i = 0; i < slotWindows.length; i++) {
      const w = slotWindows[i]!;
      const id = `${dock.id}-slot-${i}`;
      await prisma.dispatchDockSlot.upsert({
        where: { id },
        create: {
          id, dockId: dock.id, date: dateOnly,
          startAt: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), w.s, 0, 0)),
          endAt:   new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), w.e, 0, 0)),
          status: 'AVAILABLE',
        },
        update: {},
      });
    }
  }

  // ── Pending orders (8) ────────────────────────────────
  const orders = [
    { id: 'seed-order-1', name: 'Bole Retail',       lat: 8.9948, lng: 38.7923, w: 80,  v: 0.4, pri: 8, ws: 8,  we: 12 },
    { id: 'seed-order-2', name: 'Kazanchis Mart',    lat: 9.0167, lng: 38.7667, w: 120, v: 0.6, pri: 6, ws: 9,  we: 13 },
    { id: 'seed-order-3', name: 'Piassa Traders',    lat: 9.0333, lng: 38.7500, w: 95,  v: 0.5, pri: 5, ws: 10, we: 14 },
    { id: 'seed-order-4', name: 'Merkato Wholesale', lat: 9.0348, lng: 38.7466, w: 200, v: 1.2, pri: 9, ws: 11, we: 15 },
    { id: 'seed-order-5', name: 'Saris Corner',      lat: 8.9900, lng: 38.7400, w: 60,  v: 0.3, pri: 4, ws: 10, we: 16 },
    { id: 'seed-order-6', name: 'CMC Store',         lat: 9.0200, lng: 38.8300, w: 150, v: 0.8, pri: 7, ws: 8,  we: 12 },
    { id: 'seed-order-7', name: 'Bole Medhanialem',  lat: 9.0050, lng: 38.7850, w: 70,  v: 0.35, pri: 6, ws: 9, we: 14 },
    { id: 'seed-order-8', name: 'Megenagna Shop',    lat: 9.0200, lng: 38.8000, w: 110, v: 0.6, pri: 5, ws: 10, we: 15 },
  ];
  for (const o of orders) {
    await prisma.order.upsert({
      where: { id: o.id },
      create: {
        id: o.id, distributorId: `seed-dist-${o.id.split('-').pop()}`, distributorName: o.name,
        lat: o.lat, lng: o.lng, weightKg: o.w, volumeM3: o.v, priority: o.pri,
        timeWindowStart: tw(o.ws), timeWindowEnd: tw(o.we), status: 'PENDING', totalQuantity: 10,
      },
      update: {},
    });
  }

  // ── Route 1: DISPATCHED (driver demo) ─────────────────
  const routeId = 'route-today-d201';
  const route = await prisma.routePlan.upsert({
    where: { id: routeId },
    create: {
      id: routeId, date: dateOnly, vehicleId: 'V-101', driverId: 'D-201',
      status: 'DISPATCHED', version: 1, plannedKm: 42.5, plannedMin: 240,
      startLat: 9.0108, startLng: 38.7613,
    },
    update: {},
  });
  const seedStops = [
    { seq: 1, name: 'Bole Retail',       lat: 8.9948, lng: 38.7923, qty: 10 },
    { seq: 2, name: 'Kazanchis Mart',    lat: 9.0167, lng: 38.7667, qty: 15 },
    { seq: 3, name: 'Piassa Traders',    lat: 9.0333, lng: 38.7500, qty: 12 },
    { seq: 4, name: 'Merkato Wholesale', lat: 9.0348, lng: 38.7466, qty: 25 },
    { seq: 5, name: 'Saris Corner',      lat: 8.9900, lng: 38.7400, qty: 8 },
  ];
  for (const s of seedStops) {
    const id = `${routeId}-stop-${s.seq}`;
    await prisma.routeStop.upsert({
      where: { id },
      create: {
        id, routePlanId: route.id, seq: s.seq,
        distributorId: `seed-dist-${s.seq}`, distributorName: s.name,
        lat: s.lat, lng: s.lng,
        plannedEta: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 8 + s.seq, 0, 0)),
        status: 'PENDING', quantityOrdered: s.qty, pickedAt: new Date(),
      },
      update: {},
    });
  }

  // ── Route 2: PLANNED, slot allocated (warehouse demo) ─
  const routeId2 = 'route-today-v102';
  const route2 = await prisma.routePlan.upsert({
    where: { id: routeId2 },
    create: {
      id: routeId2, date: dateOnly, vehicleId: 'V-102', driverId: 'D-202',
      status: 'PLANNED', version: 1, plannedKm: 38.2, plannedMin: 220,
      startLat: 9.0108, startLng: 38.7613,
    },
    update: {},
  });
  const stops2 = [
    { seq: 1, name: 'CMC Store',        lat: 9.0200, lng: 38.8300, qty: 12 },
    { seq: 2, name: 'Bole Medhanialem', lat: 9.0050, lng: 38.7850, qty: 8 },
    { seq: 3, name: 'Megenagna Shop',   lat: 9.0200, lng: 38.8000, qty: 15 },
    { seq: 4, name: 'Sarbet Retail',    lat: 8.9950, lng: 38.7600, qty: 10 },
  ];
  for (const s of stops2) {
    const id = `${routeId2}-stop-${s.seq}`;
    await prisma.routeStop.upsert({
      where: { id },
      create: {
        id, routePlanId: route2.id, seq: s.seq,
        distributorId: `seed-dist-v102-${s.seq}`, distributorName: s.name,
        lat: s.lat, lng: s.lng,
        plannedEta: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 8 + s.seq, 0, 0)),
        status: 'PENDING', quantityOrdered: s.qty,
      },
      update: {},
    });
  }
  await prisma.dispatchDockSlot.upsert({
    where: { id: 'dock-a-slot-0' },
    create: {
      id: 'dock-a-slot-0', dockId: 'dock-a', date: dateOnly,
      startAt: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 6, 0, 0)),
      endAt:   new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 7, 0, 0)),
      status: 'ALLOCATED', routePlanId: routeId2,
    },
    update: {},
  });

  // ── Route 3: yesterday, COMPLETED (finance demo) ──────
  const yesterday = dateOnly;
  const yId = 'route-yesterday-v103';
  const yRoute = await prisma.routePlan.upsert({
    where: { id: yId },
    create: {
      id: yId, date: new Date(yesterday.getTime() - 86_400_000),
      vehicleId: 'V-103', driverId: 'D-203',
      status: 'COMPLETED', version: 1, plannedKm: 30, plannedMin: 180,
      startLat: 9.0108, startLng: 38.7613,
    },
    update: {},
  });
  const yStops = [
    { seq: 1, name: 'Sarbet Retail',       qty: 10, amount: 500, method: 'CASH' as const, ref: null as string | null },
    { seq: 2, name: 'Old Airport Grocer',  qty: 15, amount: 750, method: 'CASH' as const, ref: null },
    { seq: 3, name: 'Haya Hulet Shop',     qty: 18, amount: 900, method: 'TELEBIRR' as const, ref: 'TB-SEED-DEMO-1' },
  ];
  for (const s of yStops) {
    const stopId = `${yId}-stop-${s.seq}`;
    await prisma.routeStop.upsert({
      where: { id: stopId },
      create: {
        id: stopId, routePlanId: yRoute.id, seq: s.seq,
        distributorId: `seed-dist-${s.seq}`, distributorName: s.name,
        lat: 9.0108, lng: 38.7613,
        plannedEta: new Date(yesterday.getTime() - 86_400_000 + (8 + s.seq) * 3600_000),
        status: 'DELIVERED', quantityOrdered: s.qty, pickedAt: daysAgo(2),
      },
      update: {},
    });
    await prisma.proofOfDelivery.upsert({
      where: { id: `proof-y-${s.seq}` },
      create: {
        id: `proof-y-${s.seq}`, routeStopId: stopId, outcome: 'DELIVERED',
        qtyConfirmed: s.qty, qtyOrdered: s.qty,
        signatureBase64: 'data:image/png;base64,seed',
        clientOpId: `seed-op-y-${s.seq}`, capturedAt: daysAgo(1),
      },
      update: {},
    });
    await prisma.payment.upsert({
      where: { id: `payment-y-${s.seq}` },
      create: {
        id: `payment-y-${s.seq}`, routeStopId: stopId,
        method: s.method, amountEtb: s.amount, telebirrRef: s.ref,
        clientOpId: `seed-pay-y-${s.seq}`, capturedAt: daysAgo(1),
      },
      update: {},
    });
  }

  // ── Demo fuel history ──────────────────────────────────
  const demoFills = [
    { id: 'seed-fuel-v101-1', vehicleId: 'V-101', liters: 60, amount: 620, odo: 44800, capturedDaysAgo: 4, flag: 'NO_BASELINE', ratio: null },
    { id: 'seed-fuel-v101-2', vehicleId: 'V-101', liters: 60, amount: 620, odo: 45300, capturedDaysAgo: 2, flag: 'OK', ratio: 1.0 },
    { id: 'seed-fuel-v102-1', vehicleId: 'V-102', liters: 55, amount: 570, odo: 32100, capturedDaysAgo: 4, flag: 'NO_BASELINE', ratio: null },
    { id: 'seed-fuel-v102-2', vehicleId: 'V-102', liters: 54, amount: 560, odo: 32550, capturedDaysAgo: 2, flag: 'OK', ratio: 1.0 },
    { id: 'seed-fuel-v103-1', vehicleId: 'V-103', liters: 50, amount: 520, odo: 51200, capturedDaysAgo: 3, flag: 'OK', ratio: 1.0 },
  ];
  for (const f of demoFills) {
    await prisma.fuelLog.upsert({
      where: { id: f.id },
      create: {
        id: f.id, driverId: 'D-201', vehicleId: f.vehicleId,
        liters: f.liters, amountEtb: f.amount, odometerKm: f.odo,
        stationName: 'Bole Total', varianceFlag: f.flag, varianceRatio: f.ratio,
        clientOpId: `seed-${f.id}`, capturedAt: daysAgo(f.capturedDaysAgo),
      },
      update: {},
    });
  }

  // ── Portal demo orders (2 pending + 1 delivered) ───────
  const skuByCode = new Map((await prisma.sku.findMany()).map((s) => [s.code, s]));
  const portalOrders = [
    { id: 'portal-order-1', daysAgo: 0, status: 'PENDING', lines: [{ code: 'SKU-COKE-500', qty: 50 }, { code: 'SKU-PEPSI-500', qty: 30 }] },
    { id: 'portal-order-2', daysAgo: 1, status: 'PENDING', lines: [{ code: 'SKU-WATER-1L', qty: 100 }, { code: 'SKU-BREAD', qty: 40 }] },
    { id: 'portal-order-3', daysAgo: 3, status: 'DELIVERED', lines: [{ code: 'SKU-MILK-1L', qty: 25 }] },
  ];
  for (const po of portalOrders) {
    const createdAt = daysAgo(po.daysAgo);
    const lines = po.lines.map((l) => {
      const sku = skuByCode.get(l.code)!;
      return {
        skuId: sku.id, skuCode: sku.code, skuName: sku.name,
        quantity: l.qty, unitPrice: Number(sku.unitPriceEtb), lineTotal: l.qty * Number(sku.unitPriceEtb),
        weightKg: l.qty * Number(sku.weightKg), volumeM3: l.qty * Number(sku.volumeM3),
      };
    });
    const totalQty = lines.reduce((s, l) => s + l.quantity, 0);
    const totalWeight = lines.reduce((s, l) => s + l.weightKg, 0);
    const totalVolume = lines.reduce((s, l) => s + l.volumeM3, 0);
    await prisma.order.upsert({
      where: { id: po.id },
      create: {
        id: po.id, distributorId: 'seed-dist-1', distributorName: 'Abebe Distribution',
        lat: 9.0200, lng: 38.7800, weightKg: totalWeight, volumeM3: totalVolume, priority: 5,
        timeWindowStart: new Date(createdAt.getTime() + 3600_000),
        timeWindowEnd: new Date(createdAt.getTime() + 86_400_000),
        status: po.status, totalQuantity: totalQty, createdAt,
        lines: { create: lines.map((l) => ({ skuId: l.skuId, skuCode: l.skuCode, skuName: l.skuName, quantity: l.quantity, unitPrice: l.unitPrice, lineTotal: l.lineTotal })) },
      },
      update: {},
    });
  }

  // ── Settings ───────────────────────────────────────────
  await prisma.setting.upsert({
    where: { key: 'credit.hardGate' }, create: { key: 'credit.hardGate', value: 'false' }, update: {},
  });
  await prisma.setting.upsert({
    where: { key: 'analytics.demoMode' }, create: { key: 'analytics.demoMode', value: 'true' }, update: {},
  });

  console.log('seed: ok');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
