import { Queue } from 'bullmq';
import IORedis from 'ioredis';

const QUEUE_NAME = 'route-solve';
let redis: IORedis | null = null;
let queue: Queue | null = null;

function getRedis(): IORedis {
  if (!redis) {
    redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
      maxRetriesPerRequest: null, enableReadyCheck: false,
    });
    redis.on('error', (e) => console.error('[solve-queue]', e.message));
  }
  return redis;
}

export function getSolveQueue(): Queue {
  if (!queue) queue = new Queue(QUEUE_NAME, { connection: getRedis() });
  return queue;
}

export async function enqueueSolve(dbJobId: string): Promise<void> {
  await getSolveQueue().add('solve', { dbJobId }, {
    jobId: dbJobId, attempts: 1,
    removeOnComplete: { age: 3600, count: 500 },
    removeOnFail: { age: 3600, count: 500 },
  });
}

export async function isQueueHealthy(): Promise<boolean> {
  try { const client = await getSolveQueue().client; await client.ping(); return true; }
  catch { return false; }
}
