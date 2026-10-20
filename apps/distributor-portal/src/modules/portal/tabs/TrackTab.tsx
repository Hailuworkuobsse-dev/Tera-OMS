import { useI18n, formatETB } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useOrders } from '../hooks';
import type { PortalOrderSummary } from '../types';
function tone(s: PortalOrderSummary['status']): 'success' | 'warn' | 'danger' | 'neutral' { if (s === 'DELIVERED') return 'success'; if (s === 'ROUTED') return 'warn'; if (s === 'FAILED') return 'danger'; return 'neutral'; }
export function TrackTab() {
  const { t } = useI18n(); const q = useOrders();
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div className="flex flex-col gap-6">
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.track.active')} ({q.data.active.length})</h2>
        {q.data.active.length === 0 ? <EmptyState title={t('portal.track.no_active')} hint={t('portal.track.no_active_hint')} /> :
          <div className="flex flex-col gap-2">{q.data.active.map((o) => <Card key={o.order_id} order={o} />)}</div>}</section>
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.track.recent')} ({q.data.recent.length})</h2>
        {q.data.recent.length === 0 ? <EmptyState title={t('portal.track.no_recent')} /> :
          <div className="flex flex-col gap-2">{q.data.recent.map((o) => <Card key={o.order_id} order={o} compact />)}</div>}</section>
    </div>
  );
}
function Card({ order, compact }: { order: PortalOrderSummary; compact?: boolean }) {
  const { t } = useI18n();
  const eta = order.eta ? new Date(order.eta) : null;
  return (
    <div className={`border rounded-md bg-surface p-4 ${compact ? 'py-3' : ''}`}>
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div><div className="font-medium text-sm font-mono">{order.order_id}</div>
          <div className="text-xs text-muted mt-1">{new Date(order.created_at).toLocaleString()} · {order.line_count} {t('portal.track.lines')} · {order.total_quantity} {t('portal.track.items')}</div></div>
        <div className="flex items-center gap-3"><span className="tabular-nums font-medium">{formatETB(order.total_etb)}</span><StatusPill tone={tone(order.status)}>{order.status}</StatusPill></div>
      </div>
      {eta && !compact && <div className="mt-3 pt-3 border-t border-border flex items-center justify-between text-sm">
        <div><span className="text-muted">{t('portal.track.eta')}: </span><span className="font-medium">{eta.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
          {order.vehicle_id && <><span className="text-muted"> · {t('portal.track.vehicle')}: </span><span className="font-medium">{order.vehicle_id}</span></>}</div></div>}
    </div>
  );
}
