export interface SourceData {
  routePlans: { plannedKm: number; plannedMin: number; status: string }[];
  deliveredStops: { statusUpdatedAt: Date; plannedEta: Date }[];
  fuelCostEtb: number; highVar: number; routeCount: number; proofCount: number;
  blocked: number; blockedDispatched: number; stockoutDays: number;
  confirmedSlots: { startAt: Date; confirmedAt: Date }[];
  vehicles: number; days: number; wearRate: number;
}
const r2 = (n: number) => Math.round(n * 100) / 100;
const avg = (xs: number[]) => (xs.length === 0 ? 0 : xs.reduce((s, x) => s + x, 0) / xs.length);
const med = (xs: number[]) => { if (!xs.length) return 0; const s = [...xs].sort((a, b) => a - b); const m = Math.floor(s.length / 2); return s.length % 2 === 0 ? (s[m - 1]! + s[m]!) / 2 : s[m]!; };
export const computeVariableCostEtb = (d: SourceData) => (d.routePlans.length === 0 && d.fuelCostEtb === 0 ? null : Math.round(d.fuelCostEtb + d.routePlans.reduce((s, r) => s + r.plannedKm, 0) * d.wearRate));
export const computeKmPerDelivery = (d: SourceData) => (d.deliveredStops.length === 0 ? null : r2(d.routePlans.reduce((s, r) => s + r.plannedKm, 0) / d.deliveredStops.length));
export const computeMedianDeliveryHours = (d: SourceData) => { const m = d.routePlans.filter((r) => r.status !== 'PLANNED').map((r) => r.plannedMin); return m.length === 0 ? null : r2(med(m) / 60); };
export const computeOnTimeSlaPct = (d: SourceData) => (d.deliveredStops.length === 0 ? null : r2((d.deliveredStops.filter((s) => s.statusUpdatedAt <= s.plannedEta).length / d.deliveredStops.length) * 100));
export const computeStockoutSkuDays = (d: SourceData) => d.stockoutDays;
export const computeDockTurnaroundMinutes = (d: SourceData) => (d.confirmedSlots.length === 0 ? null : r2(avg(d.confirmedSlots.map((s) => (s.confirmedAt.getTime() - s.startAt.getTime()) / 60_000))));
export const computeReserveViolations = (d: SourceData) => (d.routeCount === 0 ? null : r2((d.highVar / d.routeCount) * 100));
export const computeDeliveriesPerVehiclePerDay = (d: SourceData) => (d.vehicles === 0 || d.days === 0 ? null : r2(d.deliveredStops.length / d.vehicles / d.days));
export const computeCleanEpodRatePct = (d: SourceData) => (d.deliveredStops.length === 0 ? null : r2(Math.min(100, (d.proofCount / d.deliveredStops.length) * 100)));
export const computeCreditBlockedPreDispatchPct = (d: SourceData) => (d.blocked === 0 ? 100 : r2(((d.blocked - d.blockedDispatched) / d.blocked) * 100));
