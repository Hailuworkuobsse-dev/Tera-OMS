import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, DataTable, EmptyState, Money, Spinner, type Column } from '@tera/ui';
import { FilterTabs } from './components/FilterTabs';
import { OverrideDialog } from './components/OverrideDialog';
import { ReasonText, StatusBadge } from './components/StatusBadge';
import { useCreditStopList, useOverrideCredit } from './hooks';
import type { CreditFilter, CreditStopRow, OverrideRequest } from './types';

export function CreditStopListPage() {
  const { t } = useI18n();
  const [filter, setFilter] = useState<CreditFilter>('ALL');
  const [overrideFor, setOverrideFor] = useState<CreditStopRow | null>(null);
  const { data, isLoading, isError, refetch } = useCreditStopList();
  const override = useOverrideCredit();

  const rows = useMemo(() => {
    const all = data?.rows ?? [];
    switch (filter) {
      case 'OVERDUE_30': return all.filter((r) => r.days_overdue >= 30);
      case 'OVER_LIMIT': return all.filter((r) => r.exposure_etb > r.credit_limit_etb);
      default: return all;
    }
  }, [data, filter]);

  const columns: Column<CreditStopRow>[] = [
    { key: 'distributor', header: t('credit.table.distributor'), render: (r) => (
      <div><div className="font-medium">{r.distributor_name}</div><ReasonText reason={r.reason} /></div>
    )},
    { key: 'region', header: t('credit.table.region'), render: (r) => r.region },
    { key: 'status', header: t('credit.table.status'), render: (r) => <StatusBadge decision={r.decision} /> },
    { key: 'owed', header: t('credit.amount_owed'), align: 'right', render: (r) => <Money value={r.amount_owed_etb} bold /> },
    { key: 'limit', header: t('credit.limit'), align: 'right', render: (r) => <Money value={r.credit_limit_etb} /> },
    { key: 'overdue', header: t('credit.days_overdue'), align: 'right', render: (r) => r.days_overdue },
    { key: 'actions', header: t('credit.table.actions'), align: 'right', render: (r) => (
      <Button size="sm" variant="secondary" onClick={() => setOverrideFor(r)}>{t('credit.override')}</Button>
    )},
  ];

  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">{t('credit.title')}</h1>
        <p className="text-sm text-muted mt-1">{t('credit.subtitle')}</p>
        {data && !data.hard_gate && (
          <p className="text-xs text-warn bg-warnBg border border-warn/30 rounded px-2 py-1 mt-2 inline-block">
            {t('common.optional')}: soft mode — blocks are warnings, not hard stops
          </p>
        )}
      </header>
      <div className="flex items-center justify-between mb-4">
        <FilterTabs value={filter} onChange={setFilter} />
        <Button variant="ghost" size="sm" onClick={() => refetch()}>{t('common.retry')}</Button>
      </div>
      {isLoading && <Spinner label={t('common.loading')} />}
      {isError && (
        <div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
          {t('common.error')}{' '}<button onClick={() => refetch()} className="underline">{t('common.retry')}</button>
        </div>
      )}
      {!isLoading && !isError && (
        rows.length === 0
          ? <EmptyState title={t('credit.no_blocked')} />
          : <DataTable columns={columns} rows={rows} rowKey={(r) => r.distributor_id} emptyMessage={t('common.empty')} />
      )}
      {overrideFor && (
        <OverrideDialog row={overrideFor} isPending={override.isPending}
          errorMessage={override.isError ? t('common.error') : undefined}
          onCancel={() => { setOverrideFor(null); override.reset(); }}
          onSubmit={(req: OverrideRequest) => override.mutate(req, { onSuccess: () => setOverrideFor(null) })} />
      )}
    </div>
  );
}
