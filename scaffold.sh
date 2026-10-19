#!/usr/bin/env bash
# codegen-credit.sh — write real code for the credit vertical slice.
# Runs AFTER scaffold.sh. Overwrites scaffold placeholders. Idempotent.
set -euo pipefail

if [[ ! -d services/api || ! -d apps/dispatcher-web ]]; then
  echo "✗ run scaffold.sh first (repo root not found)" >&2
  exit 1
fi

echo "→ codegen: credit vertical slice"

# Overwrite helper (unlike scaffold's skip-if-exists).
W() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  echo "  write $path"
}

# ═══════════════════════════════════════════════════════════════════
# 1. PRISMA MODELS
# ═══════════════════════════════════════════════════════════════════

W packages/db/prisma/models/masterdata.prisma <<'EOF'
// Minimal master data — enough to unblock the credit module.
// Distributors, SKUs, vehicles arrive in their own modules.

model Distributor {
  id        String   @id @default(cuid())
  name      String   @db.VarChar(200)
  region    String   @db.VarChar(100)
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  creditAccounts CreditAccount[]

  @@index([region])
  @@map("masterdata_distributor")
}
EOF

W packages/db/prisma/models/config.prisma <<'EOF'
// Feature flags and tunables. Anything a pilot manager might change
// lives here — never in code.

model Setting {
  key       String   @id @db.VarChar(100)
  value     String   @db.Text
  updatedAt DateTime @updatedAt @map("updated_at")

  @@map("config_setting")
}
EOF

W packages/db/prisma/models/credit.prisma <<'EOF'
// ──────────────────────────────────────────────────────────────
// Credit module (B4). Tables prefixed credit_.
// Authoritative source: packages/db/prisma/models/credit.prisma
// Read/write access: services/api/src/modules/credit/repository.ts
// ──────────────────────────────────────────────────────────────

model CreditAccount {
  id             String    @id @default(cuid())
  distributorId  String    @unique @map("distributor_id")
  limitEtb       Decimal   @map("limit_etb") @db.Decimal(14, 2)
  graceDays      Int       @default(14) @map("grace_days")
  exposureEtb    Decimal   @default(0) @map("exposure_etb") @db.Decimal(14, 2)
  oldestUnpaidAt DateTime? @map("oldest_unpaid_at")
  createdAt      DateTime  @default(now()) @map("created_at")
  updatedAt      DateTime  @updatedAt @map("updated_at")

  distributor Distributor           @relation(fields: [distributorId], references: [id])
  decisions   CreditDecision[]
  overrides   CreditOverride[]
  ledger      ExposureLedgerEntry[]
  history     CreditLimitHistory[]

  @@map("credit_account")
}

model CreditDecision {
  id           String   @id @default(cuid())
  accountId    String   @map("account_id")
  orderId      String?  @map("order_id")
  outcome      String   @db.VarChar(16) // BLOCKED | WARNED | CLEARED
  reason       String   @db.VarChar(32) // OVER_LIMIT | PAST_GRACE | BOTH | NONE
  exposureEtb  Decimal  @map("exposure_etb") @db.Decimal(14, 2)
  limitEtb     Decimal  @map("limit_etb") @db.Decimal(14, 2)
  daysOverdue  Int      @map("days_overdue")
  createdAt    DateTime @default(now()) @map("created_at")

  account   CreditAccount    @relation(fields: [accountId], references: [id])
  overrides CreditOverride[]

  @@index([accountId, createdAt])
  @@map("credit_decision")
}

model CreditOverride {
  id            String   @id @default(cuid())
  decisionId    String?  @map("decision_id")
  distributorId String   @map("distributor_id")
  reason        String   @db.Text
  actorId       String   @map("actor_id")
  expiresAt     DateTime @map("expires_at")
  createdAt     DateTime @default(now()) @map("created_at")

  decision CreditDecision? @relation(fields: [decisionId], references: [id])

  @@index([distributorId, expiresAt])
  @@map("credit_override")
}

model CreditLimitHistory {
  id           String   @id @default(cuid())
  accountId    String   @map("account_id")
  oldLimitEtb  Decimal  @map("old_limit_etb") @db.Decimal(14, 2)
  newLimitEtb  Decimal  @map("new_limit_etb") @db.Decimal(14, 2)
  reason       String   @db.Text
  actorId      String   @map("actor_id")
  createdAt    DateTime @default(now()) @map("created_at")

  account CreditAccount @relation(fields: [accountId], references: [id])

  @@index([accountId, createdAt])
  @@map("credit_limit_history")
}

