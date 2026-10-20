import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { SolveResponse, SolveSequence } from '../types';

function SequenceColumn({ title, seq, tone }: { title: string; seq: SolveSequence; tone: 'neutral' | 'primary' }) {
  return (
    <div className={`border rounded-md bg-surface ${tone === 'primary' ? 'border-primary' : 'border-border'}`}>
      <div className={`px-3 py-2 border-b ${tone === 'primary' ? 'border-primary bg-primary/5' : 'border-border'}`}>
        <div className="font-medium text-sm">{title}</div>
        <div className="text-xs text-muted mt-0.5">{seq.total_km.toFixed(1)} km · {seq.total_min} min</div>
      </div>
      <ol className="divide-y divide-border">
        {seq.stops.map((s) => (
          <li key={s.order_id} className="px-3 py-2 flex items-center gap-2 text-sm">
            <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-bg border border-border text-xs font-medium">{s.seq}</span>
            <div className="flex-1 min-w-0">
              <div className="font-medium truncate">{s.distributor_name}</div>
              <div className="text-xs text-muted">ETA {new Date(s.eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
}
export function ComparisonView({ solution }: { solution: SolveResponse }) {
  const { t } = useI18n();
  return (
    <div>
      {solution.infeasible && (
        <div className="mb-3 border border-danger/30 bg-dangerBg rounded-md p-3 text-sm text-danger">
          <strong>{t('route_builder.infeasible')}:</strong> {solution.infeasible.reason}
        </div>
      )}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SequenceColumn title={t('route_builder.manual')} seq={solution.manual} tone="neutral" />
        <SequenceColumn title={t('route_builder.optimized')} seq={solution.optimized} tone="primary" />
      </div>
      <div className="mt-4 flex items-center justify-center gap-3">
        <StatusPill tone={solution.savings_km_pct > 0 ? 'success' : 'neutral'}>{solution.savings_km_pct.toFixed(1)}% {t('route_builder.km_saved')}</StatusPill>
        <StatusPill tone={solution.savings_time_pct > 0 ? 'success' : 'neutral'}>{solution.savings_time_pct.toFixed(1)}% {t('route_builder.time_saved')}</StatusPill>
      </div>
    </div>
  );
}
