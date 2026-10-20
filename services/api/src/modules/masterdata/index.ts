import type { FastifyPluginAsync } from 'fastify';
import { masterdataRoutes } from './routes.js';
export const masterdataPlugin: FastifyPluginAsync = async (app) => { await app.register(masterdataRoutes); };
export default masterdataPlugin;
