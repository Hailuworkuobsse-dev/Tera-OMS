import type { FastifyPluginAsync } from 'fastify';
import { UnreconciledPaymentsResponseSchema, ReconcileRequestSchema, ReconcileResponseSchema } from './schemas.js';
import * as s from './service.js';
export const paymentsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/unreconciled', { schema: { response: { 200: UnreconciledPaymentsResponseSchema as any } } },
    async (req: any) => s.listUnreconciled(req.query?.limit ? parseInt(req.query.limit, 10) : 100));
  app.post('/:id/reconcile', { schema: { body: ReconcileRequestSchema as any, response: { 200: ReconcileResponseSchema as any } } },
    async (req: any) => s.reconcile(req.params.id, req.user?.sub ?? 'finance', req.body?.notes ?? null));
};
