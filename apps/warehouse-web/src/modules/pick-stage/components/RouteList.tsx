import { useI18n } from '@tera/i18n';
import { EmptyState, StatusPill } from '@tera/ui';
import type { PickableRoute } from '../types';

export function RouteList({ routes, selectedId, onSelect }: { routes: PickableRoute[]; selectedId: string | null; onSelect: (id: string) => void }) {
  const { t } = useI18n();
  if (routes.length === 0) {
    return <div className="border border-border rounded-md bg-surface"><EmptyState title={t('warehouse.pick.no_routes')} hint={t('warehouse.pick.no_routes_hint')} /></div>;
  }
  return (
    <div className="flex flex-col gap-2">
      {routes.map((r) => {
        const picked = r.picked_count === r.stop_count;
        return (
          <button key={r.route_id} onClick={() => onSelect(r.route_id)}
            className={`text-left p-4 rounded-lg border-2 transition ${r.route_id === selectedId ? 'border-primary bg-surface' : 'border-border bg-surface hover:border-primary/40'}`}>
            <div className="flex items-center justify-between mb-1">
              <span className="text-base font-semibold">{r.vehicle_id}</span>
              <StatusPill tone={r.slot_status === 'CONFIRMED' || picked ? 'success' : 'warn'}>
                {r.slot_status === 'CONFIRMED' ? t('dispatch.slot.confirmed') : picked ? t('warehouse.pick.ready') : t('warehouse.pick.pending')}
              </StatusPill>
            </div>
            <div className="text-sm text-muted">{r.driver_id} · {r.picked_count}/{r.stop_count} {t('warehouse.dock.picked_label')}</div>
          </button>
        );
      })}
    </div>
  );
}
