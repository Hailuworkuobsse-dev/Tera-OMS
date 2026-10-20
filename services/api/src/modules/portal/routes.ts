import type { FastifyPluginAsync } from 'fastify';
import { PortalProfileSchema, CatalogResponseSchema, PlaceOrderRequestSchema, PlaceOrderResponseSchema, PortalOrdersResponseSchema, PortalOrderDetailSchema, StatementResponseSchema, RaiseDisputeRequestSchema, DisputesListResponseSchema } from '@tera/contracts';
import * as s from './service.js';
import { getDistributorId } from './context.js';
export const portalRoutes: FastifyPluginAsync = async (app) => {
  app.get('/me', { schema: { response: { 200: PortalProfileSchema as any } } }, async (req: any) => s.getProfile(getDistributorId(req)));
  app.get('/catalog', { schema: { response: { 200: CatalogResponseSchema as any } } }, async () => s.getCatalog());
  app.post('/orders', { schema: { body: PlaceOrderRequestSchema as any, response: { 200: PlaceOrderResponseSchema as any } } }, async (req: any) => s.placeOrder(getDistributorId(req), req.body));
  app.get('/orders', { schema: { response: { 200: PortalOrdersResponseSchema as any } } }, async (req: any) => s.listOrders(getDistributorId(req)));
  app.get('/orders/:id', { schema: { response: { 200: PortalOrderDetailSchema as any } } }, async (req: any) => s.getOrderDetail(getDistributorId(req), req.params.id));
  app.get('/statements', { schema: { response: { 200: StatementResponseSchema as any } } }, async (req: any) => s.getStatement(getDistributorId(req)));
  app.post('/disputes', { schema: { body: RaiseDisputeRequestSchema as any, response: { 200: DisputesListResponseSchema as any } } }, async (req: any) => { await s.raiseDispute(getDistributorId(req), req.body); return s.listDisputes(getDistributorId(req)); });
  app.get('/disputes', { schema: { response: { 200: DisputesListResponseSchema as any } } }, async (req: any) => s.listDisputes(getDistributorId(req)));
};
