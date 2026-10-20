import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useSkus, useCreateSku, useToggleSkuActive } from '../hooks';
const EMPTY = { code: '', name: '', unit: 'each', weight_kg: '', volume_m3: '', reorder_point: '0', safety_stock: '0', lead_time_days: '0' };

export function SkusTab() {
  const { t } = useI18n();
  const list = useSkus(); const create = useCreateSku(); const toggle = useToggleSkuActive();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const upd = (k: keyof typeof EMPTY, v: string) => setForm({ ...form, [k]: v });
  const reset = () => { setForm(EMPTY); setShowForm(false); };
  const submit = () => { create.mutate({
    code: form.code.trim(), name: form.name.trim(), unit: form.unit.trim(),
    weight_kg: parseFloat(form.weight_kg), volume_m3: parseFloat(form.volume_m3),
    reorder_point: parseInt(form.reorder_point, 10) || 0,
    safety_stock: parseInt(form.safety_stock, 10) || 0,
    lead_time_days: parseInt(form.lead_time_days, 10) || 0,
  }, { onSuccess: reset }); };
  if (list.isLoading) return <Spinner label={t('common.loading')} />;
  if (list.isError || !list.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const rows = list.data.skus;
  return (
    <div>
      <div className="flex items-center justify-between mb-4"><p className="text-sm text-muted">{rows.length} {t('admin.md.skus_count')}</p>{!showForm && <Button onClick={() => setShowForm(true)}>{t('admin.md.add')}</Button>}</div>
      {showForm && (
        <div className="border border-primary/30 bg-surface rounded-md p-4 mb-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <F label={t('admin.md.code')} value={form.code} onChange={(v) => upd('code', v)} />
            <F label={t('admin.md.name')} value={form.name} onChange={(v) => upd('name', v)} />
            <F label={t('admin.md.unit')} value={form.unit} onChange={(v) => upd('unit', v)} />
            <F label={t('admin.md.weight_kg')} value={form.weight_kg} onChange={(v) => upd('weight_kg', v)} type="number" />
            <F label={t('admin.md.volume_m3')} value={form.volume_m3} onChange={(v) => upd('volume_m3', v)} type="number" />
            <F label={t('admin.md.lead_time')} value={form.lead_time_days} onChange={(v) => upd('lead_time_days', v)} type="number" />
            <F label={t('admin.md.reorder')} value={form.reorder_point} onChange={(v) => upd('reorder_point', v)} type="number" />
            <F label={t('admin.md.safety')} value={form.safety_stock} onChange={(v) => upd('safety_stock', v)} type="number" />
          </div>
          {create.isError && <p className="text-sm text-danger mt-2">{(create.error as Error).message}</p>}
          <div className="flex justify-end gap-2 mt-4"><Button variant="secondary" onClick={reset} disabled={create.isPending}>{t('common.cancel')}</Button><Button onClick={submit} disabled={!form.code.trim() || !form.name.trim() || !form.weight_kg || !form.volume_m3} loading={create.isPending}>{t('common.confirm')}</Button></div>
        </div>
      )}
      {rows.length === 0 ? <EmptyState title={t('admin.md.no_skus')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.code')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.name')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.unit')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">kg</th>
            <th className="text-right px-4 py-3 font-medium text-muted">m³</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead>
          <tbody>{rows.map((s) => (
            <tr key={s.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-mono text-xs">{s.code}</td>
              <td className="px-4 py-3">{s.name}</td>
              <td className="px-4 py-3">{s.unit}</td>
              <td className="px-4 py-3 text-right tabular-nums">{s.weight_kg}</td>
              <td className="px-4 py-3 text-right tabular-nums">{s.volume_m3}</td>
              <td className="px-4 py-3"><StatusPill tone={s.active ? 'success' : 'neutral'}>{s.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
              <td className="px-4 py-3 text-right"><Button size="sm" variant={s.active ? 'ghost' : 'secondary'} onClick={() => toggle.mutate({ id: s.id, active: !s.active })}>{s.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
function F({ label, value, onChange, type = 'text' }: { label: string; value: string; onChange: (v: string) => void; type?: 'text' | 'number' }) {
  return <label className="text-sm"><span className="text-muted block mb-1">{label}</span><input type={type} value={value} onChange={(e) => onChange(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>;
}
