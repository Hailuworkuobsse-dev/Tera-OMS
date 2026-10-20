import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { RouteBuilderPage } from '../RouteBuilderPage';

const mockResult = {
  manual: { stops: [
    { order_id: 'o1', distributor_name: 'Bole Retail', seq: 1, eta: new Date().toISOString(), lat: 8.9948, lng: 38.7923 },
    { order_id: 'o2', distributor_name: 'Piassa Traders', seq: 2, eta: new Date().toISOString(), lat: 9.0333, lng: 38.75 },
  ], total_km: 20, total_min: 48 },
  optimized: { stops: [
    { order_id: 'o2', distributor_name: 'Piassa Traders', seq: 1, eta: new Date().toISOString(), lat: 9.0333, lng: 38.75 },
    { order_id: 'o1', distributor_name: 'Bole Retail', seq: 2, eta: new Date().toISOString(), lat: 8.9948, lng: 38.7923 },
  ], total_km: 16, total_min: 38 },
  savings_km_pct: 20, savings_time_pct: 20.8, infeasible: null,
};

vi.mock('../api', async () => {
  const today = new Date();
  const startH = (h: number) => { const d = new Date(today); d.setHours(h, 0, 0, 0); return d.toISOString(); };
  return {
    routeBuilderKeys: { all: ['rb'], pending: () => ['rb', 'pending'], vehicles: () => ['rb', 'vehicles'], solveJob: (id: string) => ['rb', 'job', id] },
    fetchPendingOrders: vi.fn().mockResolvedValue({
      orders: [
        { id: 'o1', distributor_id: 'd1', distributor_name: 'Bole Retail', lat: 8.9948, lng: 38.7923, weight_kg: 80, volume_m3: 0.4, priority: 8, time_window_start: startH(8), time_window_end: startH(12), status: 'PENDING', created_at: new Date().toISOString() },
        { id: 'o2', distributor_id: 'd2', distributor_name: 'Piassa Traders', lat: 9.0333, lng: 38.75, weight_kg: 95, volume_m3: 0.5, priority: 5, time_window_start: startH(10), time_window_end: startH(14), status: 'PENDING', created_at: new Date().toISOString() },
      ],
    }),
    fetchVehicles: vi.fn().mockResolvedValue({
      vehicles: [{ id: 'V-101', plate: 'AA-3-B-101', capacity_kg: 1500, capacity_m3: 8, shift_start_h: 7, shift_end_h: 18, start_lat: 9.0108, start_lng: 38.7613 }],
    }),
    solveRoutes: vi.fn(),
    submitAsyncSolve: vi.fn().mockResolvedValue({ job_id: 'job-1', status: 'QUEUED' }),
    getAsyncSolveJob: vi.fn().mockResolvedValue({ job_id: 'job-1', status: 'DONE', submitted_at: new Date().toISOString(), started_at: new Date().toISOString(), finished_at: new Date().toISOString(), duration_ms: 120, result: mockResult, error: null }),
    acceptRoute: vi.fn().mockResolvedValue({ route_id: 'r1', planned_km: 16, planned_min: 38 }),
  };
});
vi.mock('react-leaflet', () => ({
  MapContainer: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  TileLayer: () => null, Polyline: () => null, CircleMarker: () => null,
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('RouteBuilderPage', () => {
  it('renders pending orders', async () => {
    wrap(<RouteBuilderPage />);
    expect(await screen.findByText('Bole Retail')).toBeInTheDocument();
    expect(screen.getByText('AA-3-B-101')).toBeInTheDocument();
  });
  it('solves async and shows comparison', async () => {
    wrap(<RouteBuilderPage />);
    const checks = await screen.findAllByRole('checkbox');
    fireEvent.click(checks[0]!); fireEvent.click(checks[1]!);
    fireEvent.click(screen.getByText('AA-3-B-101'));
    fireEvent.click(screen.getByRole('button', { name: /Solve/ }));
    await waitFor(() => {
      expect(screen.getByText(/20\.0% fewer km/)).toBeInTheDocument();
      expect(screen.getByText(/20\.8% faster/)).toBeInTheDocument();
    });
  });
});
