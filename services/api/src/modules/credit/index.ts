import type { FastifyPluginAsync } from 'fastify';
import { creditRoutes } from './routes.js';
export const creditPlugin: FastifyPluginAsync = async (app) => { await app.register(creditRoutes); };
export default creditPlugin;
