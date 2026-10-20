import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import { useAssumptions, useUpdateAssumption } from '../hooks';
import type { CostAssumption } from '../types';

const LABELS: Record<string, string> = {
  monthly_deliveries: 'exec.assumption.monthly_deliveries', monthly_routes: 'exec.assumption.monthly_routes',
  daily_vehicles: 'exec.assumption.daily_vehicles', vehicle_wear_etb_per_km: 'exec.assumption.vehicle_wear',
  margin_per_sku_day_etb: 'exec.assumption.margin_sku', cost_per_fuel_incident_etb: 'exec.assumption.fuel_incident',
  avg_margin_per_delivery_etb: 'exec.assumption.margin_delivery',
};
export function AssumptionsPanel() {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const list = useAssumptions(); const update = useUpdateAssumption();
  if (!open) return <button onClick={() => setOpen(true)} className="text-sm text-muted hover:text-text underline">{t('exec.assumptions.configure')}</button>;
  return (
    <div className="rounded-lg border border-border bg-surface p-4">
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm font-semibold">{t('exec.assumptions.title')}</p>
        <button onClick={() => setOpen(false)} className="text-sm text-muted hover:text-text">{t('common.cancel')}</button>
      </div>
      {list.data && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {list.data.assumptions.map((a) => <Row key={a.key} assumption={a} onChange={(v) => update.mutate({ key: a.key, value: v })} isSaving={update.isPending && update.variables?.key === a.key} />)}
        </div>
      )}
    </div>
  );
}
function Row({ assumption, onChange, isSaving }: { assumption: CostAssumption; onChange: (v: number) => void; isSaving: boolean }) {
  const { t } = useI18n();
  const [value, setValue] = useState(String(assumption.value));
  const dirty = parseFloat(value) !== assumption.value;
  return (
    <div className="text-sm"><p className="text-muted mb-1">{t(LABELS[assumption.key] ?? assumption.key)}</p>
      <div className="flex gap-2"><input type="number" value={value} onChange={(e) => setValue(e.target.value)} className="flex-1 rounded-md border border-border bg-bg px-2 py-1" />
        <span className="text-xs text-muted self-center">{assumption.unit}</span>
        {dirty && <Button size="sm" onClick={() => onChange(parseFloat(value))} loading={isSaving}>{t('common.confirm')}</Button>}
      </div></div>
  );
}
