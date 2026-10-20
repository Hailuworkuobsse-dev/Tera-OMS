import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreateFuelStation, FuelStationStatus } from '../types';
interface Props { onSubmit: (b: CreateFuelStation) => void; onCancel: () => void; isSaving: boolean; error: string | null; }
export function AddStationModal({ onSubmit, onCancel, isSaving, error }: Props) {
  const { t } = useI18n();
  const [name, setName] = useState(''); const [lat, setLat] = useState('9.0108'); const [lng, setLng] = useState('38.7613'); const [status, setStatus] = useState<FuelStationStatus>('operational');
  const latNum = parseFloat(lat); const lngNum = parseFloat(lng);
  const valid = name.trim().length > 0 && Number.isFinite(latNum) && latNum >= -90 && latNum <= 90 && Number.isFinite(lngNum) && lngNum >= -180 && lngNum <= 180;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-4">{t('admin.constraints.station.add_title')}</h2>
        <label className="block text-sm mb-3"><span className="text-muted block mb-1">{t('admin.constraints.station.name')}</span>
          <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        <div className="grid grid-cols-2 gap-3 mb-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.station.lat')}</span>
            <input type="number" step="0.0001" value={lat} onChange={(e) => setLat(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.station.lng')}</span>
            <input type="number" step="0.0001" value={lng} onChange={(e) => setLng(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        </div>
        <label className="block text-sm mb-4"><span className="text-muted block mb-1">{t('admin.constraints.station.status')}</span>
          <select value={status} onChange={(e) => setStatus(e.target.value as FuelStationStatus)} className="w-full rounded-md border border-border bg-bg px-3 py-2">
            <option value="operational">{t('admin.constraints.station.status.operational')}</option>
            <option value="queued">{t('admin.constraints.station.status.queued')}</option>
            <option value="dry">{t('admin.constraints.station.status.dry')}</option>
          </select>
        </label>
        {error && <p className="text-sm text-danger mb-3">{error}</p>}
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isSaving}>{t('common.cancel')}</Button>
          <Button onClick={() => onSubmit({ name: name.trim(), lat: latNum, lng: lngNum, status })} disabled={!valid} loading={isSaving}>{t('common.confirm')}</Button>
        </div>
      </div>
    </div>
  );
}
