import type { FastifyPluginAsync } from 'fastify';
import { DashboardResponseSchema, FreezeBaselineRequestSchema, CostAssumptionsResponseSchema, UpdateCostAssumptionSchema, CostAssumptionSchema } from '@tera/contracts';
import * as s from './service.js';
export const analyticsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/dashboard', { schema: { response: { 200: DashboardResponseSchema as any } } }, async () => s.getDashboard());
  app.post('/baseline/freeze', { schema: { body: FreezeBaselineRequestSchema as any, response: { 200: DashboardResponseSchema as any } } },
    async (req: any) => s.freezeBaseline(req.body ?? {}, req.user?.sub ?? 'admin'));
  app.get('/cost-assumptions', { schema: { response: { 200: CostAssumptionsResponseSchema as any } } }, async () => s.listAssumptions());
  app.patch('/cost-assumptions/:key', { schema: { body: UpdateCostAssumptionSchema as any, response: { 200: CostAssumptionSchema as any } } },
    async (req: any) => s.updateAssumption(req.params.key, req.body.value));
};
