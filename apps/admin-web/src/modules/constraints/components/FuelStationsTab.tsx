import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { AddStationModal } from './AddStationModal';
import { useStations, useCreateStation, useSetStationStatus, useToggleStationActive } from '../hooks';
import type { FuelStationStatus } from '../types';

const CENTER: [number, number] = [9.0108, 38.7613];
function statusTone(s: FuelStationStatus): 'success' | 'warn' | 'danger' { return s === 'operational' ? 'success' : s === 'queued' ? 'warn' : 'danger'; }
function statusColor(s: FuelStationStatus, active: boolean): string { if (!active) return '#9a9a9a'; return s === 'operational' ? '#166534' : s === 'queued' ? '#b45309' : '#b91c1c'; }

export function FuelStationsTab() {
  const { t } = useI18n();
  const [showAdd, setShowAdd] = useState(false);
  const stationsQ = useStations(); const createMut = useCreateStation(); const statusMut = useSetStationStatus(); const toggleMut = useToggleStationActive();
  const stations = useMemo(() => stationsQ.data?.stations ?? [], [stationsQ.data]);
  const activeStations = stations.filter((s) => s.active);
  if (stationsQ.isLoading) return <Spinner label={t('common.loading')} />;
  if (stationsQ.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div>
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <p className="text-sm text-muted">{stations.length} {t('admin.constraints.station.count')}</p>
        <Button onClick={() => setShowAdd(true)}>{t('admin.md.add')}</Button>
      </div>
      {activeStations.length > 0 && (
        <div className="mb-4 rounded-md overflow-hidden border border-border h-[280px]">
          <MapContainer center={CENTER} zoom={12} style={{ width: '100%', height: '100%' }}>
            <TileLayer attribution='&copy; OpenStreetMap' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
            {activeStations.map((s) => <CircleMarker key={s.id} center={[s.lat, s.lng]} radius={10} pathOptions={{ color: statusColor(s.status, s.active), fillColor: statusColor(s.status, s.active), fillOpacity: 0.7, weight: 2 }}>
              <Popup><strong>{s.name}</strong><br /><span className="text-xs">{s.status}</span></Popup>
            </CircleMarker>)}
          </MapContainer>
        </div>
      )}
      {stations.length === 0 ? <EmptyState title={t('admin.constraints.station.none')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.constraints.station.name')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">Lat, Lng</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.constraints.station.status')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead>
          <tbody>{stations.map((s) => (
            <tr key={s.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-medium">{s.name}</td>
              <td className="px-4 py-3 text-right tabular-nums text-xs text-muted">{s.lat.toFixed(4)}, {s.lng.toFixed(4)}</td>
              <td className="px-4 py-3"><div className="flex items-center gap-2">
                <select value={s.status} onChange={(e) => statusMut.mutate({ id: s.id, status: e.target.value as FuelStationStatus })} disabled={statusMut.isPending || !s.active} className="rounded-md border border-border bg-bg px-2 py-1 text-sm">
                  <option value="operational">{t('admin.constraints.station.status.operational')}</option>
                  <option value="queued">{t('admin.constraints.station.status.queued')}</option>
                  <option value="dry">{t('admin.constraints.station.status.dry')}</option>
                </select>
                <StatusPill tone={statusTone(s.status)}>{s.status}</StatusPill>
              </div></td>
              <td className="px-4 py-3"><StatusPill tone={s.active ? 'success' : 'neutral'}>{s.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
              <td className="px-4 py-3 text-right"><Button size="sm" variant={s.active ? 'ghost' : 'secondary'} onClick={() => toggleMut.mutate({ id: s.id, active: !s.active })} disabled={toggleMut.isPending}>{s.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
      {showAdd && <AddStationModal onSubmit={(b) => createMut.mutate(b, { onSuccess: () => setShowAdd(false) })} onCancel={() => setShowAdd(false)} isSaving={createMut.isPending} error={createMut.isError ? (createMut.error as Error).message : null} />}
    </div>
  );
}
