import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import type { PickListResponse, MarkPickedResponse } from '../types';

interface Props {
  pickList: PickListResponse | undefined;
  isLoading: boolean; isError: boolean;
  onRetry: () => void;
  onMarkPicked: (stopId: string) => void;
  onConfirmLoading: (slotId: string) => void;
  isMarking: boolean; isConfirming: boolean;
  lastMarked: MarkPickedResponse | null;
  confirmError: string | null;
}
export function PickListPanel({ pickList, isLoading, isError, onRetry, onMarkPicked, onConfirmLoading, isMarking, isConfirming, lastMarked, confirmError }: Props) {
  const { t } = useI18n();
  if (isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (isError || !pickList) return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-base text-danger">{t('common.error')}{' '}<button onClick={onRetry} className="underline">{t('common.retry')}</button></div></div>;
  const picked = lastMarked?.picked_count ?? pickList.picked_count;
  const total = pickList.total_count;
  const canConfirm = pickList.can_confirm_loading;
  const allPicked = picked === total;
  return (
    <div className="flex flex-col h-full">
      <div className="mb-4 pb-4 border-b border-border">
        <div className="flex items-baseline justify-between">
          <div><h2 className="text-2xl font-bold">{pickList.vehicle_id}</h2><p className="text-sm text-muted mt-1">{pickList.driver_id} · {total} {t('dispatch.stops')}</p></div>
          <div className="text-right"><p className={`text-3xl font-bold tabular-nums ${allPicked ? 'text-success' : 'text-warn'}`}>{picked}/{total}</p><p className="text-xs text-muted">{t('warehouse.dock.picked_label')}</p></div>
        </div>
      </div>
      {confirmError && <div className="mb-4 text-base text-danger border border-danger/30 bg-dangerBg rounded-md px-4 py-3">{confirmError}</div>}
      <div className="flex-1 overflow-y-auto -mx-2 px-2">
        {pickList.stops.map((s) => {
          const isPicked = s.picked_at !== null || (lastMarked && lastMarked.stop_id === s.stop_id);
          return (
            <div key={s.stop_id} className={`flex items-center gap-4 p-4 mb-2 rounded-lg border-2 transition ${isPicked ? 'bg-successBg border-success/40' : 'bg-surface border-border'}`}>
              <div className={`flex items-center justify-center w-12 h-12 rounded-full text-lg font-bold ${isPicked ? 'bg-success text-white' : 'bg-border text-muted'}`}>{isPicked ? '✓' : s.seq}</div>
              <div className="flex-1 min-w-0"><p className="text-lg font-medium truncate">{s.distributor_name}</p><p className="text-sm text-muted">{t('warehouse.pick.qty_ordered')}: <span className="font-medium text-text">{s.quantity_ordered}</span></p></div>
              {!isPicked && pickList.slot_status === 'ALLOCATED' && <Button size="lg" disabled={isMarking} onClick={() => onMarkPicked(s.stop_id)}>{t('warehouse.pick.mark_picked')}</Button>}
              {isPicked && <span className="text-sm text-success font-medium">{t('warehouse.pick.picked')}</span>}
            </div>
          );
        })}
      </div>
      {pickList.slot_status === 'ALLOCATED' && pickList.slot_id && (
        <div className="mt-4 pt-4 border-t border-border">
          <Button size="lg" className="w-full" disabled={!canConfirm || isConfirming} loading={isConfirming} onClick={() => onConfirmLoading(pickList.slot_id!)}>
            {canConfirm ? t('warehouse.pick.confirm_loading') : t('warehouse.pick.cannot_confirm')}
          </Button>
        </div>
      )}
      {pickList.slot_status === 'CONFIRMED' && <div className="mt-4 pt-4 border-t border-border"><div className="text-base text-success font-medium text-center">✓ {t('warehouse.dock.awaiting_dispatch')}</div></div>}
    </div>
  );
}
