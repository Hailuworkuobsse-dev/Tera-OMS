import { z } from 'zod';

export const CreditDecisionEnum = z.enum(['BLOCKED', 'WARNED', 'CLEARED']);
export const CreditReasonEnum = z.enum(['OVER_LIMIT', 'PAST_GRACE', 'BOTH', 'NONE']);

export const CreditStopRowSchema = z.object({
  distributor_id: z.string(), distributor_name: z.string(), region: z.string(),
  decision: CreditDecisionEnum, reason: CreditReasonEnum,
  amount_owed_etb: z.number(), credit_limit_etb: z.number(), exposure_etb: z.number(),
  days_overdue: z.number().int().nonnegative(), grace_days: z.number().int().nonnegative(),
  blocked_at: z.string().datetime(), active_override_until: z.string().datetime().nullable(),
});

export const CreditStopListResponseSchema = z.object({
  as_of: z.string().datetime(), hard_gate: z.boolean(),
  rows: z.array(CreditStopRowSchema),
});

export const OverrideRequestSchema = z.object({
  distributor_id: z.string().min(1),
  reason: z.string().trim().min(5),
  expires_at: z.string().datetime(),
});

export const OverrideResponseSchema = z.object({
  ok: z.literal(true), expires_at: z.string().datetime(),
});

export const AgingBucketLabelEnum = z.enum(['current', 'watch', 'overdue', 'critical']);

export const ExposureAccountSchema = z.object({
  distributor_id: z.string(), distributor_name: z.string(), region: z.string(),
  exposure_etb: z.number(), limit_etb: z.number(), utilization_pct: z.number(),
  days_since_oldest_unpaid: z.number().int(),
  grace_days: z.number().int(), days_overdue: z.number().int(),
});

export const AgingBucketSchema = z.object({
  label: AgingBucketLabelEnum, days_range: z.string(),
  account_count: z.number().int(), exposure_etb: z.number(),
});

export const ExposureResponseSchema = z.object({
  as_of: z.string().datetime(),
  total_exposure_etb: z.number(), total_limit_etb: z.number(), utilization_pct: z.number(),
  accounts_over_limit: z.number().int(), accounts_past_grace: z.number().int(),
  aging_buckets: z.array(AgingBucketSchema),
  near_limit_accounts: z.array(ExposureAccountSchema),
  all_accounts: z.array(ExposureAccountSchema),
});

export const OverrideRowSchema = z.object({
  id: z.string(), distributor_id: z.string(), distributor_name: z.string(),
  reason: z.string(), actor_id: z.string(),
  created_at: z.string().datetime(), expires_at: z.string().datetime(), expired: z.boolean(),
});

export const OverridesListResponseSchema = z.object({
  total: z.number().int(), overrides: z.array(OverrideRowSchema),
});

export type CreditDecision = z.infer<typeof CreditDecisionEnum>;
export type CreditReason = z.infer<typeof CreditReasonEnum>;
export type CreditStopRow = z.infer<typeof CreditStopRowSchema>;
export type CreditStopListResponse = z.infer<typeof CreditStopListResponseSchema>;
export type OverrideRequest = z.infer<typeof OverrideRequestSchema>;
export type ExposureAccount = z.infer<typeof ExposureAccountSchema>;
export type AgingBucket = z.infer<typeof AgingBucketSchema>;
export type ExposureResponse = z.infer<typeof ExposureResponseSchema>;
export type OverrideRow = z.infer<typeof OverrideRowSchema>;
export type OverridesListResponse = z.infer<typeof OverridesListResponseSchema>;
