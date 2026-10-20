import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useOrders, useDisputes, useRaiseDispute } from '../hooks';
import type { RaiseDisputeRequest } from '../types';
type T = 'QUANTITY' | 'WRONG_ITEM' | 'NEVER_DELIVERED' | 'DAMAGED' | 'OTHER';
const TYPES: T[] = ['QUANTITY', 'WRONG_ITEM', 'NEVER_DELIVERED', 'DAMAGED', 'OTHER'];
export function DisputesTab() {
  const { t } = useI18n(); const ordersQ = useOrders(); const disputesQ = useDisputes(); const raiseMut = useRaiseDispute();
  const [orderId, setOrderId] = useState(''); const [type, setType] = useState<T>('QUANTITY'); const [desc, setDesc] = useState('');
  const all = [...(ordersQ.data?.active ?? []), ...(ordersQ.data?.recent ?? [])];
  const canSubmit = orderId && desc.trim().length >= 10;
  const submit = () => { if (!canSubmit) return; const b: RaiseDisputeRequest = { order_id: orderId, type, description: desc.trim() }; raiseMut.mutate(b, { onSuccess: () => { setOrderId(''); setDesc(''); } }); };
  return (
    <div className="flex flex-col gap-6">
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.disputes.raise')}</h2>
        <div className="border border-border rounded-md bg-surface p-4 flex flex-col gap-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('portal.disputes.order')}</span>
            <select value={orderId} onChange={(e) => setOrderId(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2"><option value="">{t('portal.disputes.pick_order')}</option>
              {all.map((o) => <option key={o.order_id} value={o.order_id}>{o.order_id} ({o.status}) — {o.total_quantity} items</option>)}</select></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('portal.disputes.type')}</span>
            <select value={type} onChange={(e) => setType(e.target.value as T)} className="w-full rounded-md border border-border bg-bg px-3 py-2">
              {TYPES.map((tt) => <option key={tt} value={tt}>{t(`portal.disputes.type.${tt}`)}</option>)}</select></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('portal.disputes.description')}</span>
            <textarea value={desc} onChange={(e) => setDesc(e.target.value)} rows={3} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          {raiseMut.isError && <p className="text-sm text-danger">{(raiseMut.error as Error).message}</p>}
          <div className="flex justify-end"><Button onClick={submit} disabled={!canSubmit} loading={raiseMut.isPending}>{t('portal.disputes.submit')}</Button></div>
        </div></section>
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.disputes.past')} ({disputesQ.data?.disputes.length ?? 0})</h2>
        {disputesQ.isLoading && <Spinner label={t('common.loading')} />}
        {disputesQ.data && disputesQ.data.disputes.length === 0 && <EmptyState title={t('portal.disputes.empty')} />}
        {disputesQ.data && disputesQ.data.disputes.length > 0 && <div className="flex flex-col gap-2">{disputesQ.data.disputes.map((d) => (
          <div key={d.id} className="border border-border rounded-md bg-surface p-3">
            <div className="flex items-center justify-between mb-1"><span className="font-medium text-sm">{t(`portal.disputes.type.${d.type}`)}</span><StatusPill tone={d.status === 'OPEN' ? 'warn' : d.status === 'RESOLVED' ? 'success' : 'neutral'}>{d.status}</StatusPill></div>
            <div className="text-xs text-muted font-mono mb-1">{d.order_id}</div>
            <p className="text-sm">{d.description}</p>
            <p className="text-xs text-muted mt-1">{new Date(d.created_at).toLocaleString()}</p>
          </div>
        ))}</div>}
      </section>
    </div>
  );
}
