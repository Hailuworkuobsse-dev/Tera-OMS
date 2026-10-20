import { describe, it, expect } from 'vitest';
type S = 'QUEUED' | 'RUNNING' | 'DONE' | 'FAILED' | 'TIMEOUT';
const shouldProcess = (s: S) => s === 'QUEUED';
describe('solve job state', () => { it('only QUEUED jobs are processed', () => {
  expect(shouldProcess('QUEUED')).toBe(true);
  expect(shouldProcess('RUNNING')).toBe(false);
  expect(shouldProcess('DONE')).toBe(false);
}); });
