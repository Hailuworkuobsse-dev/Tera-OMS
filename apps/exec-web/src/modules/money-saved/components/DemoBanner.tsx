import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
export function DemoBanner({ onStartRealBaseline, isStarting }: { onStartRealBaseline: () => void; isStarting: boolean }) {
  const { t } = useI18n();
  return (
    <div className="rounded-lg border border-warn/40 bg-warnBg p-4 flex items-start gap-4">
      <div className="text-2xl">⚠</div>
      <div className="flex-1"><p className="font-medium text-warn">{t('exec.demo.title')}</p><p className="text-sm text-muted mt-1">{t('exec.demo.body')}</p></div>
      <Button variant="secondary" onClick={onStartRealBaseline} loading={isStarting}>{t('exec.demo.start')}</Button>
    </div>
  );
}
