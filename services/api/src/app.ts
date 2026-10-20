import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { errorHandler } from './plugins/errorHandler.js';
import { authPlugin } from './plugins/auth.js';
import { onRequestHook, onResponseHook } from './modules/monitoring/middleware.js';

import credit from './modules/credit/index.js';
import configMod from './modules/config/index.js';
import geo from './modules/geo/index.js';
import routing from './modules/routing/index.js';
import orders from './modules/orders/index.js';
import dispatch from './modules/dispatch/index.js';
import masterdata from './modules/masterdata/index.js';
import analytics from './modules/analytics/index.js';
import payments from './modules/payments/index.js';
import portal from './modules/portal/index.js';
import audit from './modules/audit/index.js';
import notify from './modules/notify/index.js';
import adminJobs from './modules/admin/jobs/index.js';
import monitoring from './modules/monitoring/index.js';

export async function buildApp() {
  const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
  await app.register(cors, { origin: true });
  app.addHook('onRequest', onRequestHook);
  app.addHook('onResponse', onResponseHook);
  await app.register(sensible);
  await app.register(swagger, { openapi: { info: { title: 'Tera OMS API', version: '0.1.0' } } });
  await app.register(swaggerUi, { routePrefix: '/docs' });
  app.setErrorHandler(errorHandler);
  await app.register(authPlugin);

  await app.register(configMod,  { prefix: '/config/v1' });
  await app.register(credit,     { prefix: '/credit/v1' });
  await app.register(geo,        { prefix: '/geo/v1' });
  await app.register(routing,    { prefix: '/routing/v1' });
  await app.register(orders,     { prefix: '/orders/v1' });
  await app.register(dispatch,   { prefix: '/dispatch/v1' });
  await app.register(masterdata, { prefix: '/masterdata/v1' });
  await app.register(analytics,  { prefix: '/analytics/v1' });
  await app.register(payments,   { prefix: '/payments/v1' });
  await app.register(portal,     { prefix: '/portal/v1' });
  await app.register(audit,      { prefix: '/audit/v1' });
  await app.register(notify,     { prefix: '/notify/v1' });
  await app.register(adminJobs,  { prefix: '/admin/jobs/v1' });
  await app.register(monitoring);

  app.get('/health', async () => ({ ok: true }));
  return app;
}
