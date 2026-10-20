import type { FastifyPluginAsync } from 'fastify';
import { notifyRoutes } from './routes.js';
export const notifyPlugin: FastifyPluginAsync = async (app) => { await app.register(notifyRoutes); };
export default notifyPlugin;
