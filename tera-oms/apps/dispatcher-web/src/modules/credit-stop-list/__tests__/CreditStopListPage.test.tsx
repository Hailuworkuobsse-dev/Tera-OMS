import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { CreditStopListPage } from '../CreditStopListPage';

vi.mock('../api', () => ({
  creditKeys: { all: ['credit'], stopList: () => ['credit', 'stop-list', 'today'] },
  fetchCreditStopList: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(), hard_gate: false,
    rows: [{ distributor_id: 'd1', distributor_name: 'Abebe Distribution', region: 'Addis',
      decision: 'WARNED', reason: 'OVER_LIMIT', amount_owed_etb: 120_000, credit_limit_etb: 100_000,
      exposure_etb: 120_000, days_overdue: 42, grace_days: 14,
      blocked_at: new Date().toISOString(), active_override_until: null }],
  }),
  overrideCredit: vi.fn(),
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('CreditStopListPage', () => {
  it('renders title, soft banner, and distributor row', async () => {
    wrap(<CreditStopListPage />);
    expect(screen.getByText('Credit Stop List')).toBeInTheDocument();
    expect(await screen.findByText('Abebe Distribution')).toBeInTheDocument();
    expect(screen.getByText(/soft mode/i)).toBeInTheDocument();
  });
});
