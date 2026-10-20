import { describe, it, expect } from 'vitest';
import { validateGeoJsonPolygon, validateCurfewHours } from '../validation.js';

const VALID = { type: 'Polygon' as const, coordinates: [[
  [38.74, 9.03] as [number, number], [38.76, 9.03] as [number, number],
  [38.76, 9.04] as [number, number], [38.74, 9.04] as [number, number],
  [38.74, 9.03] as [number, number],
]]};

describe('validateGeoJsonPolygon', () => {
  it('accepts valid closed polygon', () => expect(validateGeoJsonPolygon(VALID)).toEqual([]));
  it('rejects null', () => expect(validateGeoJsonPolygon(null).length).toBeGreaterThan(0));
  it('rejects wrong type', () => expect(validateGeoJsonPolygon({ type: 'LineString', coordinates: [] }).some((e) => e.includes('Polygon'))).toBe(true));
  it('rejects unclosed ring', () => {
    const bad = { type: 'Polygon', coordinates: [[[38.74, 9.03], [38.76, 9.03], [38.76, 9.04], [38.74, 9.04]]] };
    expect(validateGeoJsonPolygon(bad).some((e) => e.includes('closed'))).toBe(true);
  });
  it('rejects out-of-range lat', () => {
    const bad = { type: 'Polygon', coordinates: [[[38.74, 9.03], [38.76, 95], [38.76, 9.04], [38.74, 9.03]]] };
    expect(validateGeoJsonPolygon(bad).some((e) => e.includes('lat'))).toBe(true);
  });
});

describe('validateCurfewHours', () => {
  it('accepts standard', () => expect(validateCurfewHours({ start_hour: 7, end_hour: 10 })).toEqual([]));
  it('accepts overnight', () => expect(validateCurfewHours({ start_hour: 22, end_hour: 6 })).toEqual([]));
  it('rejects out of range', () => expect(validateCurfewHours({ start_hour: -1, end_hour: 5 }).length).toBeGreaterThan(0));
  it('rejects equal', () => expect(validateCurfewHours({ start_hour: 8, end_hour: 8 }).length).toBeGreaterThan(0));
});