model ExposureLedgerEntry {
  id         String   @id @default(cuid())
  accountId  String   @map("account_id")
  orderId    String?  @map("order_id")
  paymentId  String?  @map("payment_id")
  deltaEtb   Decimal  @db.Decimal(14, 2)
  type       String   @db.VarChar(16) // ORDER | PAYMENT | ADJUSTMENT
  createdAt  DateTime @default(now()) @map("created_at")

  account CreditAccount @relation(fields: [accountId], references: [id])

  @@index([accountId, createdAt])
  @@map("exposure_ledger_entry")
}
EOF

# ═══════════════════════════════════════════════════════════════════
# 2. CONTRACTS (Zod — shared by API, web, mobile)
# ═══════════════════════════════════════════════════════════════════

W packages/contracts/src/credit.ts <<'EOF'
import { z } from 'zod';

export const CreditDecisionEnum = z.enum(['BLOCKED', 'WARNED', 'CLEARED']);
export const CreditReasonEnum = z.enum(['OVER_LIMIT', 'PAST_GRACE', 'BOTH', 'NONE']);

export const CreditStopRowSchema = z.object({
  distributor_id: z.string(),
  distributor_name: z.string(),
  region: z.string(),
  decision: CreditDecisionEnum,
  reason: CreditReasonEnum,
  amount_owed_etb: z.number(),
  credit_limit_etb: z.number(),
  exposure_etb: z.number(),
  days_overdue: z.number().int().nonnegative(),
  grace_days: z.number().int().nonnegative(),
  blocked_at: z.string().datetime(),
  active_override_until: z.string().datetime().nullable(),
});

export const CreditStopListResponseSchema = z.object({
  as_of: z.string().datetime(),
  hard_gate: z.boolean(),
  rows: z.array(CreditStopRowSchema),
});

export const OverrideRequestSchema = z.object({
  distributor_id: z.string().min(1),
  reason: z.string().trim().min(5, 'reason must be at least 5 characters'),
  expires_at: z.string().datetime(),
});

export const OverrideResponseSchema = z.object({
  ok: z.literal(true),
  expires_at: z.string().datetime(),
});

export type CreditDecision = z.infer<typeof CreditDecisionEnum>;
export type CreditReason = z.infer<typeof CreditReasonEnum>;
export type CreditStopRow = z.infer<typeof CreditStopRowSchema>;
export type CreditStopListResponse = z.infer<typeof CreditStopListResponseSchema>;
export type OverrideRequest = z.infer<typeof OverrideRequestSchema>;
EOF

W packages/contracts/src/index.ts <<'EOF'
export * from './credit.js';
EOF

W packages/contracts/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true },
  "include": ["src"]
}
EOF

# ═══════════════════════════════════════════════════════════════════
# 3. API — CONFIG SERVICE (flag reader used by credit service)
# ═══════════════════════════════════════════════════════════════════

W services/api/src/modules/config/service.ts <<'EOF'
import { db } from '@tera/db';

export async function getFlag(key: string, defaultValue: boolean): Promise<boolean> {
  const row = await db().setting.findUnique({ where: { key } });
  if (!row) return defaultValue;
  return row.value === 'true';
}

export async function setFlag(key: string, value: boolean): Promise<void> {
  await db().setting.upsert({
    where: { key },
    create: { key, value: value ? 'true' : 'false' },
    update: { value: value ? 'true' : 'false' },
  });
}
EOF

# ═══════════════════════════════════════════════════════════════════
# 4. API — AUDIT (real implementation)
# ═══════════════════════════════════════════════════════════════════

W services/api/src/core/audit.ts <<'EOF'
import { db } from '@tera/db';
import { createHash } from 'node:crypto';

export interface AuditEntry {
  actorId: string;
  entity: string;
  entityId: string;
  action: string;
  reason: string;
  meta?: Record<string, unknown>;
}

/**
 * Append-only audit. Every override goes through here.
 * The override registry is the richest source for tuning the
 * credit rule and the solver — never skip a write.
 */
