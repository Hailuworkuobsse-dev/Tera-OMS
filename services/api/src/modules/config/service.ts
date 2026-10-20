import { db } from '@tera/db';

export async function getFlag(key: string, defaultValue: boolean): Promise<boolean> {
  const row = await db().setting.findUnique({ where: { key } });
  if (!row) return defaultValue;
  return row.value === 'true';
}
