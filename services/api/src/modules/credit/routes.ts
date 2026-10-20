import type { FastifyPluginAsync } from 'fastify';
import {
  CreditStopListResponseSchema, OverrideRequestSchema, OverrideResponseSchema,
  ExposureResponseSchema, OverridesListResponseSchema,
} from './schemas.js';
import * as service from './service.js';
import { emitCreditOverridden } from './events.js';

export const creditRoutes: FastifyPluginAsync = async (app) => {
  app.get('/stop-list', {
    schema: { response: { 200: CreditStopListResponseSchema as any } },
  }, async () => service.getStopList());

  app.post('/overrides', {
    schema: { body: OverrideRequestSchema as any, response: { 200: OverrideResponseSchema as any } },
  }, async (req: any) => {
    const actorId = req.user?.sub ?? 'system';
    const result = await service.createOverride({
      distributorId: req.body.distributor_id,
      reason: req.body.reason,
      actorId,
      expiresAt: new Date(req.body.expires_at),
    });
    emitCreditOverridden({
      distributorId: req.body.distributor_id,
      expiresAt: result.expiresAt.toISOString(),
      actorId,
    });
    return { ok: true as const, expires_at: result.expiresAt.toISOString() };
  });

  app.get('/exposure', {
    schema: { response: { 200: ExposureResponseSchema as any } },
  }, async () => service.getExposure());

  app.get('/overrides/list', {
    schema: { response: { 200: OverridesListResponseSchema as any } },
  }, async (req: any) => {
    const limit = req.query?.limit ? parseInt(req.query.limit, 10) : 100;
    return service.listOverrides(limit);
  });
};
