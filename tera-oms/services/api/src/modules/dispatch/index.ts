import type { FastifyPluginAsync } from 'fastify';
import { dispatchRoutes } from './routes.js';
export const dispatchPlugin: FastifyPluginAsync = async (app) => { await app.register(dispatchRoutes); };
export default dispatchPlugin;
