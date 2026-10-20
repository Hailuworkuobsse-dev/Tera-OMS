import { api } from '../../api/client';
import type { NotificationLogEntry, NotificationChannel } from './types';
export const notifyKeys = { all: ['notifications'] as const, log: (c: string) => [...notifyKeys.all, 'log', c] as const };
export function fetchNotifications(f: { channel?: string }) { const p = new URLSearchParams(); if (f.channel) p.set('channel', f.channel); p.set('limit', '100'); return api<{ total: number; entries: NotificationLogEntry[] }>({ path: `/notify/v1/log?${p}` }); }
export function sendTest(channel: NotificationChannel, recipient: string) { return api<{ id: string; status: string; provider_ref: string | null }>({ method: 'POST', path: '/notify/v1/test', body: { channel, recipient } }); }
