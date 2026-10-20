import type { FastifyPluginAsync } from 'fastify';
import { ordersRoutes } from './routes.js';
export const ordersPlugin: FastifyPluginAsync = async (app) => { await app.register(ordersRoutes); };
export default ordersPlugin;
