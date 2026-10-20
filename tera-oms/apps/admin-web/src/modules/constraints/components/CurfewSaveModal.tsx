import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreateCurfewZone } from '../types';
import { toGeoJson, type LatLng } from '../geo-utils';

interface Props { points: LatLng[]; onSubmit: (b: CreateCurfewZone) => void; onCancel: () => void; isSaving: boolean; error: string | null; }

export function CurfewSaveModal({ points, onSubmit, onCancel, isSaving, error }: Props) {
  const { t } = useI18n();
  const [name, setName] = useState(''); const [reason, setReason] = useState('');
  const [startHour, setStartHour] = useState('7'); const [endHour, setEndHour] = useState('10');
  const startNum = parseInt(startHour, 10); const endNum = parseInt(endHour, 10);
  const hoursValid = Number.isInteger(startNum) && startNum >= 0 && startNum <= 23 && Number.isInteger(endNum) && endNum >= 0 && endNum <= 23 && startNum !== endNum;
  const canSubmit = name.trim().length > 0 && reason.trim().length > 0 && hoursValid && !isSaving;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-1">{t('admin.constraints.curfew.save_title')}</h2>
        <p className="text-sm text-muted mb-4">{points.length} {t('admin.constraints.curfew.points')}</p>
        <label className="block text-sm mb-3"><span className="text-muted block mb-1">{t('admin.constraints.curfew.name')}</span>
          <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        <div className="grid grid-cols-2 gap-3 mb-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.start_hour')}</span>
            <input type="number" min={0} max={23} value={startHour} onChange={(e) => setStartHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.end_hour')}</span>
            <input type="number" min={0} max={23} value={endHour} onChange={(e) => setEndHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        </div>
        {!hoursValid && <p className="text-xs text-danger mb-3">{t('admin.constraints.curfew.hours_hint')}</p>}
        <label className="block text-sm mb-4"><span className="text-muted block mb-1">{t('admin.constraints.curfew.reason')}</span>
          <input value={reason} onChange={(e) => setReason(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        {error && <p className="text-sm text-danger mb-3">{error}</p>}
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isSaving}>{t('common.cancel')}</Button>
          <Button onClick={() => { if (!canSubmit) return; try { onSubmit({ name: name.trim(), polygon: toGeoJson(points), start_hour: startNum, end_hour: endNum, reason: reason.trim() }); } catch { /* */ } }} disabled={!canSubmit} loading={isSaving}>{t('common.confirm')}</Button>
        </div>
      </div>
    </div>
  );
}
