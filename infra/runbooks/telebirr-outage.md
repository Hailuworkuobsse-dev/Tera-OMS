# Runbook: Telebirr outage
1. Confirm outage via health checks.
2. e-POD marks payments PENDING (never blocks).
3. Worker reconcile backoff active.
4. On restore: run reconcile --since <outage_start>.
