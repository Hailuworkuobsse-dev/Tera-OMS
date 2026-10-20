import type { FastifyPluginAsync } from 'fastify';
import { paymentsRoutes } from './routes.js';
export const paymentsPlugin: FastifyPluginAsync = async (app) => { await app.register(paymentsRoutes); };
export default paymentsPlugin;
