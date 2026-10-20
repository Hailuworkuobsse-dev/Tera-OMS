import { db } from '@tera/db';
export const findBaselines = () => db().baseline.findMany();
export const upsertBaseline = (i: any) => db().baseline.upsert({ where: { key: i.key }, create: i, update: i });
export const getLatestSnapshot = (key: string) => db().metricSnapshot.findFirst({ where: { key }, orderBy: { date: 'desc' } });
export const getLastNDays = (key: string, n: number) => db().metricSnapshot.findMany({ where: { key }, orderBy: { date: 'desc' }, take: n });
export const getAssumptions = () => db().costAssumption.findMany();
export const upsertAssumption = (key: string, value: number, unit: string) => db().costAssumption.upsert({ where: { key }, create: { key, value, unit }, update: { value } });
export const getFlag = (key: string) => db().setting.findUnique({ where: { key } });
export const setFlag = (key: string, value: string) => db().setting.upsert({ where: { key }, create: { key, value }, update: { value } });
