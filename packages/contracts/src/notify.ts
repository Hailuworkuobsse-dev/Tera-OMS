import { z } from 'zod';

export const NotificationChannelEnum = z.enum(['sms', 'telegram', 'email']);
export const NotificationStatusEnum = z.enum(['SENT', 'FAILED', 'STUB']);

export const NotificationLogEntrySchema = z.object({
  id: z.string(), channel: NotificationChannelEnum, recipient: z.string(),
  template_key: z.string(), rendered_body: z.string(),
  status: NotificationStatusEnum, provider_ref: z.string().nullable(),
  error: z.string().nullable(), sent_at: z.string().datetime(),
});
export const NotificationListResponseSchema = z.object({
  total: z.number().int(), entries: z.array(NotificationLogEntrySchema),
});
export const SendNotificationRequestSchema = z.object({
  channel: NotificationChannelEnum, recipient: z.string().min(3).max(200),
  template_key: z.string().min(1).max(60),
  vars: z.record(z.string()).default({}),
});
export const TestSendRequestSchema = z.object({
  channel: NotificationChannelEnum, recipient: z.string().min(3).max(200),
});
export const SendNotificationResponseSchema = z.object({
  id: z.string(), status: NotificationStatusEnum, provider_ref: z.string().nullable(),
});

export type NotificationChannel = z.infer<typeof NotificationChannelEnum>;
export type NotificationLogEntry = z.infer<typeof NotificationLogEntrySchema>;
export type SendNotificationRequest = z.infer<typeof SendNotificationRequestSchema>;
export type TestSendRequest = z.infer<typeof TestSendRequestSchema>;
