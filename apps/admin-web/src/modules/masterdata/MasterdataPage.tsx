import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { DistributorsTab } from './components/DistributorsTab';
import { VehiclesTab } from './components/VehiclesTab';
import { SkusTab } from './components/SkusTab';
import { ImportTab } from './components/ImportTab';
import type { Tab } from './types';

const TABS: { id: Tab; key: string }[] = [
  { id: 'distributors', key: 'admin.md.tab.distributors' },
  { id: 'vehicles', key: 'admin.md.tab.vehicles' },
  { id: 'skus', key: 'admin.md.tab.skus' },
  { id: 'import', key: 'admin.md.tab.import' },
];
export function MasterdataPage() {
  const { t } = useI18n();
  const [tab, setTab] = useState<Tab>('distributors');
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('admin.md.title')}</h1><p className="text-sm text-muted mt-1">{t('admin.md.subtitle')}</p></header>
      <div className="border-b border-border mb-6"><nav className="flex gap-1 -mb-px">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </nav></div>
      {tab === 'distributors' && <DistributorsTab />}
      {tab === 'vehicles' && <VehiclesTab />}
      {tab === 'skus' && <SkusTab />}
      {tab === 'import' && <ImportTab />}
    </div>
  );
}
