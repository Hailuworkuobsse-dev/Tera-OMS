import { db } from '@tera/db';
import { solve } from '@tera/solver';
const MAX = 500;
export async function processSolveJob(dbJobId: string): Promise<void> {
  const job = await db().solveJob.findUnique({ where: { id: dbJobId } });
  if (!job) throw new Error(`solve job ${dbJobId} not found`);
  if (job.status !== 'QUEUED') { console.log(`[opt] ${dbJobId} already ${job.status} — skip`); return; }
  const startedAt = new Date();
  await db().solveJob.update({ where: { id: dbJobId }, data: { status: 'RUNNING', startedAt } });
  try {
    const ids = job.orderIdsJson as string[];
    if (!Array.isArray(ids) || ids.length < 2) throw new Error('need ≥2 orders');
    if (ids.length > MAX) throw new Error(`too many (${ids.length})`);
    const [orders, vehicle, zones] = await Promise.all([
      db().order.findMany({ where: { id: { in: ids } } }),
      db().vehicle.findUnique({ where: { id: job.vehicleId } }),
      db().curfewZone.findMany({ where: { active: true } }),
    ]);
    if (!vehicle) throw new Error(`vehicle ${job.vehicleId} not found`);
    if (orders.length < 2) throw new Error('fewer than 2 valid orders');
    const result = solve(
      orders.map((o) => ({ id: o.id, distributor_name: o.distributorName, lat: Number(o.lat), lng: Number(o.lng), weight_kg: Number(o.weightKg), volume_m3: Number(o.volumeM3), priority: o.priority, time_window_start: o.timeWindowStart.toISOString(), time_window_end: o.timeWindowEnd.toISOString() })),
      { id: vehicle.id, lat: Number(vehicle.startLat), lng: Number(vehicle.startLng), capacity_kg: Number(vehicle.capacityKg), capacity_m3: Number(vehicle.capacityM3), shift_start_h: vehicle.shiftStartH, shift_end_h: vehicle.shiftEndH },
      { curfew_zones: zones.map((z) => ({ id: z.id, name: z.name, polygon: z.polygonJson as any, start_hour: z.startHour, end_hour: z.endHour })) },
    );
    const finishedAt = new Date();
    await db().solveJob.update({ where: { id: dbJobId }, data: { status: 'DONE', resultJson: result as any, finishedAt, durationMs: finishedAt.getTime() - startedAt.getTime() } });
  } catch (err) {
    const finishedAt = new Date();
    const msg = err instanceof Error ? err.message : String(err);
    await db().solveJob.update({ where: { id: dbJobId }, data: { status: 'FAILED', error: msg, finishedAt, durationMs: finishedAt.getTime() - startedAt.getTime() } });
    throw err;
  }
}
