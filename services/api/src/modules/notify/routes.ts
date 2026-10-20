import type { FastifyPluginAsync } from 'fastify';
import { NotificationListResponseSchema, SendNotificationRequestSchema, SendNotificationResponseSchema, TestSendRequestSchema } from '@tera/contracts';
import * as s from './service.js';
export const notifyRoutes: FastifyPluginAsync = async (app) => {
  app.get('/log', { schema: { response: { 200: NotificationListResponseSchema as any } } }, async (req: any) => s.listNotifications({ channel: req.query?.channel, status: req.query?.status, limit: req.query?.limit ? parseInt(req.query.limit, 10) : 100 }));
  app.get('/templates', async () => s.listTemplates());
  app.post('/send', { schema: { body: SendNotificationRequestSchema as any, response: { 200: SendNotificationResponseSchema as any } } }, async (req: any) => s.sendNotification(req.body, req.user?.sub ?? 'admin'));
  app.post('/test', { schema: { body: TestSendRequestSchema as any, response: { 200: SendNotificationResponseSchema as any } } }, async (req: any) => s.sendTest(req.body, req.user?.sub ?? 'admin'));
};
