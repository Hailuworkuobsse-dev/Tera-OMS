import type { FastifyPluginAsync } from 'fastify';
import { adminJobsRoutes } from './routes.js';
export const adminJobsPlugin: FastifyPluginAsync = async (app) => { await app.register(adminJobsRoutes); };
export default adminJobsPlugin;
