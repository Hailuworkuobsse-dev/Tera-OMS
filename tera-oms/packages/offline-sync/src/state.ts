import type { SqliteAdapter } from './types.js';
export async function getState(adapter: SqliteAdapter, key: string): Promise<string | null> {
  const row = await adapter.get<{ value: string }>(`SELECT value FROM state WHERE key = ?`, [key]);
  return row?.value ?? null;
}
export async function setState(adapter: SqliteAdapter, key: string, value: string): Promise<void> {
  await adapter.run(
    `INSERT INTO state(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
    [key, value],
  );
}
