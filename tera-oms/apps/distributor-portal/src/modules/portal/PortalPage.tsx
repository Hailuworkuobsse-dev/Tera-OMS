import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Spinner } from '@tera/ui';
import { DistributorSwitcher } from './components/DistributorSwitcher';
import { OrderTab } from './tabs/OrderTab';
import { TrackTab } from './tabs/TrackTab';
import { StatementsTab } from './tabs/StatementsTab';
import { DisputesTab } from './tabs/DisputesTab';
import { useMe } from './hooks';
import { getCurrentDistributor, setCurrentDistributor } from '../../api/client';
import type { Tab } from './types';
const TABS: { id: Tab; key: string }[] = [
  { id: 'order', key: 'portal.tab.order' }, { id: 'track', key: 'portal.tab.track' },
  { id: 'statements', key: 'portal.tab.statements' }, { id: 'disputes', key: 'portal.tab.disputes' },
];
export function PortalPage() {
  const { t } = useI18n(); const [tab, setTab] = useState<Tab>('order');
  if (!getCurrentDistributor()) setCurrentDistributor('seed-dist-1');
  const meQ = useMe();
  return (
    <div className="min-h-full bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3"><div className="max-w-6xl mx-auto flex items-center gap-4 flex-wrap">
        <div><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('portal.title')}</p></div>
        <div className="ml-auto flex items-center gap-3">
          {meQ.data && <div className="text-sm text-right"><div className="font-medium">{meQ.data.name}</div><div className="text-xs text-muted">{t('portal.headroom_short')}: {meQ.data.headroom_etb.toLocaleString()} ETB</div></div>}
          <DistributorSwitcher />
        </div>
      </div></header>
      <div className="border-b border-border bg-surface px-6"><div className="max-w-6xl mx-auto flex gap-1">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </div></div>
      <main className="p-6 max-w-6xl mx-auto">
        {meQ.isLoading ? <Spinner label={t('common.loading')} /> : (
          <>{tab === 'order' && <OrderTab />}{tab === 'track' && <TrackTab />}{tab === 'statements' && <StatementsTab />}{tab === 'disputes' && <DisputesTab />}</>
        )}
      </main>
    </div>
  );
}
