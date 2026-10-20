import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { CurfewsTab } from './components/CurfewsTab';
import { FuelStationsTab } from './components/FuelStationsTab';
import type { Tab } from './types';
const TABS: { id: Tab; key: string }[] = [{ id: 'curfews', key: 'admin.constraints.tab.curfews' }, { id: 'fuel-stations', key: 'admin.constraints.tab.fuel' }];
export function ConstraintsPage() {
  const { t } = useI18n();
  const [tab, setTab] = useState<Tab>('curfews');
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('admin.constraints.title')}</h1><p className="text-sm text-muted mt-1">{t('admin.constraints.subtitle')}</p></header>
      <div className="border-b border-border mb-6"><nav className="flex gap-1 -mb-px">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </nav></div>
      {tab === 'curfews' && <CurfewsTab />}
      {tab === 'fuel-stations' && <FuelStationsTab />}
    </div>
  );
}
