import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import { config } from '../config.js';

export const authPlugin = fp(async (app) => {
  await app.register(jwt, { secret: config.JWT_SECRET });
});
