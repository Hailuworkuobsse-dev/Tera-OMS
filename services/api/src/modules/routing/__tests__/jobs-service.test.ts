import { describe, it, expect, vi, beforeEach } from 'vitest';
vi.mock('../jobs-repository.js', () => ({
  createSolveJob: vi.fn(), findSolveJobById: vi.fn(), markSolveJobFailed: vi.fn(),
}));
vi.mock('../queue.js', () => ({ enqueueSolve: vi.fn(), isQueueHealthy: vi.fn() }));

import * as repo from '../jobs-repository.js';
import { enqueueSolve, isQueueHealthy } from '../queue.js';
import { submitAsyncSolve, getAsyncSolveJob } from '../jobs-service.js';

const mockedRepo = vi.mocked(repo);
const mockedHealthy = vi.mocked(isQueueHealthy);
const mockedEnqueue = vi.mocked(enqueueSolve);

beforeEach(() => vi.clearAllMocks());

describe('submitAsyncSolve', () => {
  it('rejects >500 orders', async () => {
    const ids = Array.from({ length: 501 }, (_, i) => `o-${i}`);
    await expect(submitAsyncSolve({ order_ids: ids, vehicle_id: 'v1' })).rejects.toMatchObject({ statusCode: 400 });
    expect(mockedRepo.createSolveJob).not.toHaveBeenCalled();
  });
  it('creates QUEUED job + enqueues when healthy', async () => {
    mockedRepo.createSolveJob.mockResolvedValue({ id: 'j1', status: 'QUEUED', orderIdsJson: ['a','b'], vehicleId: 'v1', resultJson: null, error: null, startedAt: null, finishedAt: null, durationMs: null, createdAt: new Date() } as any);
    mockedHealthy.mockResolvedValue(true);
    mockedEnqueue.mockResolvedValue(undefined);
    const r = await submitAsyncSolve({ order_ids: ['a','b'], vehicle_id: 'v1' });
    expect(r.job_id).toBe('j1');
    expect(mockedEnqueue).toHaveBeenCalledWith('j1');
  });
  it('marks FAILED + throws 503 when queue unreachable', async () => {
    mockedRepo.createSolveJob.mockResolvedValue({ id: 'j2', status: 'QUEUED', orderIdsJson: ['a','b'], vehicleId: 'v1', resultJson: null, error: null, startedAt: null, finishedAt: null, durationMs: null, createdAt: new Date() } as any);
    mockedHealthy.mockResolvedValue(false);
    mockedRepo.markSolveJobFailed.mockResolvedValue({} as any);
    await expect(submitAsyncSolve({ order_ids: ['a','b'], vehicle_id: 'v1' })).rejects.toMatchObject({ statusCode: 503 });
    expect(mockedRepo.markSolveJobFailed).toHaveBeenCalledWith('j2', expect.any(String));
  });
});

describe('getAsyncSolveJob', () => {
  it('returns the job', async () => {
    mockedRepo.findSolveJobById.mockResolvedValue({ id: 'j', status: 'DONE', orderIdsJson: [], vehicleId: 'v', resultJson: { savings_km_pct: 20 } as any, error: null, startedAt: new Date(), finishedAt: new Date(), durationMs: 120, createdAt: new Date() } as any);
    const r = await getAsyncSolveJob('j');
    expect(r.status).toBe('DONE');
    expect(r.duration_ms).toBe(120);
  });
  it('404 when missing', async () => {
    mockedRepo.findSolveJobById.mockResolvedValue(null);
    await expect(getAsyncSolveJob('missing')).rejects.toMatchObject({ statusCode: 404 });
  });
});
