import type { FastifyPluginAsync } from 'fastify';
import { monitoringRoutes } from './routes.js';
export const monitoringPlugin: FastifyPluginAsync = async (app) => { await app.register(monitoringRoutes); };
export default monitoringPlugin;
