import type { PullResponse, PushResponse, OpResult } from '@tera/contracts';
import type { SqliteAdapter, SyncEngineConfig, SyncEngineState } from './types.js';
import { createSchema } from './schema.js';
import { getState, setState } from './state.js';
import { pendingOps, markOpSynced, countPending } from './outbox.js';
import { applyChange } from './apply.js';

const KEY_CLIENT_ID = 'client_id';
const KEY_CURSOR = 'last_cursor';
const KEY_LAST_SYNC = 'last_synced_at';

export class SyncEngine {
  private adapter: SqliteAdapter;
  private config: SyncEngineConfig;
  private initialized = false;

  constructor(adapter: SqliteAdapter, config: SyncEngineConfig) {
    this.adapter = adapter;
    this.config = config;
  }

  async init(): Promise<void> {
    if (this.initialized) return;
    await createSchema(this.adapter);
    this.initialized = true;
  }

  async getState(): Promise<SyncEngineState> {
    const [clientId, cursor, lastSync] = await Promise.all([
      getState(this.adapter, KEY_CLIENT_ID),
      getState(this.adapter, KEY_CURSOR),
      getState(this.adapter, KEY_LAST_SYNC),
    ]);
    return { client_id: clientId, last_cursor: cursor ?? '0', last_synced_at: lastSync };
  }

  async pendingCount(): Promise<number> { return countPending(this.adapter); }

  async sync(): Promise<{ pulled: number; pushed: number; errors: string[] }> {
    await this.init();
    const errors: string[] = [];
    let pulled = 0;
    let pushed = 0;
    try {
      const clientId = await this.ensureClient();
      const pullRes = await this.pull(clientId);
      pulled = pullRes.changes.length;
      await setState(this.adapter, KEY_CURSOR, pullRes.next_cursor);
      await setState(this.adapter, KEY_LAST_SYNC, new Date().toISOString());
      const pushRes = await this.push(clientId);
      pushed = pushRes.results.filter((r) => r.status === 'accepted').length;
    } catch (e) {
      errors.push(e instanceof Error ? e.message : String(e));
    }
    return { pulled, pushed, errors };
  }

  private async ensureClient(): Promise<string> {
    const existing = await getState(this.adapter, KEY_CLIENT_ID);
    if (existing) return existing;
    const res = await this.fetch<{ client_id: string }>('/sync/v1/clients', {
      method: 'POST', body: { device_id: this.config.device_id, driver_id: this.config.driver_id },
    });
    await setState(this.adapter, KEY_CLIENT_ID, res.client_id);
    return res.client_id;
  }

  private async pull(clientId: string): Promise<PullResponse> {
    const cursor = (await getState(this.adapter, KEY_CURSOR)) ?? '0';
    const limit = this.config.pull_limit ?? 200;
    const res = await this.fetch<PullResponse>(
      `/sync/v1/pull?client_id=${encodeURIComponent(clientId)}&cursor=${encodeURIComponent(cursor)}&limit=${limit}`,
      { method: 'GET' },
    );
    await this.adapter.transaction(async () => {
      for (const change of res.changes) await applyChange(this.adapter, change);
    });
    return res;
  }

  private async push(clientId: string): Promise<PushResponse> {
    const ops = await pendingOps(this.adapter, 50);
    if (ops.length === 0) return { results: [], server_time: new Date().toISOString() };
    const body = {
      client_id: clientId,
      ops: ops.map((o) => ({ client_op_id: o.client_op_id, op_type: o.op_type, entity_id: o.entity_id, payload: o.payload })),
    };
    const res = await this.fetch<PushResponse>('/sync/v1/push', { method: 'POST', body });
    for (const r of res.results) await markOpSynced(this.adapter, r.client_op_id, r as OpResult);
    return res;
  }

  private async fetch<T>(path: string, init: { method: string; body?: unknown }): Promise<T> {
    const url = `${this.config.api_base_url.replace(/\/$/, '')}${path}`;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.config.get_auth_token) {
      const token = await this.config.get_auth_token();
      if (token) headers.Authorization = `Bearer ${token}`;
    }
    const res = await fetch(url, {
      method: init.method, headers,
      body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`sync ${init.method} ${path} failed (${res.status}): ${text || res.statusText}`);
    }
    return res.json() as Promise<T>;
  }
}
