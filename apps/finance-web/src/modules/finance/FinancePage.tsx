import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { CreditDashboardTab } from './tabs/credit-dashboard/CreditDashboardTab';
import { OverridesTab } from './tabs/overrides/OverridesTab';
import { ReconciliationTab } from './tabs/reconciliation/ReconciliationTab';
type Tab = 'credit' | 'overrides' | 'reconciliation';
const TABS: { id: Tab; key: string }[] = [{ id: 'credit', key: 'finance.tab.credit' }, { id: 'overrides', key: 'finance.tab.overrides' }, { id: 'reconciliation', key: 'finance.tab.reconciliation' }];
export function FinancePage() {
  const { t } = useI18n(); const [tab, setTab] = useState<Tab>('credit');
  return (
    <div>
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('finance.heading')}</h1><p className="text-sm text-muted mt-1">{t('finance.heading_hint')}</p></header>
      <div className="border-b border-border mb-6"><nav className="flex gap-1 -mb-px">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </nav></div>
      {tab === 'credit' && <CreditDashboardTab />}
      {tab === 'overrides' && <OverridesTab />}
      {tab === 'reconciliation' && <ReconciliationTab />}
    </div>
  );
}
