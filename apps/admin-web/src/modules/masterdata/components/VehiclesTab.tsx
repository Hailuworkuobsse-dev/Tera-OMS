import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useVehicles, useCreateVehicle, useToggleVehicleActive } from '../hooks';
const EMPTY = { plate: '', capacity_kg: '', capacity_m3: '', shift_start_h: '7', shift_end_h: '18', start_lat: '9.0108', start_lng: '38.7613', baseline_l_per_100km: '' };

export function VehiclesTab() {
  const { t } = useI18n();
  const list = useVehicles(); const create = useCreateVehicle(); const toggle = useToggleVehicleActive();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const upd = (k: keyof typeof EMPTY, v: string) => setForm({ ...form, [k]: v });
  const reset = () => { setForm(EMPTY); setShowForm(false); };
  const submit = () => { create.mutate({
    plate: form.plate.trim(), capacity_kg: parseFloat(form.capacity_kg), capacity_m3: parseFloat(form.capacity_m3),
    shift_start_h: parseInt(form.shift_start_h, 10), shift_end_h: parseInt(form.shift_end_h, 10),
    start_lat: parseFloat(form.start_lat), start_lng: parseFloat(form.start_lng),
    baseline_l_per_100km: form.baseline_l_per_100km.trim() ? parseFloat(form.baseline_l_per_100km) : null,
  }, { onSuccess: reset }); };
  if (list.isLoading) return <Spinner label={t('common.loading')} />;
  if (list.isError || !list.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const rows = list.data.vehicles;
  return (
    <div>
      <div className="flex items-center justify-between mb-4"><p className="text-sm text-muted">{rows.length} {t('admin.md.vehicles_count')}</p>{!showForm && <Button onClick={() => setShowForm(true)}>{t('admin.md.add')}</Button>}</div>
      {showForm && (
        <div className="border border-primary/30 bg-surface rounded-md p-4 mb-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <Field label={t('admin.md.plate')} value={form.plate} onChange={(v) => upd('plate', v)} />
            <Field label={t('admin.md.capacity_kg')} value={form.capacity_kg} onChange={(v) => upd('capacity_kg', v)} type="number" />
            <Field label={t('admin.md.capacity_m3')} value={form.capacity_m3} onChange={(v) => upd('capacity_m3', v)} type="number" />
            <Field label={t('admin.md.baseline')} value={form.baseline_l_per_100km} onChange={(v) => upd('baseline_l_per_100km', v)} type="number" />
            <Field label={t('admin.md.shift_start')} value={form.shift_start_h} onChange={(v) => upd('shift_start_h', v)} type="number" />
            <Field label={t('admin.md.shift_end')} value={form.shift_end_h} onChange={(v) => upd('shift_end_h', v)} type="number" />
            <Field label={t('admin.md.start_lat')} value={form.start_lat} onChange={(v) => upd('start_lat', v)} type="number" />
            <Field label={t('admin.md.start_lng')} value={form.start_lng} onChange={(v) => upd('start_lng', v)} type="number" />
          </div>
          {create.isError && <p className="text-sm text-danger mt-2">{(create.error as Error).message}</p>}
          <div className="flex justify-end gap-2 mt-4"><Button variant="secondary" onClick={reset} disabled={create.isPending}>{t('common.cancel')}</Button><Button onClick={submit} disabled={!form.plate.trim() || !form.capacity_kg || !form.capacity_m3} loading={create.isPending}>{t('common.confirm')}</Button></div>
        </div>
      )}
      {rows.length === 0 ? <EmptyState title={t('admin.md.no_vehicles')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.plate')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">kg</th>
            <th className="text-right px-4 py-3 font-medium text-muted">m³</th>
            <th className="text-right px-4 py-3 font-medium text-muted">L/100km</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead>
          <tbody>{rows.map((v) => (
            <tr key={v.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-medium">{v.plate}</td>
              <td className="px-4 py-3 text-right tabular-nums">{v.capacity_kg}</td>
              <td className="px-4 py-3 text-right tabular-nums">{v.capacity_m3}</td>
              <td className="px-4 py-3 text-right tabular-nums">{v.baseline_l_per_100km ?? '—'}</td>
              <td className="px-4 py-3"><StatusPill tone={v.active ? 'success' : 'neutral'}>{v.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
              <td className="px-4 py-3 text-right"><Button size="sm" variant={v.active ? 'ghost' : 'secondary'} onClick={() => toggle.mutate({ id: v.id, active: !v.active })}>{v.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
function Field({ label, value, onChange, type = 'text' }: { label: string; value: string; onChange: (v: string) => void; type?: 'text' | 'number' }) {
  return <label className="text-sm"><span className="text-muted block mb-1">{label}</span><input type={type} value={value} onChange={(e) => onChange(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>;
}
