import { useEffect } from 'react';
import { MapContainer, TileLayer, Polyline, CircleMarker, Polygon, Popup, Marker } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { RoutePlan, CurfewZone, FuelStation } from '../types';

delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

const ROUTE_COLORS = ['#0f766e', '#b45309', '#7c3aed', '#0891b2', '#be123c'];
const FALLBACK_CENTER: [number, number] = [9.0108, 38.7613];

function geoJsonToLatLngs(geojson: CurfewZone['polygon']): [number, number][] {
  return geojson.coordinates[0]!.map(([lng, lat]) => [lat, lng] as [number, number]);
}
interface Props {
  routes: RoutePlan[]; curfewZones: CurfewZone[]; fuelStations: FuelStation[];
  selectedRouteId: string | null;
  onSelectRoute: (id: string) => void;
}
export function MapCanvas({ routes, curfewZones, fuelStations, selectedRouteId, onSelectRoute }: Props) {
  useEffect(() => {
    const t = setTimeout(() => window.dispatchEvent(new Event('resize')), 200);
    return () => clearTimeout(t);
  }, []);
  return (
    <div className="w-full h-full min-h-[500px] rounded-md overflow-hidden border border-border">
      <MapContainer center={FALLBACK_CENTER} zoom={12} style={{ width: '100%', height: '100%' }}>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {curfewZones.map((z) => (
          <Polygon key={z.id} positions={geoJsonToLatLngs(z.polygon)}
            pathOptions={{ color: '#b91c1c', fillOpacity: 0.12, weight: 1.5, dashArray: '4 4' }}>
            <Popup><strong>{z.name}</strong><br />{String(z.start_hour).padStart(2, '0')}:00 – {String(z.end_hour).padStart(2, '0')}:00<br /><em>{z.reason}</em></Popup>
          </Polygon>
        ))}
        {routes.map((route, i) => {
          const color = ROUTE_COLORS[i % ROUTE_COLORS.length]!;
          const positions: [number, number][] = [
            [route.start_lat, route.start_lng],
            ...route.stops.map((s) => [s.lat, s.lng] as [number, number]),
          ];
          const isSelected = route.id === selectedRouteId;
          return (
            <div key={route.id}>
              <Polyline positions={positions}
                pathOptions={{ color, weight: isSelected ? 5 : 3, opacity: isSelected ? 1 : 0.65 }}
                eventHandlers={{ click: () => onSelectRoute(route.id) }} />
              <CircleMarker center={[route.start_lat, route.start_lng]} radius={8}
                pathOptions={{ color, fillColor: color, fillOpacity: 1 }}>
                <Popup>Vehicle {route.vehicle_id} · start</Popup>
              </CircleMarker>
              {route.stops.map((s) => (
                <CircleMarker key={s.id} center={[s.lat, s.lng]}
                  radius={s.status === 'DELIVERED' ? 5 : 7}
                  pathOptions={{
                    color: s.status === 'DELIVERED' ? '#6b6b6b' : color,
                    fillColor: s.status === 'DELIVERED' ? '#a3a3a3' : '#ffffff',
                    fillOpacity: 1, weight: 2,
                  }}>
                  <Popup><strong>{s.distributor_name}</strong><br />Seq {s.seq} · {s.status}</Popup>
                </CircleMarker>
              ))}
            </div>
          );
        })}
        {fuelStations.map((f) => (
          <Marker key={f.id} position={[f.lat, f.lng]}>
            <Popup><strong>{f.name}</strong><br />{f.status}</Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