export async function writeAudit(entry: AuditEntry): Promise<void> {
  // Stored in config_setting for pilot simplicity; promoted to a
  // dedicated `audit_log` table when volume justifies it.
  const id = createHash('sha256')
    .update(`${entry.actorId}:${entry.entity}:${entry.entityId}:${entry.action}:${Date.now()}`)
    .digest('hex')
    .slice(0, 32);
  await db().setting.upsert({
    where: { key: `audit:${id}` },
    create: { key: `audit:${id}`, value: JSON.stringify({ ...entry, at: new Date().toISOString() }) },
    update: {},
  });
}
EOF

# ═══════════════════════════════════════════════════════════════════
# 5. API — CREDIT MODULE
# ═══════════════════════════════════════════════════════════════════

W services/api/src/modules/credit/schemas.ts <<'EOF'
// Re-export the shared contracts so routes and services import from one place.
export {
  CreditStopListResponseSchema,
  OverrideRequestSchema,
  OverrideResponseSchema,
  CreditStopRowSchema,
  CreditDecisionEnum,
  CreditReasonEnum,
  type CreditStopRow,
  type CreditStopListResponse,
  type OverrideRequest,
} from '@tera/contracts';
EOF

W services/api/src/modules/credit/repository.ts <<'EOF'
import { db } from '@tera/db';

// The ONLY file that touches credit_* tables directly.
// Cross-module reads go through events or explicit service contracts.

export type AccountRow = Awaited<ReturnType<typeof findAccounts>>[number];

export function findAccounts() {
  return db().creditAccount.findMany({
    include: {
      distributor: { select: { id: true, name: true, region: true } },
      overrides: { where: { expiresAt: { gt: new Date() } } },
    },
    orderBy: { createdAt: 'asc' },
  });
}

export function findActiveOverride(distributorId: string) {
  return db().creditOverride.findFirst({
    where: { distributorId, expiresAt: { gt: new Date() } },
    orderBy: { expiresAt: 'desc' },
  });
}

export function recordDecision(input: {
  accountId: string;
  outcome: string;
  reason: string;
  exposureEtb: number;
  limitEtb: number;
  daysOverdue: number;
}) {
  return db().creditDecision.create({ data: input });
}

export function createOverride(input: {
  decisionId?: string;
  distributorId: string;
  reason: string;
  actorId: string;
  expiresAt: Date;
}) {
  return db().creditOverride.create({ data: input });
}

export function readFlag(key: string) {
  return db().setting.findUnique({ where: { key } });
}
EOF

W services/api/src/modules/credit/service.ts <<'EOF'
import { getFlag } from '../config/service.js';
import { writeAudit } from '../../core/audit.js';
import * as repo from './repository.js';
import type { CreditStopRow, CreditStopListResponse } from './schemas.js';

export type Decision = 'BLOCKED' | 'WARNED' | 'CLEARED';
export type Reason = 'OVER_LIMIT' | 'PAST_GRACE' | 'BOTH' | 'NONE';

interface TriggerResult {
  triggered: boolean;
  reason: Reason;
  overLimit: boolean;
  pastGrace: boolean;
}

/**
 * Pure rule — no I/O. This is the credit policy itself.
 * An account triggers if it is over its limit, past its grace
 * period, or both. The gate (soft vs hard) is decided by the caller.
 */
export function evaluateRule(input: {
  exposureEtb: number;
  limitEtb: number;
  daysOverdue: number;
  graceDays: number;
}): TriggerResult {
  const overLimit = input.exposureEtb > input.limitEtb;
  const pastGrace = input.daysOverdue > input.graceDays;

  if (overLimit && pastGrace) return { triggered: true, reason: 'BOTH', overLimit, pastGrace };
  if (overLimit) return { triggered: true, reason: 'OVER_LIMIT', overLimit, pastGrace };
  if (pastGrace) return { triggered: true, reason: 'PAST_GRACE', overLimit, pastGrace };
  return { triggered: false, reason: 'NONE', overLimit, pastGrace };
}

function decide(triggered: boolean, hasOverride: boolean, hardGate: boolean): Decision {
  if (!triggered) return 'CLEARED';
  if (hasOverride) return 'WARNED'; // override allows but keeps the flag
  return hardGate ? 'BLOCKED' : 'WARNED'; // soft mode = WARNED
}

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

    const trigger = evaluateRule({
      exposureEtb, limitEtb, daysOverdue, graceDays: a.graceDays,
    });

    const override = a.overrides[0];
    const decision = decide(trigger.triggered, Boolean(override), hardGate);
    if (decision === 'CLEARED') continue; // stop list only shows action-required

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

    // Persist the decision for the record (fire-and-forget to keep list fast)
    void repo.recordDecision({
      accountId: a.id, outcome: decision, reason: trigger.reason,
      exposureEtb, limitEtb, daysOverdue,
    });
  }

  // BLOCKED first, then WARNED, then by amount owed desc
  rows.sort((x, y) => {
    const order: Record<Decision, number> = { BLOCKED: 0, WARNED: 1, CLEARED: 2 };
    const d = order[x.decision] - order[y.decision];
    return d !== 0 ? d : y.amount_owed_etb - x.amount_owed_etb;
  });

  return { as_of: new Date().toISOString(), hard_gate: hardGate, rows };
}

