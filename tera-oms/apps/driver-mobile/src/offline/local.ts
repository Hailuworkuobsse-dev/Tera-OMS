import {
  applyStopAction, applyProofCapture, applyFuelLog,
  getLocalManifest, getFuelContext,
  type StopAction, type ProofOutcome, type PaymentMethod,
  type LocalManifest, type FuelContext, type FuelHint,
} from '@tera/offline-sync';
import { createExpoAdapter } from './adapter';

export async function readManifest(): Promise<LocalManifest> {
  const adapter = await createExpoAdapter();
  return getLocalManifest(adapter);
}
export async function readFuelContext(): Promise<FuelContext> {
  const adapter = await createExpoAdapter();
  return getFuelContext(adapter);
}
export async function recordStopAction(stopId: string, action: StopAction): Promise<void> {
  const adapter = await createExpoAdapter();
  await applyStopAction(adapter, { stopId, action, capturedAt: new Date().toISOString() });
}

export interface RecordProofInput {
  stopId: string; outcome: ProofOutcome;
  qtyConfirmed: number; qtyOrdered: number;
  reason: string | null; signatureBase64: string | null; photoBase64: string | null;
  payment: { method: PaymentMethod; amountEtb: number; telebirrRef: string | null } | null;
}
export async function recordProofOfDelivery(input: RecordProofInput): Promise<void> {
  const adapter = await createExpoAdapter();
  await applyProofCapture(adapter, {
    stopId: input.stopId, outcome: input.outcome,
    qtyConfirmed: input.qtyConfirmed, qtyOrdered: input.qtyOrdered,
    reason: input.reason, signatureBase64: input.signatureBase64, photoBase64: input.photoBase64,
    capturedAt: new Date().toISOString(), payment: input.payment,
  });
}

export interface RecordFuelInput {
  vehicleId: string; driverId: string;
  liters: number; amountEtb: number; odometerKm: number;
  stationName: string; stationId: string | null;
}
export async function recordFuelLog(input: RecordFuelInput): Promise<FuelHint> {
  const adapter = await createExpoAdapter();
  const result = await applyFuelLog(adapter, { ...input, capturedAt: new Date().toISOString() });
  return result.hint;
}
