import type { SqliteAdapter, ClientOp } from './types.js';
import { queueOp } from './outbox.js';

export type StopAction = 'ARRIVED' | 'DELIVERED' | 'FAILED';
export type ProofOutcome = 'DELIVERED' | 'PARTIAL' | 'NOT_AVAILABLE' | 'RETURNED';
export type PaymentMethod = 'CASH' | 'TELEBIRR';

export async function applyStopAction(
  adapter: SqliteAdapter,
  input: { stopId: string; action: StopAction; capturedAt: string; clientOpId?: string },
): Promise<ClientOp> {
  const clientOpId = input.clientOpId ?? generateClientOpId();
  const op: ClientOp = {
    client_op_id: clientOpId,
    op_type: 'route_stop.status_update',
    entity_id: input.stopId,
    payload: { status: input.action, captured_at: input.capturedAt },
  };
  await adapter.transaction(async () => {
    const row = await adapter.get<{ id: string }>(`SELECT id FROM route_stop WHERE id = ?`, [input.stopId]);
    if (!row) throw new Error(`stop ${input.stopId} not found locally`);
    await adapter.run(`UPDATE route_stop SET status = ?, status_updated_at = ? WHERE id = ?`,
      [input.action, input.capturedAt, input.stopId]);
    await queueOp(adapter, op);
  });
  return op;
}

export interface PaymentInput { method: PaymentMethod; amountEtb: number; telebirrRef: string | null; }

export interface ApplyProofInput {
  stopId: string; outcome: ProofOutcome;
  qtyConfirmed: number | null; qtyOrdered: number | null;
  reason: string | null; signatureBase64: string | null; photoBase64: string | null;
  capturedAt: string; payment?: PaymentInput | null;
  clientOpId?: string; proofId?: string; paymentId?: string;
}

export interface ApplyProofResult {
  clientOpId: string; proofId: string; resultingStatus: StopAction;
  payment: { id: string } | null;
}

export async function applyProofCapture(
  adapter: SqliteAdapter, input: ApplyProofInput,
): Promise<ApplyProofResult> {
  const clientOpId = input.clientOpId ?? generateClientOpId();
  const proofId = input.proofId ?? generateId('proof');
  const paymentId = input.payment ? (input.paymentId ?? generateId('pay')) : null;
  const resultingStatus = statusForOutcome(input.outcome);
  const op: ClientOp = {
    client_op_id: clientOpId, op_type: 'route_stop.proof', entity_id: input.stopId,
    payload: {
      outcome: input.outcome, qty_confirmed: input.qtyConfirmed, qty_ordered: input.qtyOrdered,
      reason: input.reason, signature_base64: input.signatureBase64, photo_base64: input.photoBase64,
      captured_at: input.capturedAt,
      payment: input.payment ? { method: input.payment.method, amount_etb: input.payment.amountEtb, telebirr_ref: input.payment.telebirrRef } : null,
    },
  };
  await adapter.transaction(async () => {
    const row = await adapter.get<{ id: string }>(`SELECT id FROM route_stop WHERE id = ?`, [input.stopId]);
    if (!row) throw new Error(`stop ${input.stopId} not found locally`);
    await adapter.run(
      `INSERT INTO proof_of_delivery (id, stop_id, outcome, qty_confirmed, qty_ordered, reason,
        signature_base64, photo_base64, captured_at, client_op_id, synced_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
      [proofId, input.stopId, input.outcome, input.qtyConfirmed, input.qtyOrdered, input.reason,
       input.signatureBase64, input.photoBase64, input.capturedAt, clientOpId],
    );
    if (input.payment && paymentId) {
      await adapter.run(
        `INSERT INTO payment (id, stop_id, method, amount_etb, telebirr_ref, client_op_id, captured_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [paymentId, input.stopId, input.payment.method, input.payment.amountEtb,
         input.payment.telebirrRef, clientOpId, input.capturedAt],
      );
    }
    await adapter.run(`UPDATE route_stop SET status = ?, status_updated_at = ? WHERE id = ?`,
      [resultingStatus, input.capturedAt, input.stopId]);
    await queueOp(adapter, op);
  });
  return { clientOpId, proofId, resultingStatus, payment: paymentId ? { id: paymentId } : null };
}

function statusForOutcome(outcome: ProofOutcome): StopAction {
  if (outcome === 'DELIVERED' || outcome === 'PARTIAL') return 'DELIVERED';
  return 'FAILED';
}
function generateClientOpId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}-${Math.random().toString(36).slice(2, 10)}`;
}
function generateId(prefix: string): string {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}
