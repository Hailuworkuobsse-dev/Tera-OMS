import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { RoutePlan } from '../types';

interface Props {
  routes: RoutePlan[];
  liveByRouteId: Map<string, { current_stop_index: number; status: 'on-track' | 'late'; minutes_behind: number }>;
  selectedRouteId: string | null;
  onSelectRoute: (id: string) => void;
}
export function VehicleList({ routes, liveByRouteId, selectedRouteId, onSelectRoute }: Props) {
  const { t } = useI18n();
  if (routes.length === 0) {
    return <div className="text-muted text-sm p-4 border border-border rounded-md bg-surface">{t('morning_map.no_routes')}</div>;
  }
  return (
    <div className="flex flex-col gap-2">
      {routes.map((r) => {
        const live = liveByRouteId.get(r.id);
        const isSelected = r.id === selectedRouteId;
        const delivered = r.stops.filter((s) => s.status === 'DELIVERED').length;
        return (
          <button key={r.id} onClick={() => onSelectRoute(r.id)}
            className={`text-left p-3 rounded-md border transition ${isSelected ? 'border-primary bg-surface' : 'border-border bg-surface hover:bg-bg'}`}>
            <div className="flex items-center justify-between">
              <span className="font-medium text-sm">{r.vehicle_id}</span>
              {live && (
                <StatusPill tone={live.status === 'late' ? 'danger' : 'success'}>
                  {live.status === 'late' ? t('morning_map.status.late') : t('morning_map.status.on_track')}
                </StatusPill>
              )}
            </div>
            <div className="text-xs text-muted mt-1">{r.driver_id} · {delivered}/{r.stops.length} {t('morning_map.stops_delivered')}</div>
            {live && live.minutes_behind > 0 && (
              <div className="text-xs text-danger mt-1">{live.minutes_behind} {t('time.minutes_short')}</div>
            )}
          </button>
        );
      })}
    </div>
  );
}
