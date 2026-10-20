import { describe, it, expect } from 'vitest';
import { computeVariableCostEtb, computeKmPerDelivery, computeOnTimeSlaPct, computeCreditBlockedPreDispatchPct } from '../metric-computers.js';
const base = { routePlans: [], deliveredStops: [], fuelCostEtb: 0, highVar: 0, routeCount: 0, proofCount: 0, blocked: 0, blockedDispatched: 0, stockoutDays: 0, confirmedSlots: [], vehicles: 0, days: 0, wearRate: 3.5 };
describe('metric computers', () => {
  it('variable cost null on empty', () => expect(computeVariableCostEtb(base)).toBeNull());
  it('variable cost = fuel + wear', () => expect(computeVariableCostEtb({ ...base, fuelCostEtb: 100_000, routePlans: [{ plannedKm: 500, plannedMin: 240, status: 'DISPATCHED' }] })).toBe(101_750));
  it('km per delivery', () => expect(computeKmPerDelivery({ ...base, routePlans: [{ plannedKm: 100, plannedMin: 60, status: 'DISPATCHED' }], deliveredStops: [{ statusUpdatedAt: new Date(), plannedEta: new Date() }, { statusUpdatedAt: new Date(), plannedEta: new Date() }] })).toBe(50));
  it('on-time SLA', () => { const eta = new Date('2026-04-12T10:00:00Z'); expect(computeOnTimeSlaPct({ ...base, deliveredStops: [{ statusUpdatedAt: new Date('2026-04-12T09:55:00Z'), plannedEta: eta }, { statusUpdatedAt: new Date('2026-04-12T10:30:00Z'), plannedEta: eta }] })).toBe(50); });
  it('credit 100 when no blocks', () => expect(computeCreditBlockedPreDispatchPct(base)).toBe(100));
});
