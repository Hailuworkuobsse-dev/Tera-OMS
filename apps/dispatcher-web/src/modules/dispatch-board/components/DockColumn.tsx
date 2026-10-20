import { useI18n } from '@tera/i18n';
import { SlotCard } from './SlotCard';
import type { Dock } from '../types';
interface Props {
  dock: Dock;
  onConfirm: (slotId: string) => void;
  onDispatch: (routeId: string) => void;
  pendingAction: { slotId?: string; routeId?: string; kind: 'confirm' | 'dispatch' } | null;
  disabled?: boolean;
}
export function DockColumn({ dock, onConfirm, onDispatch, pendingAction, disabled }: Props) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-2">
      <div className="text-sm font-semibold px-1 pb-1 border-b border-border">{dock.name}</div>
      {dock.slots.length === 0 ? (
        <div className="text-xs text-muted px-1">{t('dispatch.no_slots')}</div>
      ) : (
        dock.slots.map((slot) => (
          <SlotCard key={slot.id} slot={slot} onConfirm={onConfirm} onDispatch={onDispatch}
            pendingAction={pendingAction?.kind === 'confirm' && pendingAction.slotId === slot.id ? 'confirm'
              : pendingAction?.kind === 'dispatch' && pendingAction.routeId === slot.route?.id ? 'dispatch'
              : null}
            disabled={disabled} />
        ))
      )}
    </div>
  );
}
