import { useEffect } from 'react';
import { MapContainer, TileLayer, Polygon, Polyline, CircleMarker, Popup, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { CurfewZone } from '../types';
import { fromGeoJson, isActiveNow, formatRange, type LatLng } from '../geo-utils';

delete (L.Icon.Default.prototype as any)._getIconUrl;
const CENTER: LatLng = [9.0108, 38.7613];

interface Props {
  zones: CurfewZone[];
  drawing: boolean;
  drawingPoints: LatLng[];
  onAddPoint: (p: LatLng) => void;
}
export function CurfewMapEditor({ zones, drawing, drawingPoints, onAddPoint }: Props) {
  useEffect(() => { const t = setTimeout(() => window.dispatchEvent(new Event('resize')), 200); return () => clearTimeout(t); }, []);
  return (
    <div className="w-full h-full min-h-[500px] rounded-md overflow-hidden border border-border relative">
      <MapContainer center={CENTER} zoom={12} style={{ width: '100%', height: '100%' }}>
        <TileLayer attribution='&copy; OpenStreetMap' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        {zones.map((z) => {
          const positions = fromGeoJson(z.polygon);
          const activeNow = z.active && isActiveNow(z.start_hour, z.end_hour);
          const pathOptions = !z.active
            ? { color: '#6b6b6b', fillColor: '#6b6b6b', fillOpacity: 0.08, weight: 1.5, dashArray: '2 4' }
            : activeNow ? { color: '#b91c1c', fillColor: '#b91c1c', fillOpacity: 0.25, weight: 3 }
              : { color: '#b91c1c', fillColor: '#b91c1c', fillOpacity: 0.1, weight: 2, dashArray: '4 4' };
          return (
            <Polygon key={z.id} positions={positions} pathOptions={pathOptions}>
              <Popup><div className="text-sm"><strong>{z.name}</strong><br />{formatRange(z.start_hour, z.end_hour)}<br /><em className="text-xs">{z.reason}</em><br /><span className="text-xs">{!z.active ? '⏸ Inactive' : activeNow ? '● Active now' : '○ Scheduled'}</span></div></Popup>
            </Polygon>
          );
        })}
        {drawing && (
          <>
            {drawingPoints.length >= 3 && <Polygon positions={drawingPoints} pathOptions={{ color: '#0f766e', fillColor: '#0f766e', fillOpacity: 0.2, weight: 2, dashArray: '6 4' }} />}
            {drawingPoints.length === 2 && <Polyline positions={drawingPoints} pathOptions={{ color: '#0f766e', weight: 2, dashArray: '6 4' }} />}
            {drawingPoints.map((p, i) => <CircleMarker key={i} center={p} radius={7} pathOptions={{ color: '#0f766e', fillColor: '#0f766e', fillOpacity: 1, weight: 2 }}><Popup>Point {i + 1}</Popup></CircleMarker>)}
            <ClickCatcher onAddPoint={onAddPoint} />
          </>
        )}
      </MapContainer>
    </div>
  );
}
function ClickCatcher({ onAddPoint }: { onAddPoint: (p: LatLng) => void }) {
  useMapEvents({ click: (e) => onAddPoint([e.latlng.lat, e.latlng.lng]) });
  return null;
}
