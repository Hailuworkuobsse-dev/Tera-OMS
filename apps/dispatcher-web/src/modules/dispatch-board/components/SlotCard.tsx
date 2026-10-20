import { useI18n } from '@tera/i18n';
import { Button, StatusPill } from '@tera/ui';
import type { DockSlot } from '../types';

interface Props {
  slot: DockSlot;
  onConfirm: (slotId: string) => void;
  onDispatch: (routeId: string) => void;
  pendingAction: 'confirm' | 'dispatch' | null;
  disabled?: boolean;
}
function slotTone(status: DockSlot['status']): 'neutral' | 'warn' | 'success' {
  if (status === 'AVAILABLE') return 'neutral';
  if (status === 'ALLOCATED') return 'warn';
  return 'success';
}
export function SlotCard({ slot, onConfirm, onDispatch, pendingAction, disabled }: Props) {
  const { t } = useI18n();
  const time = (iso: string) => new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const statusLabel: Record<DockSlot['status'], string> = {
    AVAILABLE: t('dispatch.slot.available'), ALLOCATED: t('dispatch.slot.allocated'),
    CONFIRMED: t('dispatch.slot.confirmed'), COMPLETED: t('dispatch.slot.completed'),
  };
  const allPicked = slot.route ? slot.route.picked_count === slot.route.stop_count : false;
  return (
    <div className={`border rounded-md p-3 bg-surface ${slot.status === 'COMPLETED' ? 'opacity-70' : ''}`}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-medium tabular-nums">{time(slot.start_at)} – {time(slot.end_at)}</span>
        <StatusPill tone={slotTone(slot.status)}>{statusLabel[slot.status]}</StatusPill>
      </div>
      {slot.route ? (
        <>
          <div className="text-sm font-medium">{slot.route.vehicle_id}</div>
          <div className="text-xs text-muted">{slot.route.driver_id} · {slot.route.stop_count} {t('dispatch.stops')} · {slot.route.planned_km.toFixed(1)} km</div>
          <div className={`text-xs mt-1 ${allPicked ? 'text-success' : 'text-warn'}`}>
            {slot.route.picked_count} / {slot.route.stop_count} picked
          </div>
          <div className="mt-3 flex flex-col gap-1.5">
            {slot.status === 'ALLOCATED' && (
              <Button size="sm" disabled={disabled || pendingAction !== null || !allPicked} loading={pendingAction === 'confirm'} onClick={() => onConfirm(slot.id)}>
                {allPicked ? t('dispatch.confirm_loading') : t('dispatch.pick_first')}
              </Button>
            )}
            {(slot.status === 'CONFIRMED' || slot.status === 'COMPLETED') && slot.route.status === 'PLANNED' && (
              <Button size="sm" disabled={disabled || pendingAction !== null} loading={pendingAction === 'dispatch'} onClick={() => onDispatch(slot.route!.id)}>
                {t('dispatch.dispatch_route')}
              </Button>
            )}
            {slot.route.status === 'DISPATCHED' && (
              <div className="text-xs text-success font-medium">{t('dispatch.on_road')}</div>
            )}
          </div>
        </>
      ) : (
        <div className="text-xs text-muted">{t('dispatch.empty_slot')}</div>
      )}
    </div>
  );
}
