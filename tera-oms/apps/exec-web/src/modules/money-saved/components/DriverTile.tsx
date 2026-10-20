import { useI18n, formatETB } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import { Sparkline } from './Sparkline';
import type { Tile } from '../types';

export function DriverTile({ tile }: { tile: Tile }) {
  const { t } = useI18n();
  const tone: 'success' | 'warn' | 'neutral' = tile.fully_in_target ? 'success' : tile.in_target ? 'warn' : 'neutral';
  const badge = tile.fully_in_target ? t('exec.tile.fully_in_target') : tile.in_target ? t('exec.tile.in_target') : t('exec.tile.below_target');
  const arrow = tile.improvement_pct >= 0 ? '↑' : '↓';
  const sparkColor = tile.fully_in_target ? '#166534' : tile.in_target ? '#b45309' : '#6b6b6b';
  return (
    <div className="rounded-lg border border-border bg-surface p-4 flex flex-col gap-3">
      <div className="flex items-start justify-between gap-2"><p className="text-sm font-medium leading-tight">{t(tile.label_key)}</p><StatusPill tone={tone}>{badge}</StatusPill></div>
      <div className="flex items-baseline gap-2"><p className="text-2xl font-bold tabular-nums">{formatValue(tile.current, tile.unit)}</p><p className="text-xs text-muted">{tile.unit}</p></div>
      <div className="flex items-center justify-between gap-2">
        <div className="text-xs text-muted">{formatValue(tile.baseline, tile.unit)} → {formatValue(tile.current, tile.unit)}
          <span className={`ml-2 font-medium ${tile.improvement_pct >= 0 ? 'text-success' : 'text-danger'}`}>{arrow} {Math.abs(tile.improvement_pct).toFixed(1)}%</span></div>
        <Sparkline data={tile.trend_7d} color={sparkColor} />
      </div>
      {tile.etb_impact !== null && <div className="text-xs text-primary border-t border-border pt-2">≈ {formatETB(tile.etb_impact)} {t('exec.tile.etb_impact')}</div>}
    </div>
  );
}
function formatValue(v: number, unit: string): string {
  if (unit === 'ETB') return new Intl.NumberFormat('en-ET', { maximumFractionDigits: 0 }).format(v);
  if (unit === '%') return `${v.toFixed(1)}%`;
  if (unit === 'SKU-days') return String(Math.round(v));
  return v.toFixed(1);
}
