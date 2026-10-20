import type { FastifyPluginAsync } from 'fastify';
import { PendingOrdersResponseSchema } from '@tera/contracts';
import * as service from './service.js';

export const ordersRoutes: FastifyPluginAsync = async (app) => {
  app.get('/pending', {
    schema: { response: { 200: PendingOrdersResponseSchema as any } },
  }, async () => service.getPendingOrders());
};
