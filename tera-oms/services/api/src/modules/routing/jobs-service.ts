import type { AsyncSolveRequest, AsyncSolveSubmitResponse, AsyncSolveJobResponse, AsyncSolveStatus, SolveResponse } from '@tera/contracts';
import * as jobsRepo from './jobs-repository.js';
import { enqueueSolve, isQueueHealthy } from './queue.js';

const MAX_ORDERS = 500;

export async function submitAsyncSolve(input: AsyncSolveRequest): Promise<AsyncSolveSubmitResponse> {
  if (input.order_ids.length > MAX_ORDERS) {
    const e = new Error(`Too many orders (${input.order_ids.length}); max ${MAX_ORDERS}`) as any;
    e.statusCode = 400; throw e;
  }
  const job = await jobsRepo.createSolveJob({
    orderIds: input.order_ids, vehicleId: input.vehicle_id, status: 'QUEUED',
  });
  const healthy = await isQueueHealthy();
  if (!healthy) {
    await jobsRepo.markSolveJobFailed(job.id, 'Optimizer queue unreachable');
    const e = new Error('Solve queue unavailable — is the optimizer running?') as any;
    e.statusCode = 503; throw e;
  }
  try { await enqueueSolve(job.id); }
  catch (err) {
    await jobsRepo.markSolveJobFailed(job.id, err instanceof Error ? err.message : String(err));
    const e = new Error('Failed to enqueue solve job') as any; e.statusCode = 503; throw e;
  }
  return { job_id: job.id, status: job.status as AsyncSolveStatus };
}

export async function getAsyncSolveJob(jobId: string): Promise<AsyncSolveJobResponse> {
  const job = await jobsRepo.findSolveJobById(jobId);
  if (!job) { const e = new Error('solve job not found') as any; e.statusCode = 404; throw e; }
  return {
    job_id: job.id, status: job.status as AsyncSolveStatus,
    submitted_at: job.createdAt.toISOString(),
    started_at: job.startedAt ? job.startedAt.toISOString() : null,
    finished_at: job.finishedAt ? job.finishedAt.toISOString() : null,
    duration_ms: job.durationMs,
    result: job.resultJson as unknown as SolveResponse | null,
    error: job.error,
  };
}
