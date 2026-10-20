import type { FastifyPluginAsync } from 'fastify';
import { routingRoutes } from './routes.js';
export const routingPlugin: FastifyPluginAsync = async (app) => { await app.register(routingRoutes); };
export default routingPlugin;
