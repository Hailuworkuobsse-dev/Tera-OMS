import type { NotificationLogEntry, NotificationListResponse, SendNotificationRequest, SendNotificationResponse, TestSendRequest } from '@tera/contracts';
import * as repo from './repository.js';
import { TEMPLATES, findTemplate, renderTemplate } from './templates.js';
import { sendViaChannel, type Channel } from './adapters.js';
import { writeAudit } from '../../core/audit.js';
export async function sendNotification(input: SendNotificationRequest, actorId: string): Promise<SendNotificationResponse> {
  const t = findTemplate(input.template_key);
  if (!t) { const e = new Error(`unknown template "${input.template_key}"`) as any; e.statusCode = 400; throw e; }
  const body = renderTemplate(t.body, { ...input.vars, channel: input.channel });
  let r; try { r = await sendViaChannel(input.channel as Channel, input.recipient, body); } catch (err) { r = { ok: false, providerRef: null, error: err instanceof Error ? err.message : String(err), stub: true }; }
  const status = r.ok ? (r.stub ? 'STUB' : 'SENT') : 'FAILED';
  const log = await repo.createLog({ channel: input.channel, recipient: input.recipient, templateKey: input.template_key, renderedBody: body, status, providerRef: r.providerRef, error: r.error });
  await writeAudit({ actorId, entity: 'notification', entityId: log.id, action: 'sent', reason: `${input.channel} → ${input.recipient} (${input.template_key})`, meta: { status, providerRef: r.providerRef } });
  return { id: log.id, status: status as any, provider_ref: r.providerRef };
}
export async function sendTest(input: TestSendRequest, actorId: string) {
  return sendNotification({ channel: input.channel, recipient: input.recipient, template_key: 'test', vars: { time: new Date().toLocaleString(), channel: input.channel } }, actorId);
}
export async function listNotifications(input: { channel?: string; status?: string; limit: number }): Promise<NotificationListResponse> {
  const rows = await repo.findLogs(input);
  return { total: rows.length, entries: rows.map((r) => ({ id: r.id, channel: r.channel as any, recipient: r.recipient, template_key: r.templateKey, rendered_body: r.renderedBody, status: r.status as any, provider_ref: r.providerRef, error: r.error, sent_at: r.sentAt.toISOString() })) };
}
export function listTemplates() { return { templates: TEMPLATES.map((t) => ({ key: t.key, label_key: t.labelKey, channel_hint: t.channelHint })) }; }
