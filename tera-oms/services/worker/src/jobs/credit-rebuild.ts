import * as repo from './repository.js';
export async function runCreditRebuild(triggeredBy: string): Promise<{ processed: number; skipped: number }> {
  const run = await repo.createJobRun('credit_rebuild', triggeredBy);
  try {
    const accounts = await repo.loadAllCreditAccounts();
    let processed = 0, skipped = 0;
    for (const a of accounts) {
      const [unrec, delivered, reconciledStops] = await Promise.all([
        repo.loadUnreconciledPaymentsForDistributor(a.distributorId),
        repo.loadDeliveredStopsForDistributor(a.distributorId),
        repo.loadReconciledStopsForDistributor(a.distributorId),
      ]);
      const recSet = new Set(reconciledStops.map((p) => p.routeStopId));
      const candidates: Date[] = [...unrec.map((p) => p.capturedAt)];
      for (const s of delivered) if (!recSet.has(s.id)) candidates.push(s.statusUpdatedAt);
      const oldest = candidates.length === 0 ? null : candidates.reduce((o, d) => (d < o ? d : o));
      const exposure = Math.round(unrec.reduce((s, p) => s + Number(p.amountEtb), 0) * 100) / 100;
      const prevOldest = a.oldestUnpaidAt?.getTime() ?? null;
      const prevExposure = Number(a.exposureEtb);
      await repo.updateCreditAccount(a.id, { oldestUnpaidAt: oldest, exposureEtb: exposure });
      processed++;
      if ((oldest?.getTime() ?? null) !== prevOldest || Math.abs(prevExposure - exposure) > 1) {
        await repo.createAudit({ actorId: 'worker/credit_rebuild', entity: 'credit_account', entityId: a.id, action: 'rebuilt',
          reason: `Exposure ${prevExposure} → ${exposure}; oldest ${a.oldestUnpaidAt?.toISOString() ?? 'none'} → ${oldest?.toISOString() ?? 'none'}`,
          meta: { previous_exposure: prevExposure, new_exposure: exposure } });
      }
    }
    await repo.finishJobRun(run.id, { status: 'DONE', processedCount: processed, skippedCount: skipped });
    return { processed, skipped };
  } catch (err) {
    await repo.finishJobRun(run.id, { status: 'FAILED', processedCount: 0, skippedCount: 0, error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
