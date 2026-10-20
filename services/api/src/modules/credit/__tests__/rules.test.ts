import { describe, it, expect } from 'vitest';
import { evaluateRule, decide } from '../rules.js';

describe('evaluateRule', () => {
  it('clears under limit and inside grace', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 3, graceDays: 14 });
    expect(r.triggered).toBe(false);
    expect(r.reason).toBe('NONE');
  });
  it('triggers OVER_LIMIT', () => {
    const r = evaluateRule({ exposureEtb: 120, limitEtb: 100, daysOverdue: 0, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('OVER_LIMIT');
  });
  it('triggers PAST_GRACE', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 20, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('PAST_GRACE');
  });
  it('triggers BOTH', () => {
    const r = evaluateRule({ exposureEtb: 120, limitEtb: 100, daysOverdue: 30, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('BOTH');
  });
  it('grace boundary is inclusive (not > graceDays)', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 14, graceDays: 14 });
    expect(r.triggered).toBe(false);
  });
});

describe('decide', () => {
  it('CLEARED when not triggered', () => expect(decide(false, false, true)).toBe('CLEARED'));
  it('WARNED in soft mode', () => expect(decide(true, false, false)).toBe('WARNED'));
  it('BLOCKED in hard mode', () => expect(decide(true, false, true)).toBe('BLOCKED'));
  it('WARNED when override present', () => expect(decide(true, true, true)).toBe('WARNED'));
});
