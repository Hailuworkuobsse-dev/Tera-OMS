# Runbook: Sync backlog

Symptom: pending_ops > 200 for > 10 min.

1. Check `@tera/api` sync module pod health.
2. Inspect `sync_client_change_log` growth.
3. If conflicts are the cause: open credit override log — likely a bad rule release.
4. If network: clients self-heal on reconnection.
5. Never purge `client_change_log`; drain by processing.
