import { useI18n } from '@tera/i18n';
import { Button, StatusPill } from '@tera/ui';
import type { DockSlot } from '../types';

export function SlotCard({ slot, onConfirm, isConfirming }: { slot: DockSlot; onConfirm: (id: string) => void; isConfirming: boolean }) {
  const { t } = useI18n();
  const time = (iso: string) => new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const route = slot.route;
  const allPicked = route ? route.picked_count === route.stop_count : false;
  const canConfirm = slot.status === 'ALLOCATED' && allPicked;
  if (slot.status !== 'ALLOCATED' && slot.status !== 'CONFIRMED') return null;
  return (
    <div className={`border rounded-lg bg-surface p-4 ${slot.status === 'CONFIRMED' ? 'border-success/40' : 'border-warn/40'}`}>
      <div className="flex items-center justify-between mb-3">
        <span className="text-lg font-semibold tabular-nums">{time(slot.start_at)} – {time(slot.end_at)}</span>
        <StatusPill tone={slot.status === 'ALLOCATED' ? 'warn' : 'success'}>
          {slot.status === 'ALLOCATED' ? t('dispatch.slot.allocated') : t('dispatch.slot.confirmed')}
        </StatusPill>
      </div>
      {route ? (
        <>
          <div className="text-base font-medium mb-1">{route.vehicle_id}</div>
          <div className="text-sm text-muted mb-2">{route.driver_id} · {route.stop_count} {t('dispatch.stops')} · {route.planned_km.toFixed(1)} km</div>
          <div className={`text-sm mb-3 ${allPicked ? 'text-success' : 'text-warn'}`}>{route.picked_count} / {route.stop_count} {t('warehouse.dock.picked_label')}</div>
          {slot.status === 'ALLOCATED' && (
            <Button size="lg" disabled={!canConfirm || isConfirming} loading={isConfirming} onClick={() => onConfirm(slot.id)} className="w-full">
              {allPicked ? t('warehouse.dock.confirm_loading') : t('warehouse.dock.pick_first')}
            </Button>
          )}
          {slot.status === 'CONFIRMED' && <div className="text-sm text-success font-medium">✓ {t('warehouse.dock.awaiting_dispatch')}</div>}
        </>
      ) : <div className="text-sm text-muted">{t('dispatch.empty_slot')}</div>}
    </div>
  );
}