export async function createOverride(input: {
  distributorId: string;
  reason: string;
  actorId: string;
  expiresAt: Date;
}): Promise<{ expiresAt: Date }> {
  if (input.expiresAt.getTime() <= Date.now()) {
    const err = new Error('expires_at must be in the future');
    (err as any).statusCode = 400;
    throw err;
  }
  const override = await repo.createOverride(input);
  await writeAudit({
    actorId: input.actorId,
    entity: 'credit_override',
    entityId: override.id,
    action: 'create',
    reason: input.reason,
    meta: { distributorId: input.distributorId, expiresAt: input.expiresAt.toISOString() },
  });
  return { expiresAt: override.expiresAt };
}
EOF

W services/api/src/modules/credit/events.ts <<'EOF'
import { bus } from '../../core/events.js';

export function emitCreditEvaluated(payload: {
  distributorId: string;
  outcome: 'BLOCKED' | 'WARNED' | 'CLEARED';
  reason: 'OVER_LIMIT' | 'PAST_GRACE' | 'BOTH' | 'NONE';
}): void {
  bus.emit('credit.evaluated', payload);
}

export function emitCreditOverridden(payload: {
  distributorId: string;
  expiresAt: string;
  actorId: string;
}): void {
  bus.emit('credit.overridden', payload);
}
EOF

W services/api/src/modules/credit/routes.ts <<'EOF'
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import {
  CreditStopListResponseSchema,
  OverrideRequestSchema,
  OverrideResponseSchema,
} from './schemas.js';
import * as service from './service.js';
import { emitCreditOverridden } from './events.js';

export const creditRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get('/stop-list', {
    schema: { response: { 200: CreditStopListResponseSchema } },
  }, async () => service.getStopList());

  app.post('/overrides', {
    schema: { body: OverrideRequestSchema, response: { 200: OverrideResponseSchema } },
  }, async (req) => {
    const actorId = (req as any).user?.sub ?? 'system';
    const result = await service.createOverride({
      distributorId: req.body.distributor_id,
      reason: req.body.reason,
      actorId,
      expiresAt: new Date(req.body.expires_at),
    });
    emitCreditOverridden({
      distributorId: req.body.distributor_id,
      expiresAt: result.expiresAt.toISOString(),
      actorId,
    });
    return { ok: true as const, expires_at: result.expiresAt.toISOString() };
  });
};
EOF

W services/api/src/modules/credit/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { creditRoutes } from './routes.js';

export const creditPlugin: FastifyPluginAsync = async (app) => {
  await app.register(creditRoutes);
};

export default creditPlugin;
EOF

W services/api/src/modules/credit/__tests__/service.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { evaluateRule } from '../service.js';

describe('credit rule', () => {
  it('clears an account under limit and inside grace', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 3, graceDays: 14 });
    expect(r.triggered).toBe(false);
    expect(r.reason).toBe('NONE');
  });

  it('triggers OVER_LIMIT when exposure exceeds limit', () => {
    const r = evaluateRule({ exposureEtb: 120, limitEtb: 100, daysOverdue: 0, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('OVER_LIMIT');
  });

  it('triggers PAST_GRACE when overdue beyond grace', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 20, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('PAST_GRACE');
  });

  it('triggers BOTH when over limit and past grace', () => {
    const r = evaluateRule({ exposureEtb: 120, limitEtb: 100, daysOverdue: 30, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('BOTH');
  });

  it('is inclusive at the grace boundary (exactly graceDays overdue does not trigger)', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 14, graceDays: 14 });
    expect(r.triggered).toBe(false);
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# 6. WEB — dispatcher-web package.json (adds testing deps)
# ═══════════════════════════════════════════════════════════════════

W apps/dispatcher-web/package.json <<'EOF'
{
  "name": "dispatcher-web",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "test": "vitest run",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.24.0",
    "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*",
    "@tera/i18n": "workspace:*",
    "@tera/contracts": "workspace:*"
  },
  "devDependencies": {
    "vite": "^5.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.4.0",
    "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.4.0",
    "jsdom": "^24.1.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0"
  }
}
EOF

W apps/dispatcher-web/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
    css: false,
  },
});
EOF

