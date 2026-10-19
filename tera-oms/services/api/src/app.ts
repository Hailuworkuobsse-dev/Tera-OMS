import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { serializerCompiler, validatorCompiler, type ZodTypeProvider } from 'fastify-type-provider-zod';
import { errorHandler } from './plugins/errorHandler.js';
import { authPlugin } from './plugins/auth.js';
import { config } from './config.js';

import identity from './modules/identity/index.js';
import masterdata from './modules/masterdata/index.js';
import orders from './modules/orders/index.js';
import credit from './modules/credit/index.js';
import inventory from './modules/inventory/index.js';
import geo from './modules/geo/index.js';
import routing from './modules/routing/index.js';
import dispatch from './modules/dispatch/index.js';
import delivery from './modules/delivery/index.js';
import payments from './modules/payments/index.js';
import fleet from './modules/fleet/index.js';
import notify from './modules/notify/index.js';
import analytics from './modules/analytics/index.js';
import sync from './modules/sync/index.js';
import audit from './modules/audit/index.js';
import configMod from './modules/config/index.js';
import adapters from './modules/adapters/index.js';
import reporting from './modules/reporting/index.js';

export async function buildApp() {
  const app = Fastify({ logger: { level: config.LOG_LEVEL } }).withTypeProvider<ZodTypeProvider>();
  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  await app.register(cors, { origin: true });
  await app.register(sensible);
  await app.register(swagger, {
    openapi: {
      info: { title: 'Tera OMS API', version: '0.1.0' },
      components: {
        securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
      },
    },
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  app.setErrorHandler(errorHandler);
  await app.register(authPlugin);

  await app.register(identity, { prefix: '/identity/v1' });
  await app.register(masterdata, { prefix: '/masterdata/v1' });
  await app.register(orders, { prefix: '/orders/v1' });
  await app.register(credit, { prefix: '/credit/v1' });
  await app.register(inventory, { prefix: '/inventory/v1' });
  await app.register(geo, { prefix: '/geo/v1' });
  await app.register(routing, { prefix: '/routing/v1' });
  await app.register(dispatch, { prefix: '/dispatch/v1' });
  await app.register(delivery, { prefix: '/delivery/v1' });
  await app.register(payments, { prefix: '/payments/v1' });
  await app.register(fleet, { prefix: '/fleet/v1' });
  await app.register(notify, { prefix: '/notify/v1' });
  await app.register(analytics, { prefix: '/analytics/v1' });
  await app.register(sync, { prefix: '/sync/v1' });
  await app.register(audit, { prefix: '/audit/v1' });
  await app.register(configMod, { prefix: '/config/v1' });
  await app.register(adapters, { prefix: '/adapters/v1' });
  await app.register(reporting, { prefix: '/reporting/v1' });

  app.get('/health', async () => ({ ok: true }));
  return app;
}
