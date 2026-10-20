import { Queue, Worker as BullWorker, type Job } from 'bullmq';
import IORedis from 'ioredis';
import cron from 'node-cron';
import { runMetricSnapshot } from './jobs/metric-snapshot.js';
import { runFuelVariance } from './jobs/fuel-variance.js';
import { runCreditRebuild } from './jobs/credit-rebuild.js';

const QUEUE = 'worker-jobs';
const redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null, enableReadyCheck: false });
redis.on('connect', () => console.log('[worker] redis connected'));
redis.on('error', (e) => console.error('[worker] redis error', e.message));
const queue = new Queue(QUEUE, { connection: redis });

async function process(job: Job<{ triggeredBy?: string }>) {
  const t = job.data?.triggeredBy ?? 'schedule';
  switch (job.name) {
    case 'metric_snapshot': { const r = await runMetricSnapshot(t); console.log(`[worker] metric_snapshot ${r.processed}/${r.skipped}`); break; }
    case 'fuel_variance': { const r = await runFuelVariance(t); console.log(`[worker] fuel_variance ${r.processed}/${r.skipped}`); break; }
    case 'credit_rebuild': { const r = await runCreditRebuild(t); console.log(`[worker] credit_rebuild ${r.processed}/${r.skipped}`); break; }
    default: throw new Error(`unknown job: ${job.name}`);
  }
}
const worker = new BullWorker<{ triggeredBy?: string }>(QUEUE, async (job) => process(job), { connection: redis, concurrency: 2 });
worker.on('completed', (j) => console.log(`[worker] ✓ ${j.name}`));
worker.on('failed', (j, e) => console.error(`[worker] ✗ ${j?.name}: ${e.message}`));

cron.schedule('0 22 * * *', async () => { await queue.add('metric_snapshot', { triggeredBy: 'schedule' }); });
cron.schedule('15 22 * * *', async () => { await queue.add('credit_rebuild', { triggeredBy: 'schedule' }); });
cron.schedule('30 22 * * *', async () => { await queue.add('fuel_variance', { triggeredBy: 'schedule' }); });
console.log('[worker] ready');
process.on('SIGTERM', async () => { await worker.close(); await queue.close(); await redis.quit(); process.exit(0); });
process.on('SIGINT', async () => { await worker.close(); await queue.close(); await redis.quit(); process.exit(0); });
