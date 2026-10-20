import { Queue } from 'bullmq';
import IORedis from 'ioredis';
const NAME = 'worker-jobs';
let redis: IORedis | null = null; let q: Queue | null = null;
function getRedis() { if (!redis) { redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null, enableReadyCheck: false }); } return redis; }
export function getQueue(): Queue { if (!q) q = new Queue(NAME, { connection: getRedis() }); return q; }
export async function enqueueJob(jobKey: string, triggeredBy: string): Promise<void> {
  await getQueue().add(jobKey, { triggeredBy }, { removeOnComplete: { age: 3600, count: 100 }, removeOnFail: { age: 86_400, count: 100 } });
}
