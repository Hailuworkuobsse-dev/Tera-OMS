// BullMQ workers + repeatable jobs.
import { Queue, Worker } from 'bullmq';
import IORedis from 'ioredis';

const redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null });
const queue = new Queue('tera', { connection: redis });

new Worker('tera', async (job) => {
  console.log('job:', job.name, job.data);
}, { connection: redis });

console.log('worker ready');
