export { SyncEngine } from './sync-engine.js';
export { createSchema } from './schema.js';
export { queueOp, pendingOps, countPending, markOpSynced } from './outbox.js';
export { resolveConflict, type Resolution, type Entity } from './conflict.js';
export { getState, setState } from './state.js';
export {
  applyStopAction, applyProofCapture,
  type StopAction, type ProofOutcome, type PaymentMethod, type PaymentInput,
  type ApplyProofInput, type ApplyProofResult,
} from './driver-ops.js';
export {
  getLocalManifest,
  type LocalManifest, type LocalPlan, type LocalStop, type PaymentStatus, type PaymentMethodValue,
} from './manifest-read.js';
export {
  applyFuelLog, computeFuelHint, getFuelContext,
  type FuelHint, type FuelHintLevel, type LocalVehicle, type LocalFuelFill, type FuelContext,
  type ApplyFuelInput, type ApplyFuelResult,
} from './fuel.js';
export type * from './types.js';
