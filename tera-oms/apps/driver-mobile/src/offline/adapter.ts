import * as SQLite from 'expo-sqlite';
import type { SqliteAdapter } from '@tera/offline-sync';

let cached: SqliteAdapter | null = null;

export async function createExpoAdapter(dbName = 'tera.db'): Promise<SqliteAdapter> {
  if (cached) return cached;
  const db = await SQLite.openDatabaseAsync(dbName);
  cached = {
    async run(sql, params = []) { await db.runAsync(sql, params as any[]); },
    async all<T>(sql: string, params: unknown[] = []) { return (await db.getAllAsync(sql, params as any[])) as T[]; },
    async get<T>(sql: string, params: unknown[] = []) { return ((await db.getFirstAsync(sql, params as any[])) as T) ?? null; },
    async transaction<T>(fn: () => Promise<T>): Promise<T> {
      let result!: T;
      await db.withTransactionAsync(async () => { result = await fn(); });
      return result;
    },
  };
  return cached;
}
