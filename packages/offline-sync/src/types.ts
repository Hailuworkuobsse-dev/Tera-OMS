import type { SyncChange, ClientOp, OpResult } from '@tera/contracts';
export type { SyncChange, ClientOp, OpResult };

export interface SqliteAdapter {
  run(sql: string, params?: unknown[]): Promise<void>;
  all<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T[]>;
  get<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T | null>;
  transaction<T>(fn: () => Promise<T>): Promise<T>;
}

export interface OutboxOp {
  client_op_id: string;
  op_type: ClientOp['op_type'];
  entity_id: string;
  payload: Record<string, unknown>;
  queued_at: string;
  synced_at: string | null;
  result: OpResult | null;
}

export interface SyncEngineConfig {
  api_base_url: string;
  device_id: string;
  driver_id: string;
  get_auth_token?: () => Promise<string | null>;
  pull_limit?: number;
}

export interface SyncEngineState {
  client_id: string | null;
  last_cursor: string;
  last_synced_at: string | null;
}
