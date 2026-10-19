import type { FastifyPluginAsync } from 'fastify';

export const syncPlugin: FastifyPluginAsync = async (app) => {
  // routes registered here as the module is built
};

export default syncPlugin;
