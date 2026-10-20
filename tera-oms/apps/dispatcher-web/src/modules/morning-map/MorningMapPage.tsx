import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, Spinner } from '@tera/ui';
import { MapCanvas } from './components/MapCanvas';
import { VehicleList } from './components/VehicleList';
import { MapLegend } from './components/MapLegend';
import { FallbackTable } from './components/FallbackTable';
import { useTodayRoutes, useCurfewZones, useFuelStations, deriveLiveVehicles } from './hooks';

export function MorningMapPage() {
  const { t } = useI18n();
  const [selectedRouteId, setSelectedRouteId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<'map' | 'table'>('map');
  const routesQ = useTodayRoutes();
  const zonesQ = useCurfewZones();
  const stationsQ = useFuelStations();
  const isLoading = routesQ.isLoading || zonesQ.isLoading || stationsQ.isLoading;
  const isError = routesQ.isError || zonesQ.isError || stationsQ.isError;
  const routes = routesQ.data?.routes ?? [];
  const zones = zonesQ.data?.zones ?? [];
  const stations = stationsQ.data?.stations ?? [];

  const liveByRouteId = useMemo(() => {
    const map = new Map<string, { current_stop_index: number; status: 'on-track' | 'late'; minutes_behind: number }>();
    for (const v of deriveLiveVehicles(routes)) {
      map.set(v.route.id, { current_stop_index: v.current_stop_index, status: v.status, minutes_behind: v.minutes_behind });
    }
    return map;
  }, [routes]);

  const refetchAll = () => { void routesQ.refetch(); void zonesQ.refetch(); void stationsQ.refetch(); };

  if (isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (isError) {
    return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
      {t('common.error')}{' '}<button onClick={refetchAll} className="underline">{t('common.retry')}</button>
    </div></div>;
  }

  return (
    <div className="max-w-[1400px] mx-auto">
      <header className="mb-4 flex items-end justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{t('morning_map.title')}</h1>
          <p className="text-sm text-muted mt-1">{t('morning_map.subtitle')}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" onClick={() => setViewMode(viewMode === 'map' ? 'table' : 'map')}>
            {viewMode === 'map' ? t('morning_map.view_table') : t('morning_map.view_map')}
          </Button>
          <Button variant="secondary" size="sm" onClick={refetchAll}>{t('common.retry')}</Button>
        </div>
      </header>
      <div className="grid grid-cols-1 lg:grid-cols-[320px_1fr] gap-4">
        <aside className="flex flex-col gap-3">
          <VehicleList routes={routes} liveByRouteId={liveByRouteId} selectedRouteId={selectedRouteId} onSelectRoute={setSelectedRouteId} />
          <MapLegend />
        </aside>
        <section className="min-h-[500px]">
          {viewMode === 'map'
            ? <MapCanvas routes={routes} curfewZones={zones} fuelStations={stations} selectedRouteId={selectedRouteId} onSelectRoute={setSelectedRouteId} />
            : <FallbackTable routes={routes} />}
        </section>
      </div>
    </div>
  );
}
