import { db } from '@tera/db';
export async function loadSolveJobsByStatus() { const r = await db().solveJob.groupBy({ by: ['status'], _count: { _all: true } }); return r.map((x) => ({ status: x.status, count: x._count._all })); }
export async function loadRecentDurations() { const r = await db().solveJob.findMany({ where: { status: 'DONE', durationMs: { not: null } }, select: { durationMs: true }, orderBy: { createdAt: 'desc' }, take: 100 }); return r.map((x) => x.durationMs!).filter(Number.isFinite); }
export const countPending = () => db().order.count({ where: { status: 'PENDING' } });
export const countUnreconciled = () => db().payment.count({ where: { reconciledAt: null } });
export function countStaleClients(h: number) { return db().syncClient.count({ where: { lastSeenAt: { lt: new Date(Date.now() - h * 3600_000) } } }); }
export function countHighVarFuel(d: number) { return db().fuelLog.count({ where: { varianceFlag: 'HIGH', capturedAt: { gte: new Date(Date.now() - d * 86_400_000) } } }); }
export async function loadJobRuns24h() { const r = await db().jobRun.groupBy({ by: ['jobKey', 'status'], where: { startedAt: { gte: new Date(Date.now() - 24 * 3600_000) } }, _count: { _all: true } }); return r.map((x) => ({ jobKey: x.jobKey, status: x.status, count: x._count._all })); }