W apps/dispatcher-web/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF

# ═══════════════════════════════════════════════════════════════════
# 7. WEB — credit-stop-list module
# ═══════════════════════════════════════════════════════════════════

W apps/dispatcher-web/src/modules/credit-stop-list/types.ts <<'EOF'
export type {
  CreditDecision,
  CreditReason,
  CreditStopRow,
  CreditStopListResponse,
  OverrideRequest,
} from '@tera/contracts';

export type CreditFilter = 'ALL' | 'OVERDUE_30' | 'OVER_LIMIT';
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/api.ts <<'EOF'
import { api } from '../../api/client';
import type { CreditStopListResponse, OverrideRequest } from './types';

export const creditKeys = {
  all: ['credit'] as const,
  stopList: () => [...creditKeys.all, 'stop-list', 'today'] as const,
};

export function fetchCreditStopList(signal?: AbortSignal) {
  return api<CreditStopListResponse>({ path: '/credit/v1/stop-list', signal });
}

export function overrideCredit(req: OverrideRequest) {
  return api<{ ok: true; expires_at: string }>({
    method: 'POST',
    path: '/credit/v1/overrides',
    body: req,
  });
}
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { creditKeys, fetchCreditStopList, overrideCredit } from './api';
import type { OverrideRequest } from './types';

export function useCreditStopList() {
  return useQuery({
    queryKey: creditKeys.stopList(),
    queryFn: ({ signal }) => fetchCreditStopList(signal),
    refetchInterval: 60_000,
  });
}

export function useOverrideCredit() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: OverrideRequest) => overrideCredit(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: creditKeys.all }),
  });
}
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/components/StatusBadge.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { CreditDecision, CreditReason } from '../types';

const TONE = { BLOCKED: 'danger', WARNED: 'warn', CLEARED: 'success' } as const;

const DECISION_KEY: Record<CreditDecision, string> = {
  BLOCKED: 'credit.status.blocked',
  WARNED: 'credit.status.warned',
  CLEARED: 'credit.status.cleared',
};

const REASON_KEY: Record<CreditReason, string> = {
  OVER_LIMIT: 'credit.reason.over_limit',
  PAST_GRACE: 'credit.reason.past_grace',
  BOTH: 'credit.reason.both',
  NONE: 'credit.status.cleared',
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
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/components/FilterTabs.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import type { CreditFilter } from '../types';

const FILTERS: { id: CreditFilter; key: string }[] = [
  { id: 'ALL', key: 'credit.filter.all' },
  { id: 'OVERDUE_30', key: 'credit.filter.overdue_30' },
  { id: 'OVER_LIMIT', key: 'credit.filter.over_limit' },
];

export function FilterTabs({
  value, onChange,
}: { value: CreditFilter; onChange: (f: CreditFilter) => void }) {
  const { t } = useI18n();
  return (
    <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
      {FILTERS.map((f) => (
        <button
          key={f.id}
          onClick={() => onChange(f.id)}
          className={`px-3 py-1.5 text-sm rounded ${
            value === f.id ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'
          }`}
        >
          {t(f.key)}
        </button>
      ))}
    </div>
  );
}
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/components/OverrideDialog.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreditStopRow, OverrideRequest } from '../types';

interface Props {
  row: CreditStopRow;
  onSubmit: (req: OverrideRequest) => void;
  onCancel: () => void;
  isPending: boolean;
  errorMessage?: string;
}

// Default: 24h from now. Local time (Africa/Addis_Ababa is UTC+3, no DST).
function defaultExpiry(): string {
  return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
}

