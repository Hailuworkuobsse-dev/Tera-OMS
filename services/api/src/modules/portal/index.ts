import type { FastifyPluginAsync } from 'fastify';
import { portalRoutes } from './routes.js';
export const portalPlugin: FastifyPluginAsync = async (app) => { await app.register(portalRoutes); };
export default portalPlugin;
