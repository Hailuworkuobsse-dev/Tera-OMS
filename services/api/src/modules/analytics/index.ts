import type { FastifyPluginAsync } from 'fastify';
import { analyticsRoutes } from './routes.js';
export const analyticsPlugin: FastifyPluginAsync = async (app) => { await app.register(analyticsRoutes); };
export default analyticsPlugin;
