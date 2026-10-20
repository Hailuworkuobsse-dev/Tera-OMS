import type { FastifyPluginAsync } from 'fastify';
import { JobRunsResponseSchema, JobScheduleResponseSchema, RunJobResponseSchema, JobKeyEnum } from '@tera/contracts';
import * as s from './service.js';
export const adminJobsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/runs', { schema: { response: { 200: JobRunsResponseSchema as any } } }, async (req: any) => s.listRuns(req.query?.limit ? parseInt(req.query.limit, 10) : 50));
  app.get('/schedule', { schema: { response: { 200: JobScheduleResponseSchema as any } } }, async () => s.listSchedule());
  app.post('/:key/run', { schema: { response: { 200: RunJobResponseSchema as any } } }, async (req: any) => {
    const key = JobKeyEnum.parse(req.params.key); await s.runNow(key, req.user?.sub ?? 'admin'); return { job_key: key, enqueued: true as const };
  });
};
