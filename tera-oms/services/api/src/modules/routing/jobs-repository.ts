import { db } from '@tera/db';

export function createSolveJob(input: { orderIds: string[]; vehicleId: string; status: string }) {
  return db().solveJob.create({
    data: { orderIdsJson: input.orderIds as any, vehicleId: input.vehicleId, status: input.status },
  });
}

export function findSolveJobById(id: string) { return db().solveJob.findUnique({ where: { id } }); }

export function markSolveJobFailed(id: string, error: string) {
  return db().solveJob.update({ where: { id }, data: { status: 'FAILED', error, finishedAt: new Date() } });
}
