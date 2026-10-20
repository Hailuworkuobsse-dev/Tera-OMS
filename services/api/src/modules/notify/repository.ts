import { db } from '@tera/db';
export const createLog = (i: any) => db().notificationLog.create({ data: i });
export function findLogs(input: { channel?: string; status?: string; limit: number }) {
  return db().notificationLog.findMany({ where: { ...(input.channel ? { channel: input.channel } : {}), ...(input.status ? { status: input.status } : {}) }, orderBy: { sentAt: 'desc' }, take: input.limit });
}
