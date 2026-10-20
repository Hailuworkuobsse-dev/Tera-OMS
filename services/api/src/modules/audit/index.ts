import type { FastifyPluginAsync } from 'fastify';
import { auditRoutes } from './routes.js';
export const auditPlugin: FastifyPluginAsync = async (app) => { await app.register(auditRoutes); };
export default auditPlugin;
