import * as repo from './repository.js';
const WINDOW = 30;
function computeL100(fills: { liters: number; odometerKm: number; capturedAt: Date }[]): { l100: number; at: Date }[] {
  const sorted = [...fills].sort((a, b) => a.capturedAt.getTime() - b.capturedAt.getTime());
  const out: { l100: number; at: Date }[] = [];
  for (let i = 1; i < sorted.length; i++) { const d = sorted[i]!.odometerKm - sorted[i - 1]!.odometerKm; if (d <= 0) continue; out.push({ l100: (sorted[i]!.liters / d) * 100, at: sorted[i]!.capturedAt }); }
  return out;
}
export async function runFuelVariance(triggeredBy: string): Promise<{ processed: number; skipped: number }> {
  const run = await repo.createJobRun('fuel_variance', triggeredBy);
  const since = new Date(Date.now() - WINDOW * 86_400_000);
  try {
    const vehicles = await repo.loadActiveVehicles();
    let processed = 0, skipped = 0;
    for (const v of vehicles) {
      const fills = await repo.loadFuelFillsForVehicle(v.id, since);
      if (fills.length < 4) { skipped++; continue; }
      const l = computeL100(fills.map((f) => ({ liters: Number(f.liters), odometerKm: Number(f.odometerKm), capturedAt: f.capturedAt })));
      if (l.length < 3) { skipped++; continue; }
      const mean = l.reduce((s, x) => s + x.l100, 0) / l.length;
      const variance = l.reduce((s, x) => s + (x.l100 - mean) ** 2, 0) / l.length;
      const stdev = Math.sqrt(variance);
      const outliers = l.filter((x) => x.l100 < mean - 2 * stdev || x.l100 > mean + 2 * stdev);
      if (outliers.length > 0) {
        await repo.createAudit({ actorId: 'worker/fuel_variance', entity: 'vehicle', entityId: v.id, action: 'variance_flagged',
          reason: `${v.plate}: ${outliers.length} outlier(s) (mean ${mean.toFixed(1)}, σ ${stdev.toFixed(2)})`,
          meta: { plate: v.plate, mean, stdev, outliers: outliers.length } });
      }
      processed++;
    }
    await repo.finishJobRun(run.id, { status: 'DONE', processedCount: processed, skippedCount: skipped });
    return { processed, skipped };
  } catch (err) {
    await repo.finishJobRun(run.id, { status: 'FAILED', processedCount: 0, skippedCount: 0, error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
