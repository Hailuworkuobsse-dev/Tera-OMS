import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner } from '@tera/ui';
import { SlotCard } from './components/SlotCard';
import { useBoard, useConfirmLoading } from './hooks';

export function DockQueuePage() {
  const { t } = useI18n();
  const [kiosk, setKiosk] = useState(true);
  const boardQ = useBoard();
  const confirmMut = useConfirmLoading();
  if (boardQ.isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (boardQ.isError || !boardQ.data) {
    return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-base text-danger">
      {t('common.error')}{' '}<button onClick={() => boardQ.refetch()} className="underline">{t('common.retry')}</button>
    </div></div>;
  }
  const actionableDocks = boardQ.data.docks.map((d) => ({ ...d, slots: d.slots.filter((s) => s.status === 'ALLOCATED' || s.status === 'CONFIRMED') })).filter((d) => d.slots.length > 0);
  const hasWork = actionableDocks.length > 0;
  return (
    <div className={kiosk ? 'px-2' : ''}>
      <header className="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className={`font-bold ${kiosk ? 'text-4xl' : 'text-2xl'}`}>{t('warehouse.dock.title')}</h1>
          <p className={`text-muted mt-1 ${kiosk ? 'text-lg' : 'text-base'}`}>{t('warehouse.dock.subtitle')}</p>
        </div>
        <button onClick={() => setKiosk((v) => !v)} className="text-sm text-muted hover:text-text px-3 py-2 rounded-md border border-border bg-surface">
          {kiosk ? t('warehouse.mode.normal') : t('warehouse.mode.kiosk')}
        </button>
      </header>
      {confirmMut.isError && <div className="mb-4 text-base text-danger border border-danger/30 bg-dangerBg rounded-md px-4 py-3">{(confirmMut.error as Error).message}</div>}
      {!hasWork ? <EmptyState title={t('warehouse.dock.empty')} hint={t('warehouse.dock.empty_hint')} />
        : (
          <div className={`grid gap-4 ${kiosk ? 'grid-cols-1 md:grid-cols-3' : 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3'}`}>
            {actionableDocks.map((dock) => (
              <div key={dock.id} className="flex flex-col gap-3">
                <div className={`font-semibold px-1 pb-2 border-b border-border ${kiosk ? 'text-2xl' : 'text-base'}`}>{dock.name}</div>
                {dock.slots.map((slot) => (
                  <SlotCard key={slot.id} slot={slot} onConfirm={(id) => confirmMut.mutate(id)} isConfirming={confirmMut.isPending && confirmMut.variables === slot.id} />
                ))}
              </div>
            ))}
          </div>
        )}
    </div>
  );
}
