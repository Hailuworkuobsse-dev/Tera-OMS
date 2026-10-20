import type { FastifyPluginAsync } from 'fastify';
import {
  DistributorsResponseSchema, DistributorSchema, VehiclesResponseSchema, VehicleSchema, SkusResponseSchema, SkuSchema,
  CreateDistributorSchema, CreateVehicleSchema, CreateSkuSchema, ToggleActiveSchema,
  ImportRequestSchema, ValidateImportResponseSchema, CommitImportResponseSchema,
} from './schemas.js';
import * as service from './service.js';

export const masterdataRoutes: FastifyPluginAsync = async (app) => {
  app.get('/distributors', { schema: { response: { 200: DistributorsResponseSchema as any } } }, async () => service.listDistributors());
  app.post('/distributors', { schema: { body: CreateDistributorSchema as any, response: { 200: DistributorSchema as any } } }, async (req: any) => service.createDistributor(req.body));
  app.patch('/distributors/:id', { schema: { body: ToggleActiveSchema as any, response: { 200: DistributorSchema as any } } }, async (req: any) => service.toggleDistributorActive(req.params.id, req.body.active));

  app.get('/vehicles', { schema: { response: { 200: VehiclesResponseSchema as any } } }, async () => service.listVehicles());
  app.post('/vehicles', { schema: { body: CreateVehicleSchema as any, response: { 200: VehicleSchema as any } } }, async (req: any) => service.createVehicle(req.body));
  app.patch('/vehicles/:id', { schema: { body: ToggleActiveSchema as any, response: { 200: VehicleSchema as any } } }, async (req: any) => service.toggleVehicleActive(req.params.id, req.body.active));

  app.get('/skus', { schema: { response: { 200: SkusResponseSchema as any } } }, async () => service.listSkus());
  app.post('/skus', { schema: { body: CreateSkuSchema as any, response: { 200: SkuSchema as any } } }, async (req: any) => service.createSku(req.body));
  app.patch('/skus/:id', { schema: { body: ToggleActiveSchema as any, response: { 200: SkuSchema as any } } }, async (req: any) => service.toggleSkuActive(req.params.id, req.body.active));

  app.post('/import/validate', { schema: { body: ImportRequestSchema as any, response: { 200: ValidateImportResponseSchema as any } } }, async (req: any) => service.validateImport(req.body.type, req.body.rows));
  app.post('/import/commit', { schema: { body: ImportRequestSchema as any, response: { 200: CommitImportResponseSchema as any } } }, async (req: any) => service.commitImport(req.body.type, req.body.rows));
};
