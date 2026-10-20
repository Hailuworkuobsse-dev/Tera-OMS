import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { DispatchBoardPage } from '../DispatchBoardPage';

vi.mock('../api', () => ({
  dispatchKeys: { all: ['db'], board: () => ['db', 'board'] },
  fetchBoard: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(),
    summary: { routes_planned: 1, routes_dispatched: 0, slots_available: 10, slots_allocated: 1, slots_confirmed: 0, unallocated_routes: 0 },
    docks: [{ id: 'dock-a', name: 'Dock A', slots: [
      { id: 'slot-1', start_at: new Date().toISOString(), end_at: new Date(Date.now() + 3600_000).toISOString(),
        status: 'ALLOCATED', confirmed_at: null, confirmed_by: null,
        route: { id: 'r1', vehicle_id: 'V-102', driver_id: 'D-202', status: 'PLANNED', planned_km: 38, planned_min: 220, stop_count: 4, picked_count: 4 } },
    ] }, { id: 'dock-b', name: 'Dock B', slots: [] }],
  }),
  allocateAll: vi.fn(),
  confirmSlot: vi.fn(),
  dispatchRoute: vi.fn(),
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('DispatchBoardPage', () => {
  it('renders board with V-102 and Confirm loading (all picked)', async () => {
    wrap(<DispatchBoardPage />);
    expect(await screen.findByText('Dispatch Board')).toBeInTheDocument();
    expect(await screen.findByText('V-102')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Confirm loading/ })).toBeInTheDocument();
  });
});
