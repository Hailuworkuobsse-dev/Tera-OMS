import { describe, it, expect } from 'vitest';
import { bucketForDaysOverdue, enrichAccount } from '../finance.js';

describe('bucketForDaysOverdue', () => {
  it('current at 0 or negative', () => {
    expect(bucketForDaysOverdue(0)).toBe('current');
    expect(bucketForDaysOverdue(-3)).toBe('current');
  });
  it('watch 1-14', () => {
    expect(bucketForDaysOverdue(1)).toBe('watch');
    expect(bucketForDaysOverdue(14)).toBe('watch');
  });
  it('overdue 15-30', () => {
    expect(bucketForDaysOverdue(15)).toBe('overdue');
    expect(bucketForDaysOverdue(30)).toBe('overdue');
  });
  it('critical 31+', () => {
    expect(bucketForDaysOverdue(31)).toBe('critical');
  });
});

describe('enrichAccount', () => {
  const NOW = new Date('2026-04-12T12:00:00.000Z');
  it('computes utilization and days_overdue', () => {
    const r = enrichAccount({
      distributorId: 'd1', distributorName: 'A', region: 'Addis',
      limitEtb: 100_000, exposureEtb: 120_000,
      oldestUnpaidAt: new Date('2026-03-01T00:00:00.000Z'), graceDays: 14,
    }, NOW);
    expect(r.utilization_pct).toBe(120);
    expect(r.days_overdue).toBe(28); // 42 days - 14 grace
  });
  it('null oldest => 0 days overdue', () => {
    const r = enrichAccount({
      distributorId: 'd', distributorName: 'A', region: 'A',
      limitEtb: 100, exposureEtb: 10, oldestUnpaidAt: null, graceDays: 14,
    }, NOW);
    expect(r.days_since_oldest_unpaid).toBe(0);
    expect(r.days_overdue).toBe(0);
  });
  it('zero limit => 0%', () => {
    const r = enrichAccount({
      distributorId: 'd', distributorName: 'A', region: 'A',
      limitEtb: 0, exposureEtb: 5000, oldestUnpaidAt: null, graceDays: 14,
    }, NOW);
    expect(r.utilization_pct).toBe(0);
  });
});
