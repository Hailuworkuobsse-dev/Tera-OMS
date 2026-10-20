export interface GeoJsonPolygon {
  type: 'Polygon';
  coordinates: [number, number][][];
}

export function validateGeoJsonPolygon(polygon: unknown): string[] {
  const errors: string[] = [];
  if (!polygon || typeof polygon !== 'object') return ['polygon must be an object'];
  const p = polygon as Partial<GeoJsonPolygon>;
  if (p.type !== 'Polygon') errors.push('polygon.type must be "Polygon"');
  if (!Array.isArray(p.coordinates) || p.coordinates.length !== 1) {
    errors.push('polygon.coordinates must contain exactly one ring');
    return errors;
  }
  const ring = p.coordinates[0];
  if (!Array.isArray(ring)) { errors.push('ring must be array'); return errors; }
  if (ring.length < 4) { errors.push(`ring must have >=4 coords, got ${ring.length}`); return errors; }
  const first = ring[0]; const last = ring[ring.length - 1];
  if (!Array.isArray(first) || !Array.isArray(last) || first.length !== 2 || last.length !== 2) {
    errors.push('first and last must be [lng, lat]'); return errors;
  }
  if (first[0] !== last[0] || first[1] !== last[1]) errors.push('ring must be closed');
  for (let i = 0; i < ring.length; i++) {
    const c = ring[i];
    if (!Array.isArray(c) || c.length !== 2) { errors.push(`coord ${i} invalid`); continue; }
    const [lng, lat] = c;
    if (typeof lng !== 'number' || !Number.isFinite(lng) || lng < -180 || lng > 180) errors.push(`coord ${i}: lng ${lng} out of range`);
    if (typeof lat !== 'number' || !Number.isFinite(lat) || lat < -90 || lat > 90) errors.push(`coord ${i}: lat ${lat} out of range`);
  }
  return errors;
}

export function validateCurfewHours(input: { start_hour: number; end_hour: number }): string[] {
  const errors: string[] = [];
  if (!Number.isInteger(input.start_hour) || input.start_hour < 0 || input.start_hour > 23) errors.push('start_hour must be 0-23');
  if (!Number.isInteger(input.end_hour) || input.end_hour < 0 || input.end_hour > 23) errors.push('end_hour must be 0-23');
  if (input.start_hour === input.end_hour) errors.push('start_hour and end_hour must differ');
  return errors;
}
