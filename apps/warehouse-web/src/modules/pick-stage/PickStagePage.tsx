import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { useBoard } from '../dock-queue/hooks';
import { usePickList, useMarkPicked, useConfirmLoading } from './hooks';
import { RouteList } from './components/RouteList';
import { PickListPanel } from './components/PickListPanel';
import type { PickableRoute } from './types';

export function PickStagePage() {
  const { t } = useI18n();
  const [selected, setSelected] = useState<string | null>(null);
  const boardQ = useBoard();
  const pickListQ = usePickList(selected);
  const markMut = useMarkPicked(selected ?? '');
  const confirmMut = useConfirmLoading();
  const routes: PickableRoute[] = useMemo(() => {
    const board = boardQ.data;
    if (!board) return [];
    const out: PickableRoute[] = [];
    for (const dock of board.docks) {
      for (const slot of dock.slots) {
        if (!slot.route) continue;
        if (slot.status !== 'ALLOCATED' && slot.status !== 'CONFIRMED') continue;
        out.push({ route_id: slot.route.id, vehicle_id: slot.route.vehicle_id, driver_id: slot.route.driver_id,
          stop_count: slot.route.stop_count, picked_count: slot.route.picked_count,
          slot_id: slot.id, slot_status: slot.status as any, start_at: slot.start_at, end_at: slot.end_at });
      }
    }
    return out;
  }, [boardQ.data]);
  const effective = selected ?? routes[0]?.route_id ?? null;
  return (
    <div>
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('warehouse.pick.title')}</h1><p className="text-sm text-muted mt-1">{t('warehouse.pick.subtitle')}</p></header>
      <div className="grid grid-cols-1 lg:grid-cols-[380px_1fr] gap-6">
        <aside><p className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('warehouse.pick.routes_today')}</p>
          <RouteList routes={routes} selectedId={effective} onSelect={setSelected} />
        </aside>
        <section className="min-h-[500px]">
          {effective === null ? <div className="flex items-center justify-center h-full text-muted text-base border border-border rounded-md bg-surface p-8">{t('warehouse.pick.select_route')}</div>
            : <PickListPanel pickList={pickListQ.data} isLoading={pickListQ.isLoading} isError={pickListQ.isError}
                onRetry={() => pickListQ.refetch()}
                onMarkPicked={(stopId) => markMut.mutate(stopId)}
                onConfirmLoading={(slotId) => confirmMut.mutate(slotId)}
                isMarking={markMut.isPending} isConfirming={confirmMut.isPending}
                lastMarked={markMut.data ?? null}
                confirmError={confirmMut.isError ? (confirmMut.error as Error).message : null} />}
        </section>
      </div>
    </div>
  );
}
