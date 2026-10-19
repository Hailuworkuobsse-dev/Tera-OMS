# Runbook: Telebirr outage

1. Confirm outage via 3 failed health checks.
2. Confirm e-POD is marking payments as PENDING (not blocking).
3. Confirm worker `reconcile` job backoff is active.
4. Notify finance: settlements delayed; no driver action.
5. On restore: `pnpm --filter @tera/worker exec tsx src/jobs/reconcile.ts --since <outage_start>`
6. Verify `payment.reconciled` event count matches pending queue.
