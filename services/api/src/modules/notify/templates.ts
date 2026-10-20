export interface NotificationTemplate { key: string; labelKey: string; channelHint: 'sms'|'telegram'|'email'|'any'; body: string; }
export const TEMPLATES: NotificationTemplate[] = [
  { key: 'test', labelKey: 'notify.template.test', channelHint: 'any', body: 'Tera OMS test notification at {time}. If you can read this, the {channel} adapter works.' },
  { key: 'eta_alert', labelKey: 'notify.template.eta_alert', channelHint: 'sms', body: 'Hi {name}, your delivery {order_id} is on the way and should arrive around {eta}.' },
  { key: 'order_confirmed', labelKey: 'notify.template.order_confirmed', channelHint: 'sms', body: 'Order {order_id} confirmed: {n} items, {total} ETB.' },
  { key: 'delivery_completed', labelKey: 'notify.template.delivery_completed', channelHint: 'sms', body: 'Delivery {order_id} completed at {time}.' },
];
export const findTemplate = (k: string) => TEMPLATES.find((t) => t.key === k) ?? null;
export function renderTemplate(body: string, vars: Record<string, string>): string {
  return body.replace(/\{(\w+)\}/g, (_, k) => (k in vars ? vars[k]! : `{${k}}`));
}
