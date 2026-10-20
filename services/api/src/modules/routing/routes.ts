import type { FastifyPluginAsync } from 'fastify';
import {
  TodayRoutesResponseSchema, VehiclesResponseSchema,
  SolveRequestSchema, SolveResponseSchema, AcceptRouteRequestSchema, AcceptRouteResponseSchema,
  AsyncSolveRequestSchema, AsyncSolveSubmitResponseSchema, AsyncSolveJobResponseSchema,
  PickListResponseSchema, MarkPickedResponseSchema,
} from './schemas.js';
import * as service from './service.js';
import * as jobsService from './jobs-service.js';

export const routingRoutes: FastifyPluginAsync = async (app) => {
  app.get('/routes/today', {
    schema: { response: { 200: TodayRoutesResponseSchema as any } },
  }, async () => service.getTodayRoutes());

  app.get('/vehicles', {
    schema: { response: { 200: VehiclesResponseSchema as any } },
  }, async () => service.getVehicles());

  app.post('/solve', {
    schema: { body: SolveRequestSchema as any, response: { 200: SolveResponseSchema as any } },
  }, async (req: any) => service.solveRoutes(req.body.order_ids, req.body.vehicle_id));

  app.post('/routes', {
    schema: { body: AcceptRouteRequestSchema as any, response: { 200: AcceptRouteResponseSchema as any } },
  }, async (req: any) => service.acceptRoute(req.body));

  app.post('/solve/async', {
    schema: { body: AsyncSolveRequestSchema as any, response: { 200: AsyncSolveSubmitResponseSchema as any } },
  }, async (req: any) => jobsService.submitAsyncSolve(req.body));

  app.get('/solve/jobs/:id', {
    schema: { response: { 200: AsyncSolveJobResponseSchema as any } },
  }, async (req: any) => jobsService.getAsyncSolveJob(req.params.id));

  app.get('/routes/:id/pick-list', {
    schema: { response: { 200: PickListResponseSchema as any } },
  }, async (req: any) => service.getPickList(req.params.id));

  app.post('/routes/:id/stops/:stopId/picked', {
    schema: { response: { 200: MarkPickedResponseSchema as any } },
  }, async (req: any) => service.markStopPicked(req.params.id, req.params.stopId));
};
