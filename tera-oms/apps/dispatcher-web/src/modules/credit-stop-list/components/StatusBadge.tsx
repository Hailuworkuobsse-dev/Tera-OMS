import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { CreditDecision, CreditReason } from '../types';

const TONE = { BLOCKED: 'danger', WARNED: 'warn', CLEARED: 'success' } as const;
const DECISION_KEY: Record<CreditDecision, string> = {
  BLOCKED: 'credit.status.blocked', WARNED: 'credit.status.warned', CLEARED: 'credit.status.cleared',
};
const REASON_KEY: Record<CreditReason, string> = {
  OVER_LIMIT: 'credit.reason.over_limit', PAST_GRACE: 'credit.reason.past_grace',
  BOTH: 'credit.reason.both', NONE: 'credit.status.cleared',
};
export function StatusBadge({ decision }: { decision: CreditDecision }) {
  const { t } = useI18n();
  return <StatusPill tone={TONE[decision]}>{t(DECISION_KEY[decision])}</StatusPill>;
}
export function ReasonText({ reason }: { reason: CreditReason }) {
  const { t } = useI18n();
  if (reason === 'NONE') return null;
  return <span className="text-muted text-xs">{t(REASON_KEY[reason])}</span>;
}
