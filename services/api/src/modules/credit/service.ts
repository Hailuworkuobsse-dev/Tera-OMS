import { getFlag } from '../config/service.js';
import { writeAudit } from '../../core/audit.js';
import * as repo from './repository.js';
import { evaluateRule, decide } from './rules.js';
import { enrichAccount, bucketForDaysOverdue, type RawAccount } from './finance.js';
import type {
  CreditStopRow, CreditStopListResponse,
  ExposureResponse, AgingBucket,
  OverridesListResponse, OverrideRow,
} from '@tera/contracts';

export async function getStopList(): Promise<CreditStopListResponse> {
  const hardGate = await getFlag('credit.hardGate', false);
  const accounts = await repo.findAccounts();
  const now = Date.now();
  const rows: CreditStopRow[] = [];

  for (const a of accounts) {
    const limitEtb = Number(a.limitEtb);
    const exposureEtb = Number(a.exposureEtb);
    const daysOverdue = a.oldestUnpaidAt
      ? Math.floor((now - a.oldestUnpaidAt.getTime()) / 86_400_000)
      : 0;
    const trigger = evaluateRule({ exposureEtb, limitEtb, daysOverdue, graceDays: a.graceDays });
    const override = a.overrides[0];
    const decision = decide(trigger.triggered, Boolean(override), hardGate);
    if (decision === 'CLEARED') continue;

    rows.push({
      distributor_id: a.distributorId,
      distributor_name: a.distributor.name,
      region: a.distributor.region,
      decision,
      reason: trigger.reason,
      amount_owed_etb: exposureEtb,
      credit_limit_etb: limitEtb,
      exposure_etb: exposureEtb,
      days_overdue: daysOverdue,
      grace_days: a.graceDays,
      blocked_at: a.updatedAt.toISOString(),
      active_override_until: override ? override.expiresAt.toISOString() : null,
    });

    void repo.recordDecision({
      accountId: a.id, outcome: decision, reason: trigger.reason,
      exposureEtb, limitEtb, daysOverdue,
    });
  }

  const order: Record<string, number> = { BLOCKED: 0, WARNED: 1, CLEARED: 2 };
  rows.sort((x, y) => {
    const d = order[x.decision]! - order[y.decision]!;
    return d !== 0 ? d : y.amount_owed_etb - x.amount_owed_etb;
  });

  return { as_of: new Date().toISOString(), hard_gate: hardGate, rows };
}

export async function createOverride(input: {
  distributorId: string; reason: string; actorId: string; expiresAt: Date;
}): Promise<{ expiresAt: Date }> {
  if (input.expiresAt.getTime() <= Date.now()) {
    const err = new Error('expires_at must be in the future') as any;
    err.statusCode = 400; throw err;
  }
  const override = await repo.createOverride(input);
  await writeAudit({
    actorId: input.actorId, entity: 'credit_override', entityId: override.id,
    action: 'create', reason: input.reason,
    meta: { distributorId: input.distributorId, expiresAt: input.expiresAt.toISOString() },
  });
  return { expiresAt: override.expiresAt };
}

export async function getExposure(): Promise<ExposureResponse> {
  const rows = await repo.findAllAccountsForFinance();
  const enriched = rows.map((a) => enrichAccount({
    distributorId: a.distributorId,
    distributorName: a.distributor.name,
    region: a.distributor.region,
    limitEtb: Number(a.limitEtb),
    exposureEtb: Number(a.exposureEtb),
    oldestUnpaidAt: a.oldestUnpaidAt,
    graceDays: a.graceDays,
  }));

  const totalExposure = enriched.reduce((s, a) => s + a.exposure_etb, 0);
  const totalLimit = enriched.reduce((s, a) => s + a.limit_etb, 0);

  const bucketDefs: { label: AgingBucket['label']; range: string }[] = [
    { label: 'current',  range: '0 days overdue' },
    { label: 'watch',    range: '1–14 days' },
    { label: 'overdue',  range: '15–30 days' },
    { label: 'critical', range: '31+ days' },
  ];

  const agingBuckets: AgingBucket[] = bucketDefs.map((b) => {
    const members = enriched.filter((a) => bucketForDaysOverdue(a.days_overdue) === b.label);
    return {
      label: b.label, days_range: b.range,
      account_count: members.length,
      exposure_etb: members.reduce((s, a) => s + a.exposure_etb, 0),
    };
  });

  const nearLimit = enriched
    .filter((a) => a.limit_etb > 0 && a.exposure_etb / a.limit_etb >= 0.8)
    .sort((a, b) => b.utilization_pct - a.utilization_pct);

  return {
    as_of: new Date().toISOString(),
    total_exposure_etb: Math.round(totalExposure),
    total_limit_etb: Math.round(totalLimit),
    utilization_pct: totalLimit > 0 ? Math.round((totalExposure / totalLimit) * 10000) / 100 : 0,
    accounts_over_limit: enriched.filter((a) => a.exposure_etb > a.limit_etb).length,
    accounts_past_grace: enriched.filter((a) => a.days_overdue > 0).length,
    aging_buckets: agingBuckets,
    near_limit_accounts: nearLimit,
    all_accounts: [...enriched].sort((a, b) => b.exposure_etb - a.exposure_etb),
  };
}

export async function listOverrides(limit = 100): Promise<OverridesListResponse> {
  const rows = await repo.findAllOverrides(limit);
  const distributorIds = Array.from(new Set(rows.map((r) => r.distributorId)));
  const distributors = await repo.findDistributorsByIds(distributorIds);
  const nameById = new Map(distributors.map((d) => [d.id, d.name]));
  const now = Date.now();

  const overrides: OverrideRow[] = rows.map((o) => ({
    id: o.id,
    distributor_id: o.distributorId,
    distributor_name: nameById.get(o.distributorId) ?? '(unknown)',
    reason: o.reason, actor_id: o.actorId,
    created_at: o.createdAt.toISOString(),
    expires_at: o.expiresAt.toISOString(),
    expired: o.expiresAt.getTime() < now,
  }));

  return { total: overrides.length, overrides };
}
