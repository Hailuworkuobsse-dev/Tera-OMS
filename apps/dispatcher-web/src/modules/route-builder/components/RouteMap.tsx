import { useEffect } from 'react';
import { MapContainer, TileLayer, Polyline, CircleMarker } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { SolveResponse } from '../types';

delete (L.Icon.Default.prototype as any)._getIconUrl;
interface Props { solution: SolveResponse; start: { lat: number; lng: number } }
export function RouteMap({ solution, start }: Props) {
  useEffect(() => {
    const t = setTimeout(() => window.dispatchEvent(new Event('resize')), 150);
    return () => clearTimeout(t);
  }, []);
  const buildLine = (seq: typeof solution.manual) => [
    [start.lat, start.lng] as [number, number],
    ...seq.stops.map((s) => [s.lat, s.lng] as [number, number]),
  ];
  return (
    <div className="w-full h-[340px] rounded-md overflow-hidden border border-border">
      <MapContainer center={[start.lat, start.lng]} zoom={12} style={{ width: '100%', height: '100%' }}>
        <TileLayer attribution='&copy; OpenStreetMap' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        <Polyline positions={buildLine(solution.manual)} pathOptions={{ color: '#6b6b6b', weight: 3, dashArray: '6 6', opacity: 0.7 }} />
        <Polyline positions={buildLine(solution.optimized)} pathOptions={{ color: '#0f766e', weight: 4, opacity: 1 }} />
        <CircleMarker center={[start.lat, start.lng]} radius={9} pathOptions={{ color: '#0f766e', fillColor: '#0f766e', fillOpacity: 1 }} />
        {solution.optimized.stops.map((s) => (
          <CircleMarker key={s.order_id} center={[s.lat, s.lng]} radius={6}
            pathOptions={{ color: '#0f766e', fillColor: '#fff', fillOpacity: 1, weight: 2 }} />
        ))}
      </MapContainer>
    </div>
  );
}
