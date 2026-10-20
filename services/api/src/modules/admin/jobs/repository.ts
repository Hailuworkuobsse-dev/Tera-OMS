import { db } from '@tera/db';
export const findRecentRuns = (limit: number) => db().jobRun.findMany({ orderBy: { startedAt: 'desc' }, take: limit });
export const findLatestForJob = (jobKey: string) => db().jobRun.findFirst({ where: { jobKey }, orderBy: { startedAt: 'desc' } });
