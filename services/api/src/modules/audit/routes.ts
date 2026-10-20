import type { FastifyPluginAsync } from 'fastify';
import { AuditListResponseSchema } from '@tera/contracts';
import * as s from './service.js';
export const auditRoutes: FastifyPluginAsync = async (app) => {
  app.get('/log', { schema: { response: { 200: AuditListResponseSchema as any } } }, async (req: any) => s.listAudit({ entity: req.query?.entity, actor: req.query?.actor, limit: req.query?.limit ? parseInt(req.query.limit, 10) : 100 }));
};
