import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { CurfewMapEditor } from './CurfewMapEditor';
import { CurfewSaveModal } from './CurfewSaveModal';
import { CurfewHoursModal } from './CurfewHoursModal';
import { useCurfews, useCreateCurfew, useUpdateCurfewHours, useToggleCurfewActive } from '../hooks';
import { isActiveNow, formatRange, type LatLng } from '../geo-utils';
import type { CurfewZone } from '../types';

export function CurfewsTab() {
  const { t } = useI18n();
  const [drawing, setDrawing] = useState(false);
  const [points, setPoints] = useState<LatLng[]>([]);
  const [showSave, setShowSave] = useState(false);
  const [editing, setEditing] = useState<CurfewZone | null>(null);
  const zonesQ = useCurfews(); const createMut = useCreateCurfew(); const hoursMut = useUpdateCurfewHours(); const toggleMut = useToggleCurfewActive();
  const zones = useMemo(() => zonesQ.data?.zones ?? [], [zonesQ.data]);
  return (
    <div>
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <p className="text-sm text-muted">{zones.length} {t('admin.constraints.curfew.count')}</p>
        <div className="flex gap-2">
          {!drawing && <Button onClick={() => { setDrawing(true); setPoints([]); setShowSave(false); }}>{t('admin.constraints.curfew.draw')}</Button>}
          {drawing && (<>
            <Button variant="ghost" onClick={() => setPoints((p) => p.slice(0, -1))} disabled={points.length === 0}>{t('admin.constraints.curfew.undo')}</Button>
            <Button variant="secondary" onClick={() => { setDrawing(false); setPoints([]); setShowSave(false); }}>{t('common.cancel')}</Button>
            <Button onClick={() => { if (points.length >= 3) setShowSave(true); }} disabled={points.length < 3}>{t('admin.constraints.curfew.save_points', { n: points.length })}</Button>
          </>)}
        </div>
      </div>
      {drawing && <div className="mb-3 text-sm bg-primary/5 border border-primary/30 rounded-md px-3 py-2">{t('admin.constraints.curfew.instructions')}</div>}
      <div className="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-4">
        <div className="min-h-[500px]">
          <CurfewMapEditor zones={zones} drawing={drawing} drawingPoints={points} onAddPoint={(p) => setPoints((prev) => [...prev, p])} />
        </div>
        <aside className="flex flex-col gap-2">
          <div className="text-sm font-semibold text-muted uppercase tracking-wide px-1 mb-1">{t('admin.constraints.curfew.zones')}</div>
          {zonesQ.isLoading && <Spinner label={t('common.loading')} />}
          {zonesQ.isError && <div className="text-sm text-danger border border-danger/30 bg-dangerBg rounded-md p-3">{t('common.error')}</div>}
          {!zonesQ.isLoading && !zonesQ.isError && zones.length === 0 && <EmptyState title={t('admin.constraints.curfew.none')} />}
          {zones.map((z) => {
            const activeNow = z.active && isActiveNow(z.start_hour, z.end_hour);
            return (
              <div key={z.id} className={`border rounded-md p-3 bg-surface ${z.active ? 'border-border' : 'border-border opacity-60'}`}>
                <div className="flex items-center justify-between mb-1">
                  <span className="font-medium text-sm">{z.name}</span>
                  <StatusPill tone={!z.active ? 'neutral' : activeNow ? 'danger' : 'warn'}>{!z.active ? t('admin.constraints.curfew.inactive') : activeNow ? t('admin.constraints.curfew.active_now') : t('admin.constraints.curfew.scheduled')}</StatusPill>
                </div>
                <div className="text-xs text-muted">{formatRange(z.start_hour, z.end_hour)}</div>
                <div className="text-xs text-muted mt-1 italic">"{z.reason}"</div>
                <div className="flex gap-1 mt-2">
                  <Button size="sm" variant="ghost" onClick={() => setEditing(z)}>{t('admin.constraints.curfew.edit_hours')}</Button>
                  <Button size="sm" variant={z.active ? 'ghost' : 'secondary'} onClick={() => toggleMut.mutate({ id: z.id, active: !z.active })} disabled={toggleMut.isPending}>{z.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button>
                </div>
              </div>
            );
          })}
        </aside>
      </div>
      {showSave && points.length >= 3 && <CurfewSaveModal points={points} onSubmit={(b) => createMut.mutate(b, { onSuccess: () => { setDrawing(false); setPoints([]); setShowSave(false); } })} onCancel={() => setShowSave(false)} isSaving={createMut.isPending} error={createMut.isError ? (createMut.error as Error).message : null} />}
      {editing && <CurfewHoursModal zone={editing} onSubmit={(b) => hoursMut.mutate({ id: editing.id, body: b }, { onSuccess: () => setEditing(null) })} onCancel={() => setEditing(null)} isSaving={hoursMut.isPending} error={hoursMut.isError ? (hoursMut.error as Error).message : null} />}
    </div>
  );
}
