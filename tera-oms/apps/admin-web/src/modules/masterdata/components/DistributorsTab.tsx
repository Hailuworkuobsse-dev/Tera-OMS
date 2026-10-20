import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useDistributors, useCreateDistributor, useToggleDistributorActive } from '../hooks';

export function DistributorsTab() {
  const { t } = useI18n();
  const list = useDistributors(); const create = useCreateDistributor(); const toggle = useToggleDistributorActive();
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState(''); const [region, setRegion] = useState('');
  const reset = () => { setName(''); setRegion(''); setShowForm(false); };
  const submit = () => { if (!name.trim() || !region.trim()) return; create.mutate({ name: name.trim(), region: region.trim() }, { onSuccess: reset }); };
  if (list.isLoading) return <Spinner label={t('common.loading')} />;
  if (list.isError || !list.data) return <div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">{t('common.error')}{' '}<button onClick={() => list.refetch()} className="underline">{t('common.retry')}</button></div>;
  const rows = list.data.distributors;
  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-muted">{rows.length} {t('admin.md.distributors_count')}</p>
        {!showForm && <Button onClick={() => setShowForm(true)}>{t('admin.md.add')}</Button>}
      </div>
      {showForm && (
        <div className="border border-primary/30 bg-surface rounded-md p-4 mb-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <label className="text-sm"><span className="text-muted block mb-1">{t('admin.md.name')}</span><input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
            <label className="text-sm"><span className="text-muted block mb-1">{t('admin.md.region')}</span><input value={region} onChange={(e) => setRegion(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          </div>
          {create.isError && <p className="text-sm text-danger mt-2">{(create.error as Error).message}</p>}
          <div className="flex justify-end gap-2 mt-4"><Button variant="secondary" onClick={reset} disabled={create.isPending}>{t('common.cancel')}</Button><Button onClick={submit} disabled={!name.trim() || !region.trim()} loading={create.isPending}>{t('common.confirm')}</Button></div>
        </div>
      )}
      {rows.length === 0 ? <EmptyState title={t('admin.md.no_distributors')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-bg border-b border-border"><tr>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.name')}</th>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.region')}</th>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
              <th className="text-right px-4 py-3"></th>
            </tr></thead>
            <tbody>
              {rows.map((d) => (
                <tr key={d.id} className="border-b border-border last:border-0">
                  <td className="px-4 py-3">{d.name}</td><td className="px-4 py-3">{d.region}</td>
                  <td className="px-4 py-3"><StatusPill tone={d.active ? 'success' : 'neutral'}>{d.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
                  <td className="px-4 py-3 text-right"><Button size="sm" variant={d.active ? 'ghost' : 'secondary'} onClick={() => toggle.mutate({ id: d.id, active: !d.active })} disabled={toggle.isPending}>{d.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
