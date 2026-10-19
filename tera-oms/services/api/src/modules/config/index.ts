import type { FastifyPluginAsync } from 'fastify';

export const configPlugin: FastifyPluginAsync = async (app) => {
  // routes registered here as the module is built
};

export default configPlugin;
