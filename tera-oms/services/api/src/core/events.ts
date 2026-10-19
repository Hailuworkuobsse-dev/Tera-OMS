// In-process event emitter; swap to BullMQ for cross-process events.
import { EventEmitter } from 'node:events';
export const bus = new EventEmitter();
