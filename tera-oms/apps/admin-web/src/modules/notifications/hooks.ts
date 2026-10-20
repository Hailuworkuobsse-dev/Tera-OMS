import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { notifyKeys, fetchNotifications, sendTest } from './api';
import type { NotificationChannel } from './types';
export const useNotifications = (f: { channel?: string }) => useQuery({ queryKey: notifyKeys.log(f.channel ?? ''), queryFn: () => fetchNotifications(f) });
export function useSendTest() { const qc = useQueryClient(); return useMutation({ mutationFn: (i: { channel: NotificationChannel; recipient: string }) => sendTest(i.channel, i.recipient), onSuccess: () => qc.invalidateQueries({ queryKey: notifyKeys.all }) }); }
