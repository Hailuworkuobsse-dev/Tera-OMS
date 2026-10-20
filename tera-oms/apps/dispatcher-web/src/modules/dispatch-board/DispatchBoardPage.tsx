import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import { BoardSummary } from './components/BoardSummary';
import { DockColumn } from './components/DockColumn';
import { useBoard, useAllocateAll, useConfirmSlot, useDispatchRoute } from './hooks';

export function DispatchBoardPage() {
  const { t } = useI18n();
  const [wallMode, setWallMode] = useState(false);
  const boardQ = useBoard();
  const allocateMut = useAllocateAll();
  const confirmMut = useConfirmSlot();
  const dispatchMut = useDispatchRoute();

  if (boardQ.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (boardQ.isError || !boardQ.data) {
    return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
      {t('common.error')}{' '}<button onClick={() => boardQ.refetch()} className="underline">{t('common.retry')}</button>
    </div></div>;
  }

  const { summary, docks } = boardQ.data;
  const pendingAction =
    confirmMut.isPending && confirmMut.variables ? { kind: 'confirm' as const, slotId: confirmMut.variables }
    : dispatchMut.isPending && dispatchMut.variables ? { kind: 'dispatch' as const, routeId: dispatchMut.variables }
    : null;
  const anyPending = confirmMut.isPending || dispatchMut.isPending || allocateMut.isPending;

  return (
    <div className={`mx-auto ${wallMode ? 'max-w-none px-2' : 'max-w-[1400px]'}`}>
      <header className="mb-4 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className={`font-semibold ${wallMode ? 'text-3xl' : 'text-2xl'}`}>{t('dispatch.title')}</h1>
          <p className={`text-muted mt-1 ${wallMode ? 'text-base' : 'text-sm'}`}>{t('dispatch.subtitle')}</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Button variant="ghost" size="sm" onClick={() => setWallMode((v) => !v)}>
            {wallMode ? t('dispatch.mode.normal') : t('dispatch.mode.wall')}
          </Button>
          <Button onClick={() => allocateMut.mutate()} disabled={anyPending} loading={allocateMut.isPending}>
            {t('dispatch.allocate_all')}
          </Button>
          <Button variant="secondary" size="sm" onClick={() => boardQ.refetch()}>{t('common.retry')}</Button>
        </div>
      </header>

      {(confirmMut.isError || dispatchMut.isError || allocateMut.isError) && (
        <div className="mb-3 text-sm text-danger border border-danger/30 bg-dangerBg rounded px-3 py-2">
          {((confirmMut.error ?? dispatchMut.error ?? allocateMut.error) as Error)?.message ?? t('common.error')}
        </div>
      )}
      <div className="mb-4"><BoardSummary summary={summary} /></div>
      {docks.length === 0 ? <EmptyState title={t('dispatch.no_docks')} /> : (
        <div className={`grid gap-4 ${wallMode ? 'grid-cols-1 md:grid-cols-3' : 'grid-cols-1 md:grid-cols-3'}`}>
          {docks.map((dock) => (
            <DockColumn key={dock.id} dock={dock}
              onConfirm={(slotId) => confirmMut.mutate(slotId)}
              onDispatch={(routeId) => dispatchMut.mutate(routeId)}
              pendingAction={pendingAction} disabled={anyPending} />
          ))}
        </div>
      )}
      {summary.unallocated_routes > 0 && (
        <div className="mt-4 text-xs text-warn bg-warnBg border border-warn/30 rounded px-3 py-2 inline-block">
          {summary.unallocated_routes} {t('dispatch.unallocated_hint')}
        </div>
      )}
    </div>
  );
}
