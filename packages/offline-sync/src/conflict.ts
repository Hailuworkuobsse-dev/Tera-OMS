export type Entity = 'route_stop' | 'credit' | 'payment' | 'inventory' | 'unknown';
export type Resolution =
  | { kind: 'accept_client'; reason: string }
  | { kind: 'server_wins'; reason: string }
  | { kind: 'reject_conflict'; reason: string };

export function resolveConflict(input: { entity: Entity; server_updated_at: string; client_captured_at: string }): Resolution {
  if (input.entity === 'credit' || input.entity === 'payment' || input.entity === 'inventory') {
    return { kind: 'server_wins', reason: `${input.entity} is server-authoritative` };
  }
  if (input.entity === 'route_stop') {
    const serverMs = Date.parse(input.server_updated_at);
    const clientMs = Date.parse(input.client_captured_at);
    if (!Number.isFinite(serverMs) || !Number.isFinite(clientMs)) return { kind: 'reject_conflict', reason: 'invalid timestamp' };
    if (clientMs > serverMs) return { kind: 'accept_client', reason: 'client acted after server last changed' };
    return { kind: 'reject_conflict', reason: 'server updated after client captured' };
  }
  return { kind: 'server_wins', reason: 'unknown entity — default to server' };
}
