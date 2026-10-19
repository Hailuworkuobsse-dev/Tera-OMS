import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import { config } from '../config.js';

export const authPlugin = fp(async (app) => {
  await app.register(jwt, { secret: config.JWT_SECRET });
  app.decorate('authenticate', async (req: any, reply: any) => {
    try { await req.jwtVerify(); } catch { reply.code(401).send({ code: 'unauthorized', message: 'login required' }); }
  });
});
