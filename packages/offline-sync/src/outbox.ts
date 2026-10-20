import type { SqliteAdapter, OutboxOp, ClientOp, OpResult } from './types.js';

export async function queueOp(adapter: SqliteAdapter, op: ClientOp): Promise<void> {
  await adapter.run(
    `INSERT INTO outbox(client_op_id, op_type, entity_id, payload_json, queued_at, synced_at, result_json)
     VALUES(?, ?, ?, ?, ?, NULL, NULL)`,
    [op.client_op_id, op.op_type, op.entity_id, JSON.stringify(op.payload), new Date().toISOString()],
  );
}

export async function pendingOps(adapter: SqliteAdapter, limit = 50): Promise<OutboxOp[]> {
  const rows = await adapter.all<any>(
    `SELECT * FROM outbox WHERE synced_at IS NULL ORDER BY queued_at ASC LIMIT ?`, [limit],
  );
  return rows.map((r) => ({
    client_op_id: r.client_op_id, op_type: r.op_type, entity_id: r.entity_id,
    payload: JSON.parse(r.payload_json), queued_at: r.queued_at,
    synced_at: r.synced_at, result: r.result_json ? JSON.parse(r.result_json) : null,
  }));
}

export async function countPending(adapter: SqliteAdapter): Promise<number> {
  const row = await adapter.get<{ n: number }>(`SELECT COUNT(*) AS n FROM outbox WHERE synced_at IS NULL`);
  return row?.n ?? 0;
}

export async function markOpSynced(adapter: SqliteAdapter, client_op_id: string, result: OpResult): Promise<void> {
  await adapter.run(
    `UPDATE outbox SET synced_at = ?, result_json = ? WHERE client_op_id = ?`,
    [new Date().toISOString(), JSON.stringify(result), client_op_id],
  );
}
