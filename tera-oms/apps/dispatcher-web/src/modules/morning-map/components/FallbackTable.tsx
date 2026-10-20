import { useI18n } from '@tera/i18n';
import { DataTable, type Column } from '@tera/ui';
import type { RoutePlan } from '../types';

export function FallbackTable({ routes }: { routes: RoutePlan[] }) {
  const { t } = useI18n();
  const flat = routes.flatMap((r) => r.stops.map((s) => ({
    route_id: r.id, vehicle_id: r.vehicle_id, seq: s.seq,
    distributor_name: s.distributor_name, status: s.status, planned_eta: s.planned_eta,
  })));
  const columns: Column<(typeof flat)[number]>[] = [
    { key: 'vehicle', header: t('morning_map.table.vehicle'), render: (r) => r.vehicle_id },
    { key: 'seq', header: '#', render: (r) => r.seq, align: 'right' },
    { key: 'distributor', header: t('credit.table.distributor'), render: (r) => r.distributor_name },
    { key: 'status', header: t('credit.table.status'), render: (r) => r.status },
    { key: 'eta', header: t('time.eta'), align: 'right',
      render: (r) => new Date(r.planned_eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) },
  ];
  return <DataTable columns={columns} rows={flat} rowKey={(r) => `${r.route_id}-${r.seq}`} emptyMessage={t('common.empty')} />;
}