export function OverrideDialog({ row, onSubmit, onCancel, isPending, errorMessage }: Props) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  const [expiresAt, setExpiresAt] = useState(defaultExpiry());
  const canSubmit = reason.trim().length >= 5 && !isPending;

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal="true">
      <div className="bg-surface rounded-lg border border-border w-full max-w-lg p-6">
        <h2 className="text-lg font-semibold">{t('credit.override')}</h2>
        <p className="text-sm text-muted mt-1">
          {row.distributor_name} · {row.region}
        </p>

        <label className="block mt-4 text-sm">
          <span className="text-muted">{t('credit.override_reason')}</span>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={3}
            className="mt-1 w-full rounded-md border border-border bg-bg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary"
          />
        </label>

        <label className="block mt-4 text-sm">
          <span className="text-muted">{t('credit.override_expires')}</span>
          <input
            type="datetime-local"
            value={expiresAt.slice(0, 16)}
            onChange={(e) => setExpiresAt(new Date(e.target.value).toISOString())}
            className="mt-1 w-full rounded-md border border-border bg-bg px-3 py-2"
          />
        </label>

        {errorMessage && <p className="mt-3 text-sm text-danger">{errorMessage}</p>}

        <div className="mt-6 flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isPending}>
            {t('common.cancel')}
          </Button>
          <Button
            variant="danger"
            disabled={!canSubmit}
            loading={isPending}
            onClick={() =>
              onSubmit({
                distributor_id: row.distributor_id,
                reason: reason.trim(),
                expires_at: expiresAt,
              })
            }
          >
            {t('credit.override_confirm')}
          </Button>
        </div>
      </div>
    </div>
  );
}
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/CreditStopListPage.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, DataTable, EmptyState, Money, Spinner, type Column } from '@tera/ui';
import { FilterTabs } from './components/FilterTabs';
import { OverrideDialog } from './components/OverrideDialog';
import { ReasonText, StatusBadge } from './components/StatusBadge';
import { useCreditStopList, useOverrideCredit } from './hooks';
import type { CreditFilter, CreditStopRow, OverrideRequest } from './types';

export function CreditStopListPage() {
  const { t } = useI18n();
  const [filter, setFilter] = useState<CreditFilter>('ALL');
  const [overrideFor, setOverrideFor] = useState<CreditStopRow | null>(null);

  const { data, isLoading, isError, refetch } = useCreditStopList();
  const override = useOverrideCredit();

  const rows = useMemo(() => {
    const all = data?.rows ?? [];
    switch (filter) {
      case 'OVERDUE_30': return all.filter((r) => r.days_overdue >= 30);
      case 'OVER_LIMIT': return all.filter((r) => r.exposure_etb > r.credit_limit_etb);
      default: return all;
    }
  }, [data, filter]);

  const columns: Column<CreditStopRow>[] = [
    {
      key: 'distributor',
      header: t('credit.table.distributor'),
      render: (r) => (
        <div>
          <div className="font-medium">{r.distributor_name}</div>
          <ReasonText reason={r.reason} />
        </div>
      ),
    },
    { key: 'region', header: t('credit.table.region'), render: (r) => r.region },
    { key: 'status', header: t('credit.table.status'), render: (r) => <StatusBadge decision={r.decision} /> },
    { key: 'owed', header: t('credit.amount_owed'), align: 'right', render: (r) => <Money value={r.amount_owed_etb} bold /> },
    { key: 'limit', header: t('credit.limit'), align: 'right', render: (r) => <Money value={r.credit_limit_etb} /> },
    { key: 'exposure', header: t('credit.exposure'), align: 'right', render: (r) => <Money value={r.exposure_etb} /> },
    { key: 'overdue', header: t('credit.days_overdue'), align: 'right', render: (r) => r.days_overdue },
    {
      key: 'actions',
      header: t('credit.table.actions'),
      align: 'right',
      render: (r) => (
        <Button size="sm" variant="secondary" onClick={() => setOverrideFor(r)}>
          {t('credit.override')}
        </Button>
      ),
    },
  ];

  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">{t('credit.title')}</h1>
        <p className="text-sm text-muted mt-1">{t('credit.subtitle')}</p>
        {data && !data.hard_gate && (
          <p className="text-xs text-warn bg-warnBg border border-warn/30 rounded px-2 py-1 mt-2 inline-block">
            {t('common.optional')}: soft mode — blocks are warnings, not hard stops
          </p>
        )}
      </header>

      <div className="flex items-center justify-between mb-4">
        <FilterTabs value={filter} onChange={setFilter} />
        <Button variant="ghost" size="sm" onClick={() => refetch()}>
          {t('common.retry')}
        </Button>
      </div>

      {isLoading && <Spinner label={t('common.loading')} />}

      {isError && (
        <div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
          {t('common.error')}{' '}
          <button onClick={() => refetch()} className="underline">{t('common.retry')}</button>
        </div>
      )}

      {!isLoading && !isError && (
        rows.length === 0 ? (
          <EmptyState title={t('credit.no_blocked')} />
        ) : (
          <DataTable columns={columns} rows={rows} rowKey={(r) => r.distributor_id} emptyMessage={t('common.empty')} />
        )
      )}

      {overrideFor && (
        <OverrideDialog
          row={overrideFor}
          isPending={override.isPending}
          errorMessage={override.isError ? t('common.error') : undefined}
          onCancel={() => { setOverrideFor(null); override.reset(); }}
          onSubmit={(req: OverrideRequest) =>
            override.mutate(req, { onSuccess: () => setOverrideFor(null) })
          }
        />
      )}
    </div>
  );
}
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/index.ts <<'EOF'
export { CreditStopListPage } from './CreditStopListPage';
export type { CreditStopRow, CreditDecision, CreditReason } from './types';
EOF

