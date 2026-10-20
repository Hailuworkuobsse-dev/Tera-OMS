export type Channel = 'sms' | 'telegram' | 'email';
export interface SendResult { ok: boolean; providerRef: string | null; error: string | null; stub: boolean; }
function fakeRef(p: string) { return `${p}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`; }
async function sendSms(r: string, b: string): Promise<SendResult> { console.log(`[SMS STUB] → ${r}\n  ${b}`); return { ok: true, providerRef: fakeRef('sms'), error: null, stub: true }; }
async function sendTg(r: string, b: string): Promise<SendResult> { console.log(`[TELEGRAM STUB] → ${r}\n  ${b}`); return { ok: true, providerRef: fakeRef('tg'), error: null, stub: true }; }
async function sendEmail(r: string, b: string): Promise<SendResult> { console.log(`[EMAIL STUB] → ${r}\n  ${b}`); return { ok: true, providerRef: fakeRef('email'), error: null, stub: true }; }
export async function sendViaChannel(c: Channel, r: string, b: string): Promise<SendResult> {
  switch (c) { case 'sms': return sendSms(r, b); case 'telegram': return sendTg(r, b); case 'email': return sendEmail(r, b); }
}
