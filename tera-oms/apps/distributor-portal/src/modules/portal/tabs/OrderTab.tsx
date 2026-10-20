import { useMemo, useState } from 'react';
import { useI18n, formatETB } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import { useCatalog, useMe, usePlaceOrder } from '../hooks';
import type { CatalogItem } from '../types';
export function OrderTab() {
  const { t } = useI18n();
  const catalogQ = useCatalog(); const meQ = useMe(); const placeMut = usePlaceOrder();
  const [cart, setCart] = useState<Map<string, number>>(new Map());
  const [success, setSuccess] = useState<{ orderId: string; total: number } | null>(null);
  const items = catalogQ.data?.items ?? []; const byId = useMemo(() => new Map(items.map((i) => [i.sku_id, i])), [items]);
  const cartLines = useMemo(() => { const out: { item: CatalogItem; qty: number; subtotal: number }[] = []; for (const [id, qty] of cart) { const it = byId.get(id); if (it) out.push({ item: it, qty, subtotal: qty * it.unit_price_etb }); } return out; }, [cart, byId]);
  const total = cartLines.reduce((s, l) => s + l.subtotal, 0); const headroom = meQ.data?.headroom_etb ?? 0;
  const exceeds = total > headroom; const count = cartLines.reduce((s, l) => s + l.qty, 0);
  const setQty = (id: string, q: number) => { const n = new Map(cart); if (q <= 0) n.delete(id); else n.set(id, q); setCart(n); setSuccess(null); };
  if (catalogQ.isLoading || meQ.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (catalogQ.isError || meQ.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-6">
      <div>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.order.catalog')}</h2>
        {items.length === 0 ? <EmptyState title={t('portal.order.no_skus')} /> : (
          <div className="flex flex-col gap-2">{items.map((it) => { const q = cart.get(it.sku_id) ?? 0; const tone = it.stock_on_hand === 0 ? 'text-danger' : it.stock_on_hand < 100 ? 'text-warn' : 'text-success';
            return <div key={it.sku_id} className="border border-border rounded-md bg-surface p-3 flex items-center gap-3">
              <div className="flex-1 min-w-0"><div className="font-medium">{it.name}</div>
                <div className="text-xs text-muted">{it.code} · {formatETB(it.unit_price_etb)} / {it.unit} · <span className={tone}>{it.stock_on_hand} {t('portal.order.in_stock')}</span></div></div>
              <div className="flex items-center gap-1">
                <Button size="sm" variant="ghost" onClick={() => setQty(it.sku_id, q - 1)} disabled={q === 0}>−</Button>
                <input type="number" min={0} max={it.stock_on_hand} value={q} onChange={(e) => setQty(it.sku_id, Math.min(it.stock_on_hand, Math.max(0, parseInt(e.target.value, 10) || 0)))} className="w-16 text-center rounded-md border border-border bg-bg px-2 py-1 text-sm tabular-nums" />
                <Button size="sm" variant="ghost" onClick={() => setQty(it.sku_id, Math.min(it.stock_on_hand, q + 1))}>+</Button>
              </div></div>; })}</div>
        )}
      </div>
      <aside className="lg:sticky lg:top-4 self-start flex flex-col gap-3">
        <div className="border border-border rounded-md bg-surface p-4">
          <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.order.cart')}</h2>
          {cartLines.length === 0 ? <p className="text-sm text-muted">{t('portal.order.cart_empty')}</p> : (
            <div className="flex flex-col gap-1.5 mb-3">{cartLines.map((l) => <div key={l.item.sku_id} className="flex justify-between text-sm"><span>{l.qty}× {l.item.name}</span><span className="tabular-nums">{formatETB(l.subtotal)}</span></div>)}</div>
          )}
          <div className="border-t border-border pt-2 flex justify-between font-medium"><span>{t('portal.order.total')}</span><span className="tabular-nums">{formatETB(total)}</span></div>
        </div>
        <div className={`rounded-md border p-4 ${exceeds ? 'border-danger/40 bg-dangerBg' : 'border-border bg-surface'}`}>
          <p className="text-xs text-muted uppercase">{t('portal.order.headroom')}</p>
          <p className={`text-xl font-bold tabular-nums ${exceeds ? 'text-danger' : ''}`}>{formatETB(headroom)}</p>
          {count > 0 && <p className={`text-xs mt-1 ${exceeds ? 'text-danger font-medium' : 'text-muted'}`}>{exceeds ? t('portal.order.exceeds', { over: formatETB(total - headroom) }) : t('portal.order.after', { remaining: formatETB(headroom - total) })}</p>}
        </div>
        <Button size="lg" className="w-full" disabled={count === 0 || exceeds} loading={placeMut.isPending}
          onClick={() => placeMut.mutate({ lines: cartLines.map((l) => ({ sku_id: l.item.sku_id, quantity: l.qty })) }, { onSuccess: (r) => { setSuccess({ orderId: r.order_id, total: r.total_etb }); setCart(new Map()); } })}>
          {t('portal.order.place', { n: count })}
        </Button>
        {placeMut.isError && <div className="text-sm text-danger border border-danger/30 bg-dangerBg rounded px-3 py-2">{(placeMut.error as Error).message}</div>}
        {success && <div className="text-sm text-success border border-success/30 bg-successBg rounded px-3 py-2">✓ {t('portal.order.success', { total: formatETB(success.total) })}</div>}
      </aside>
    </div>
  );
}
