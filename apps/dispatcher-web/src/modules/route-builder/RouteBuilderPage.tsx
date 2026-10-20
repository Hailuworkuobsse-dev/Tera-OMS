import { useEffect, useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import { OrderQueue } from './components/OrderQueue';
import { VehicleSelector } from './components/VehicleSelector';
import { ComparisonView } from './components/ComparisonView';
import { RouteMap } from './components/RouteMap';
import { usePendingOrders, useVehicles, useAcceptRoute, useSubmitAsyncSolve, useAsyncSolveJob, useSolveRoutesSync } from './hooks';
import type { SolveResponse } from './types';

const DEFAULT_DRIVER_ID = 'D-201';
const STALL_MS = 15_000;

export function RouteBuilderPage() {
  const { t } = useI18n();
  const ordersQ = usePendingOrders();
  const vehiclesQ = useVehicles();
  const submitMut = useSubmitAsyncSolve();
  const acceptMut = useAcceptRoute();
  const syncMut = useSolveRoutesSync();

  const [selectedOrderIds, setSelectedOrderIds] = useState<Set<string>>(new Set());
  const [selectedVehicleId, setSelectedVehicleId] = useState<string | null>(null);
  const [jobId, setJobId] = useState<string | null>(null);
  const [solution, setSolution] = useState<SolveResponse | null>(null);
  const [usedSyncFallback, setUsedSyncFallback] = useState(false);
  const jobQ = useAsyncSolveJob(jobId);

  const orders = ordersQ.data?.orders ?? [];
  const vehicles = vehiclesQ.data?.vehicles ?? [];
  const selectedVehicle = useMemo(() => vehicles.find((v) => v.id === selectedVehicleId) ?? null, [vehicles, selectedVehicleId]);

  useEffect(() => {
    if (jobQ.data?.status === 'DONE' && jobQ.data.result) setSolution(jobQ.data.result);
  }, [jobQ.data]);

  const stalledMs = useMemo(() => {
    if (!jobQ.data) return 0;
    if (jobQ.data.status !== 'QUEUED' && jobQ.data.status !== 'RUNNING') return 0;
    return Date.now() - new Date(jobQ.data.submitted_at).getTime();
  }, [jobQ.data]);
  const isStalled = stalledMs > STALL_MS;

  const reset = () => { setJobId(null); setSolution(null); setUsedSyncFallback(false); submitMut.reset(); syncMut.reset(); };
  const toggle = (id: string) => {
    const next = new Set(selectedOrderIds);
    if (next.has(id)) next.delete(id); else next.add(id);
    setSelectedOrderIds(next); reset();
  };
  const selectAll = () => { setSelectedOrderIds(new Set(orders.map((o) => o.id))); reset(); };
  const clearAll = () => { setSelectedOrderIds(new Set()); reset(); };

  const canSolve = selectedOrderIds.size >= 2 && selectedVehicleId !== null && !submitMut.isPending && !syncMut.isPending && jobId === null;
  const handleSolve = () => {
    if (!canSolve) return;
    setSolution(null); setUsedSyncFallback(false);
    submitMut.mutate({ order_ids: Array.from(selectedOrderIds), vehicle_id: selectedVehicleId! },
      { onSuccess: (r) => setJobId(r.job_id) });
  };
  const handleSyncFallback = () => {
    if (selectedOrderIds.size < 2 || !selectedVehicleId) return;
    setUsedSyncFallback(true);
    syncMut.mutate({ order_ids: Array.from(selectedOrderIds), vehicle_id: selectedVehicleId! },
      { onSuccess: (r) => setSolution(r) });
  };
  const handleAccept = () => {
    if (!selectedVehicleId) return;
    acceptMut.mutate({
      order_ids: Array.from(selectedOrderIds), vehicle_id: selectedVehicleId,
      driver_id: DEFAULT_DRIVER_ID, mode: 'optimized',
    }, { onSuccess: () => { reset(); setSelectedOrderIds(new Set()); void ordersQ.refetch(); } });
  };

  const isLoading = ordersQ.isLoading || vehiclesQ.isLoading;
  const jobRunning = jobQ.data?.status === 'QUEUED' || jobQ.data?.status === 'RUNNING';
  const jobFailed = jobQ.data?.status === 'FAILED' || jobQ.data?.status === 'TIMEOUT';

  return (
    <div className="max-w-[1400px] mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">{t('route_builder.title')}</h1>
        <p className="text-sm text-muted mt-1">{t('route_builder.subtitle')}</p>
      </header>
      {isLoading ? <Spinner label={t('common.loading')} /> : (
        <div className="grid grid-cols-1 lg:grid-cols-[360px_1fr] gap-4">
          <aside className="flex flex-col gap-3">
            <OrderQueue orders={orders} selected={selectedOrderIds} onToggle={toggle} onSelectAll={selectAll} onClearAll={clearAll} />
            <VehicleSelector vehicles={vehicles} selected={selectedVehicleId} onSelect={(id) => { setSelectedVehicleId(id); reset(); }} />
            <Button onClick={handleSolve} disabled={!canSolve} loading={submitMut.isPending}>
              {t('route_builder.solve')} ({selectedOrderIds.size})
            </Button>
            {(submitMut.isError || jobFailed) && (
              <div className="text-sm text-danger">{(submitMut.error as Error)?.message ?? jobQ.data?.error ?? t('common.error')}</div>
            )}
          </aside>
          <section className="min-w-0">
            {!solution && !jobRunning && !jobFailed && (
              <EmptyState title={t('route_builder.no_solution')} hint={t('route_builder.no_solution_hint')} />
            )}
            {jobRunning && !solution && (
              <div className="border border-border rounded-md bg-surface p-6">
                <div className="flex items-center gap-3 mb-2">
                  <span className="inline-block w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                  <p className="text-sm font-medium">
                    {jobQ.data?.status === 'QUEUED' ? t('route_builder.async.queued') : t('route_builder.async.running')}
                  </p>
                </div>
                <p className="text-xs text-muted">{t('route_builder.async.elapsed', { s: Math.floor(stalledMs / 1000) })}</p>
                {isStalled && (
                  <div className="mt-4 border border-warn/40 bg-warnBg rounded-md p-3 text-sm">
                    <p className="font-medium text-warn mb-1">{t('route_builder.async.stalled_title')}</p>
                    <p className="text-muted mb-3">{t('route_builder.async.stalled_body')}</p>
                    <div className="flex gap-2">
                      <Button size="sm" onClick={handleSyncFallback} loading={syncMut.isPending}>{t('route_builder.async.try_sync')}</Button>
                      <Button size="sm" variant="ghost" onClick={reset}>{t('common.cancel')}</Button>
                    </div>
                  </div>
                )}
              </div>
            )}
            {syncMut.isPending && (
              <div className="border border-border rounded-md bg-surface p-6">
                <div className="flex items-center gap-3">
                  <span className="inline-block w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                  <p className="text-sm font-medium">{t('route_builder.async.running')}</p>
                </div>
              </div>
            )}
            {jobFailed && !solution && (
              <div className="border border-danger/40 bg-dangerBg rounded-md p-4">
                <p className="font-medium text-danger mb-1">{t('route_builder.async.failed_title')}</p>
                <p className="text-sm text-muted mb-3">{jobQ.data?.error ?? t('common.error')}</p>
                <div className="flex gap-2">
                  <Button size="sm" onClick={handleSyncFallback} loading={syncMut.isPending}>{t('route_builder.async.try_sync')}</Button>
                  <Button size="sm" variant="ghost" onClick={reset}>{t('common.cancel')}</Button>
                </div>
              </div>
            )}
            {solution && selectedVehicle && (
              <>
                {usedSyncFallback && (
                  <div className="mb-3 text-xs text-warn border border-warn/30 bg-warnBg rounded px-3 py-2">{t('route_builder.async.used_sync')}</div>
                )}
                <ComparisonView solution={solution} />
                <div className="mt-4">
                  <RouteMap solution={solution} start={{ lat: selectedVehicle.start_lat, lng: selectedVehicle.start_lng }} />
                </div>
                <div className="mt-4 flex justify-end gap-2">
                  <Button variant="secondary" onClick={reset} disabled={acceptMut.isPending}>{t('route_builder.reject')}</Button>
                  <Button onClick={handleAccept} loading={acceptMut.isPending} disabled={solution.infeasible !== null}>
                    {t('route_builder.accept_optimized')}
                  </Button>
                </div>
              </>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
