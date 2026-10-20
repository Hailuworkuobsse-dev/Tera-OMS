import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner } from '@tera/ui';
import { HeroTile } from './components/HeroTile';
import { DriverTile } from './components/DriverTile';
import { DemoBanner } from './components/DemoBanner';
import { AssumptionsPanel } from './components/AssumptionsPanel';
import { useDashboard, useFreezeBaseline } from './hooks';

export function DashboardPage() {
  const { t } = useI18n();
  const dashQ = useDashboard(); const freezeMut = useFreezeBaseline();
  if (dashQ.isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (dashQ.isError || !dashQ.data) return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">{t('common.error')}</div></div>;
  const { hero, tiles, is_demo, baseline_frozen_at } = dashQ.data;
  if (!baseline_frozen_at) return <EmptyState title={t('exec.empty.no_baseline')} hint={t('exec.empty.no_baseline_hint')} />;
  return (
    <div className="flex flex-col gap-6">
      <header className="flex items-end justify-between gap-4 flex-wrap">
        <div><h1 className="text-2xl font-bold">{t('exec.heading')}</h1><p className="text-sm text-muted mt-1">{t('exec.as_of')}: {new Date(dashQ.data.as_of).toLocaleString()}</p></div>
        <AssumptionsPanel />
      </header>
      {is_demo && <DemoBanner onStartRealBaseline={() => freezeMut.mutate(undefined, { onSuccess: () => void dashQ.refetch() })} isStarting={freezeMut.isPending} />}
      {hero && <HeroTile hero={hero} />}
      <section>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('exec.tiles.heading')}</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">{tiles.map((tile) => <DriverTile key={tile.metric_key} tile={tile} />)}</div>
      </section>
    </div>
  );
}
