export type Decision = 'BLOCKED' | 'WARNED' | 'CLEARED';
export type Reason = 'OVER_LIMIT' | 'PAST_GRACE' | 'BOTH' | 'NONE';

export interface RuleInput {
  exposureEtb: number;
  limitEtb: number;
  daysOverdue: number;
  graceDays: number;
}

export interface RuleResult {
  triggered: boolean;
  reason: Reason;
  overLimit: boolean;
  pastGrace: boolean;
}

export function evaluateRule(input: RuleInput): RuleResult {
  const overLimit = input.exposureEtb > input.limitEtb;
  const pastGrace = input.daysOverdue > input.graceDays;
  if (overLimit && pastGrace) return { triggered: true, reason: 'BOTH', overLimit, pastGrace };
  if (overLimit) return { triggered: true, reason: 'OVER_LIMIT', overLimit, pastGrace };
  if (pastGrace) return { triggered: true, reason: 'PAST_GRACE', overLimit, pastGrace };
  return { triggered: false, reason: 'NONE', overLimit, pastGrace };
}

export function decide(triggered: boolean, hasOverride: boolean, hardGate: boolean): Decision {
  if (!triggered) return 'CLEARED';
  if (hasOverride) return 'WARNED';
  return hardGate ? 'BLOCKED' : 'WARNED';
}
