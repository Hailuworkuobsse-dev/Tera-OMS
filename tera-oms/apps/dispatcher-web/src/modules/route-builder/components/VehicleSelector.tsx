import { useI18n } from '@tera/i18n';
import type { Vehicle } from '../types';
export function VehicleSelector({ vehicles, selected, onSelect }: { vehicles: Vehicle[]; selected: string | null; onSelect: (id: string) => void }) {
  const { t } = useI18n();
  return (
    <div className="border border-border rounded-md bg-surface">
      <div className="px-3 py-2 border-b border-border text-sm font-medium">{t('route_builder.vehicle')}</div>
      <ul>
        {vehicles.map((v) => (
          <li key={v.id}>
            <button onClick={() => onSelect(v.id)}
              className={`w-full text-left px-3 py-2 text-sm border-b border-border last:border-0 ${selected === v.id ? 'bg-bg font-medium' : 'hover:bg-bg'}`}>
              <div>{v.plate}</div>
              <div className="text-xs text-muted">{v.capacity_kg} kg · {v.capacity_m3} m³ · shift {v.shift_start_h}:00–{v.shift_end_h}:00</div>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
