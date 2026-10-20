import { bus } from '../../core/events.js';
export function emitCreditOverridden(payload: { distributorId: string; expiresAt: string; actorId: string }): void {
  bus.emit('credit.overridden', payload);
}
