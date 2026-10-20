import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CurfewZone, UpdateCurfewHours } from '../types';

interface Props { zone: CurfewZone; onSubmit: (b: UpdateCurfewHours) => void; onCancel: () => void; isSaving: boolean; error: string | null; }

export function CurfewHoursModal({ zone, onSubmit, onCancel, isSaving, error }: Props) {
  const { t } = useI18n();
  const [startHour, setStartHour] = useState(String(zone.start_hour));
  const [endHour, setEndHour] = useState(String(zone.end_hour));
  const [reason, setReason] = useState(zone.reason);
  const startNum = parseInt(startHour, 10); const endNum = parseInt(endHour, 10);
  const hoursValid = Number.isInteger(startNum) && startNum >= 0 && startNum <= 23 && Number.isInteger(endNum) && endNum >= 0 && endNum <= 23 && startNum !== endNum;
  const canSubmit = reason.trim().length > 0 && hoursValid && !isSaving;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-1">{t('admin.constraints.curfew.edit_title')}</h2>
        <p className="text-sm text-muted mb-4">{zone.name}</p>
        <div className="grid grid-cols-2 gap-3 mb-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.start_hour')}</span>
            <input type="number" min={0} max={23} value={startHour} onChange={(e) => setStartHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.end_hour')}</span>
            <input type="number" min={0} max={23} value={endHour} onChange={(e) => setEndHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        </div>
        <label className="block text-sm mb-4"><span className="text-muted block mb-1">{t('admin.constraints.curfew.reason')}</span>
          <input value={reason} onChange={(e) => setReason(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        {error && <p className="text-sm text-danger mb-3">{error}</p>}
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isSaving}>{t('common.cancel')}</Button>
          <Button onClick={() => onSubmit({ start_hour: startNum, end_hour: endNum, reason: reason.trim() })} disabled={!canSubmit} loading={isSaving}>{t('common.confirm')}</Button>
        </div>
      </div>
    </div>
  );
}
