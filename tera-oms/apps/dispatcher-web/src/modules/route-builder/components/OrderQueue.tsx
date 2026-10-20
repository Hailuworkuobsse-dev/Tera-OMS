import { useI18n } from '@tera/i18n';
import type { Order } from '../types';

interface Props {
  orders: Order[]; selected: Set<string>;
  onToggle: (id: string) => void;
  onSelectAll: () => void;
  onClearAll: () => void;
}
export function OrderQueue({ orders, selected, onToggle, onSelectAll, onClearAll }: Props) {
  const { t } = useI18n();
  if (orders.length === 0) {
    return <div className="text-muted text-sm p-4 border border-border rounded-md bg-surface">{t('route_builder.no_pending')}</div>;
  }
  return (
    <div className="border border-border rounded-md bg-surface">
      <div className="flex items-center justify-between px-3 py-2 border-b border-border">
        <span className="text-sm font-medium">{t('route_builder.pending_orders')} ({orders.length})</span>
        <div className="flex gap-1">
          <button className="text-xs text-muted hover:underline" onClick={onSelectAll}>{t('route_builder.select_all')}</button>
          <button className="text-xs text-muted hover:underline" onClick={onClearAll}>{t('route_builder.clear')}</button>
        </div>
      </div>
      <ul className="max-h-[420px] overflow-y-auto">
        {orders.map((o) => {
          const isSel = selected.has(o.id);
          return (
            <li key={o.id} className={`flex items-start gap-2 p-2 border-b border-border last:border-0 ${isSel ? 'bg-bg' : ''}`}>
              <input type="checkbox" checked={isSel} onChange={() => onToggle(o.id)} className="mt-1 accent-primary" />
              <button className="text-left flex-1 text-sm" onClick={() => onToggle(o.id)}>
                <div className="font-medium">{o.distributor_name}</div>
                <div className="text-xs text-muted">{o.weight_kg} kg · {o.volume_m3} m³ · {t('route_builder.priority')} {o.priority}</div>
                <div className="text-xs text-muted">
                  {new Date(o.time_window_start).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} –{' '}
                  {new Date(o.time_window_end).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
