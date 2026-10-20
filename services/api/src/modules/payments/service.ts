import type { UnreconciledPaymentsResponse, ReconcileResponse } from '@tera/contracts';
import * as repo from './repository.js';
import { canReconcile } from './rules.js';
import { writeAudit } from '../../core/audit.js';
export async function listUnreconciled(limit = 100): Promise<UnreconciledPaymentsResponse> {
  const rows = await repo.findUnreconciled(limit);
  const stops = await repo.findRouteStopsByIds(Array.from(new Set(rows.map((r) => r.routeStopId))));
  const byId = new Map(stops.map((s) => [s.id, s]));
  return { total: rows.length, payments: rows.map((p) => {
    const s = byId.get(p.routeStopId);
    return { id: p.id, route_stop_id: p.routeStopId, driver_id: s?.routePlan.driverId ?? '?', vehicle_id: s?.routePlan.vehicleId ?? '?', distributor_name: s?.distributorName ?? '(unknown)', method: p.method as 'CASH'|'TELEBIRR', amount_etb: Number(p.amountEtb), telebirr_ref: p.telebirrRef, captured_at: p.capturedAt.toISOString() };
  }) };
}
export async function reconcile(id: string, actorId: string, notes: string | null): Promise<ReconcileResponse> {
  const payment = await repo.findById(id);
  if (!payment) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const gate = canReconcile({ reconciledAt: payment.reconciledAt?.toISOString() ?? null });
  if (!gate.allowed) { const e = new Error(gate.reason!) as any; e.statusCode = 400; throw e; }
  const updated = await repo.reconcile(id, actorId, notes);
  await writeAudit({ actorId, entity: 'payment', entityId: id, action: 'reconciled', reason: notes?.trim() || `${payment.method} payment reconciled`, meta: { amountEtb: Number(payment.amountEtb), method: payment.method } });
  return { ok: true, reconciled_at: updated.reconciledAt!.toISOString() };
}
