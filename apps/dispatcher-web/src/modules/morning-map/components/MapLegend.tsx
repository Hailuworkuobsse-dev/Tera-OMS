import { useI18n } from '@tera/i18n';
export function MapLegend() {
  const { t } = useI18n();
  return (
    <div className="flex flex-wrap gap-4 text-xs text-muted bg-surface border border-border rounded-md px-3 py-2">
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-full bg-primary" />{t('morning_map.legend.route')}</span>
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-full bg-gray-400" />{t('morning_map.legend.delivered')}</span>
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-sm bg-red-100 border border-red-400 border-dashed" />{t('morning_map.legend.curfew')}</span>
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-full bg-amber-500" />{t('morning_map.legend.fuel')}</span>
    </div>
  );
}
