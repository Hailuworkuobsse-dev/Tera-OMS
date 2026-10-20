import { useI18n, formatETB } from '@tera/i18n';
import type { Hero } from '../types';
export function HeroTile({ hero }: { hero: Hero }) {
  const { t } = useI18n();
  return (
    <div className="rounded-lg border border-primary/30 bg-gradient-to-br from-primary/5 to-primary/10 p-8">
      <p className="text-sm font-medium text-primary uppercase tracking-wide mb-2">{t('exec.hero.label')}</p>
      <div className="flex items-baseline gap-3 flex-wrap">
        <p className="text-5xl font-bold text-primary tabular-nums">{formatETB(hero.monthly_savings_etb)}</p>
        <p className="text-sm text-muted">{t('exec.hero.per_month')}</p>
      </div>
      <div className="grid grid-cols-2 gap-4 mt-6 max-w-lg">
        <div><p className="text-xs text-muted uppercase">{t('exec.hero.cumulative')}</p>
          <p className="text-xl font-semibold tabular-nums">{formatETB(hero.cumulative_savings_etb)}</p>
          <p className="text-xs text-muted">{hero.days_since_baseline} {t('exec.hero.days')}</p></div>
        <div><p className="text-xs text-muted uppercase">{t('exec.hero.annualized')}</p>
          <p className="text-xl font-semibold tabular-nums">{formatETB(hero.annualized_savings_etb)}</p>
          <p className="text-xs text-muted">{t('exec.hero.per_year')}</p></div>
      </div>
    </div>
  );
}