W apps/dispatcher-web/src/modules/credit-stop-list/__tests__/CreditStopListPage.test.tsx <<'EOF'
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { CreditStopListPage } from '../CreditStopListPage';

vi.mock('../api', () => ({
  creditKeys: {
    all: ['credit'],
    stopList: () => ['credit', 'stop-list', 'today'],
  },
  fetchCreditStopList: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(),
    hard_gate: false,
    rows: [
      {
        distributor_id: 'd1',
        distributor_name: 'Abebe Distribution',
        region: 'Addis',
        decision: 'WARNED',
        reason: 'OVER_LIMIT',
        amount_owed_etb: 120_000,
        credit_limit_etb: 100_000,
        exposure_etb: 120_000,
        days_overdue: 42,
        grace_days: 14,
        blocked_at: new Date().toISOString(),
        active_override_until: null,
      },
    ],
  }),
  overrideCredit: vi.fn(),
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <I18nProvider initialLocale="en">
      <QueryClientProvider client={qc}>{ui}</QueryClientProvider>
    </I18nProvider>
  );
}

describe('CreditStopListPage', () => {
  it('renders title, warning banner in soft mode, and the distributor row', async () => {
    wrap(<CreditStopListPage />);
    expect(screen.getByText('Credit Stop List')).toBeInTheDocument();
    expect(await screen.findByText('Abebe Distribution')).toBeInTheDocument();
    expect(screen.getByText(/soft mode/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Override/i })).toBeInTheDocument();
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# 8. WEB — app shell wiring
# ═══════════════════════════════════════════════════════════════════

W apps/dispatcher-web/src/app/AppLayout.tsx <<'EOF'
import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';

const NAV: { to: string; key: string }[] = [
  { to: '/', key: 'nav.dashboard' },
  { to: '/dispatch', key: 'nav.dispatch' },
  { to: '/credit', key: 'nav.credit' },
];

export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="min-h-full flex">
      <aside className="w-56 shrink-0 border-r border-border bg-surface flex flex-col">
        <div className="px-5 py-4 border-b border-border">
          <p className="text-sm text-muted">{t('app.name')}</p>
          <p className="text-base font-semibold">{t('nav.dispatch')}</p>
        </div>
        <nav className="flex-1 p-2">
          {NAV.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.to === '/'}
              className={({ isActive }) =>
                `block px-3 py-2 rounded-md text-sm ${
                  isActive ? 'bg-bg text-text font-medium' : 'text-muted hover:bg-bg'
                }`
              }
            >
              {t(n.key)}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="flex-1 min-w-0 p-6">
        <Outlet />
      </main>
    </div>
  );
}
EOF

W apps/dispatcher-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { CreditStopListPage } from '../modules/credit-stop-list';

const router = createBrowserRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <Navigate to="/credit" replace /> },
      { path: 'credit', element: <CreditStopListPage /> },
      // next modules: /dispatch (dispatch board), /routes (morning map)
    ],
  },
]);

export function AppRouter() {
  return <RouterProvider router={router} />;
}
EOF

# ═══════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "✓ codegen complete — credit vertical slice is wired"
echo ""
echo "Next:"
echo "  pnpm install"
echo "  pnpm db:generate && pnpm db:migrate"
echo "  pnpm --filter @tera/api dev      # http://localhost:8000/docs"
echo "  pnpm --filter dispatcher-web dev # http://localhost:5173/credit"
echo ""
echo "Tests:"
echo "  pnpm --filter @tera/api test"
echo "  pnpm --filter dispatcher-web test"