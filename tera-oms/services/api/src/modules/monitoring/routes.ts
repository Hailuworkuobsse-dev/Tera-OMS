import type { FastifyPluginAsync } from 'fastify';
import { MonitoringSnapshotSchema } from '@tera/contracts';
import * as s from './service.js';
import * as snap from './snapshot-service.js';
export const monitoringRoutes: FastifyPluginAsync = async (app) => {
  app.get('/metrics', async (_req, reply) => { const b = await s.getMetricsText(); reply.header('Content-Type', 'text/plain; version=0.0.4'); return b; });
  app.get('/admin/monitoring/v1/snapshot', { schema: { response: { 200: MonitoringSnapshotSchema as any } } }, async () => snap.getSnapshot());
};
