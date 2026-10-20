import { Worker, type Job } from 'bullmq';
import IORedis from 'ioredis';
import { processSolveJob } from './solver-worker.js';

const QUEUE = 'route-solve'; const CONCURRENCY = Number(process.env.OPT_CONCURRENCY ?? 2);
const redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null, enableReadyCheck: false });
redis.on('connect', () => console.log('[opt] redis connected'));
redis.on('error', (e) => console.error('[opt] redis error', e.message));

const worker = new Worker<{ dbJobId: string }>(QUEUE, async (job: Job<{ dbJobId: string }>) => {
  console.log(`[opt] picked ${job.id}`);
  await processSolveJob(job.data.dbJobId);
  console.log(`[opt] finished ${job.id}`);
}, { connection: redis, concurrency: CONCURRENCY });

worker.on('completed', (j) => console.log(`[opt] ✓ ${j.id}`));
worker.on('failed', (j, e) => console.error(`[opt] ✗ ${j?.id}: ${e.message}`));

console.log(`[opt] ready · queue=${QUEUE} concurrency=${CONCURRENCY}`);
process.on('SIGTERM', async () => { await worker.close(); await redis.quit(); process.exit(0); });
process.on('SIGINT', async () => { await worker.close(); await redis.quit(); process.exit(0); });
