import type { FastifyPluginAsync } from 'fastify';
import { geoRoutes } from './routes.js';
export const geoPlugin: FastifyPluginAsync = async (app) => { await app.register(geoRoutes); };
export default geoPlugin;
