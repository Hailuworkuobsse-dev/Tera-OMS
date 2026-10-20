import { Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';
export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="min-h-full bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3">
        <div className="max-w-6xl mx-auto flex items-center gap-4">
          <div className="flex-1"><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('exec.title')}</p></div>
          <p className="text-sm text-muted">{t('exec.tagline')}</p>
        </div>
      </header>
      <main className="p-6"><div className="max-w-6xl mx-auto"><Outlet /></div></main>
    </div>
  );
}
