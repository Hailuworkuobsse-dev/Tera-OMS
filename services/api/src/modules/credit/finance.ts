export type AgingBucketLabel = 'current' | 'watch' | 'overdue' | 'critical';

export function bucketForDaysOverdue(daysOverdue: number): AgingBucketLabel {
  if (daysOverdue <= 0) return 'current';
  if (daysOverdue <= 14) return 'watch';
  if (daysOverdue <= 30) return 'overdue';
  return 'critical';
}

export interface RawAccount {
  distributorId: string;
  distributorName: string;
  region: string;
  limitEtb: number;
  exposureEtb: number;
  oldestUnpaidAt: Date | null;
  graceDays: number;
}

export interface EnrichedAccount {
  distributor_id: string;
  distributor_name: string;
  region: string;
  exposure_etb: number;
  limit_etb: number;
  utilization_pct: number;
  days_since_oldest_unpaid: number;
  grace_days: number;
  days_overdue: number;
}

export function enrichAccount(a: RawAccount, now: Date = new Date()): EnrichedAccount {
  const daysSince = a.oldestUnpaidAt
    ? Math.floor((now.getTime() - a.oldestUnpaidAt.getTime()) / 86_400_000)
    : 0;
  const daysOverdue = Math.max(0, daysSince - a.graceDays);
  const utilization = a.limitEtb > 0 ? (a.exposureEtb / a.limitEtb) * 100 : 0;
  return {
    distributor_id: a.distributorId,
    distributor_name: a.distributorName,
    region: a.region,
    exposure_etb: Math.round(a.exposureEtb),
    limit_etb: Math.round(a.limitEtb),
    utilization_pct: Math.round(utilization * 100) / 100,
    days_since_oldest_unpaid: daysSince,
    grace_days: a.graceDays,
    days_overdue: daysOverdue,
  };
}
