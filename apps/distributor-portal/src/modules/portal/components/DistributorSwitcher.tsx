import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { getCurrentDistributor, setCurrentDistributor } from '../../../api/client';
const KNOWN = [
  { id: 'seed-dist-1', name: 'Abebe Distribution' }, { id: 'seed-dist-2', name: 'Bole Wholesale Co.' },
  { id: 'seed-dist-3', name: 'Kazanchis Distributors' }, { id: 'seed-dist-4', name: 'Sarbet Traders' }, { id: 'seed-dist-5', name: 'CMC Retailers' },
];
export function DistributorSwitcher() {
  const { t } = useI18n(); const current = getCurrentDistributor() ?? KNOWN[0]!.id; const [open, setOpen] = useState(false);
  const pick = (id: string) => { setCurrentDistributor(id); window.location.reload(); };
  return (
    <div className="relative">
      <button onClick={() => setOpen((v) => !v)} className="text-sm px-3 py-1.5 rounded-md border border-border bg-surface hover:bg-bg">{t('portal.switcher.label')} ▾</button>
      {open && <div className="absolute right-0 top-full mt-1 z-20 min-w-[220px] border border-border bg-surface rounded-md shadow-md">{KNOWN.map((d) => <button key={d.id} onClick={() => pick(d.id)} className={`block w-full text-left px-3 py-2 text-sm hover:bg-bg ${current === d.id ? 'font-medium bg-bg' : ''}`}>{d.name}</button>)}</div>}
    </div>
  );
}
