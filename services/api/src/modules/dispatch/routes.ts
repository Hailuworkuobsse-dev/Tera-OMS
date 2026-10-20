import type { FastifyPluginAsync } from 'fastify';
import { BoardResponseSchema, AllocateResponseSchema, ConfirmSlotResponseSchema, DispatchRouteResponseSchema } from './schemas.js';
import * as service from './service.js';

export const dispatchRoutes: FastifyPluginAsync = async (app) => {
  app.get('/board', { schema: { response: { 200: BoardResponseSchema as any } } }, async () => service.getBoard());
  app.post('/slots/allocate', { schema: { response: { 200: AllocateResponseSchema as any } } }, async () => service.allocateAll());
  app.post('/slots/:id/confirm', { schema: { response: { 200: ConfirmSlotResponseSchema as any } } },
    async (req: any) => service.confirmSlot(req.params.id, req.user?.sub ?? 'warehouse'));
  app.post('/routes/:id/dispatch', { schema: { response: { 200: DispatchRouteResponseSchema as any } } },
    async (req: any) => service.dispatchRoute(req.params.id, req.user?.sub ?? 'dispatcher'));
};
