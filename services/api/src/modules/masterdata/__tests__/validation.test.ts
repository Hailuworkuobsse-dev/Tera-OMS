import { describe, it, expect } from 'vitest';
import { validateDistributorShape, validateVehicleShape, validateSkuShape, parseNumber, parseInt2 } from '../validation.js';

describe('parseNumber / parseInt2', () => {
  it('parses decimals', () => { expect(parseNumber('12.5')).toBe(12.5); expect(parseNumber('')).toBeNull(); });
  it('parseInt2 rejects non-integers', () => { expect(parseInt2('5')).toBe(5); expect(parseInt2('5.5')).toBeNull(); });
});

describe('validateDistributorShape', () => {
  it('accepts', () => expect(validateDistributorShape({ name: 'A', region: 'B' })).toEqual([]));
  it('rejects empty name', () => expect(validateDistributorShape({ name: '', region: 'B' })).toContain('name is required'));
});
describe('validateVehicleShape', () => {
  const good = { plate: 'AA', capacity_kg: '1500', capacity_m3: '8', shift_start_h: '7', shift_end_h: '18', start_lat: '9', start_lng: '38', baseline_l_per_100km: '12' };
  it('accepts', () => expect(validateVehicleShape(good)).toEqual([]));
  it('rejects bad shift', () => expect(validateVehicleShape({ ...good, shift_end_h: '6' }).length).toBeGreaterThan(0));
});
describe('validateSkuShape', () => {
  const good = { code: 'X', name: 'Y', unit: 'each', weight_kg: '0.5', volume_m3: '0.001', reorder_point: '10', safety_stock: '5', lead_time_days: '3' };
  it('accepts', () => expect(validateSkuShape(good)).toEqual([]));
  it('rejects zero weight', () => expect(validateSkuShape({ ...good, weight_kg: '0' }).length).toBeGreaterThan(0));
});
