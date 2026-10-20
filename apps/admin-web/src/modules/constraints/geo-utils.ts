export type LatLng = [number, number];
export interface GeoJsonPolygon { type: 'Polygon'; coordinates: [number, number][][]; }
export function toGeoJson(points: LatLng[]): GeoJsonPolygon {
  if (points.length < 3) throw new Error('polygon needs at least 3 points');
  const ring: [number, number][] = points.map(([lat, lng]) => [lng, lat]);
  ring.push(ring[0]!);
  return { type: 'Polygon', coordinates: [ring] };
}
export function fromGeoJson(geojson: GeoJsonPolygon): LatLng[] {
  const ring = geojson.coordinates[0] ?? [];
  return ring.slice(0, -1).map(([lng, lat]) => [lat, lng] as LatLng);
}
export function isActiveNow(startHour: number, endHour: number, now = new Date()): boolean {
  const h = now.getHours();
  if (startHour <= endHour) return h >= startHour && h < endHour;
  return h >= startHour || h < endHour;
}
export function formatHour(h: number): string { return `${String(h).padStart(2, '0')}:00`; }
export function formatRange(startH: number, endH: number): string { return `${formatHour(startH)} – ${formatHour(endH)}`; }
