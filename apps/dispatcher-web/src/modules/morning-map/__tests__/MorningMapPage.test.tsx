import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { MorningMapPage } from '../MorningMapPage';

vi.mock('../api', () => ({
  morningMapKeys: { all: ['mm'], routes: () => ['mm', 'routes'], zones: () => ['mm', 'zones'], stations: () => ['mm', 'stations'] },
  fetchTodayRoutes: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(),
    routes: [{ id: 'r1', vehicle_id: 'V-101', driver_id: 'D-201', status: 'DISPATCHED',
      planned_km: 42.5, planned_min: 240, start_lat: 9.0108, start_lng: 38.7613,
      stops: [
        { id: 's1', seq: 1, distributor_id: 'd1', distributor_name: 'Bole Retail',
          lat: 8.9948, lng: 38.7923, planned_eta: new Date().toISOString(), actual_arrival: new Date().toISOString(), status: 'DELIVERED' },
        { id: 's2', seq: 2, distributor_id: 'd2', distributor_name: 'Piassa Traders',
          lat: 9.0333, lng: 38.75, planned_eta: new Date(Date.now() + 3600_000).toISOString(), actual_arrival: null, status: 'PENDING' },
      ] }],
  }),
  fetchCurfewZones: vi.fn().mockResolvedValue({ zones: [] }),
  fetchFuelStations: vi.fn().mockResolvedValue({ stations: [] }),
}));

vi.mock('react-leaflet', () => ({
  MapContainer: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  TileLayer: () => null, Polyline: () => null, CircleMarker: () => null, Polygon: () => null, Marker: () => null,
  Popup: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
}));
vi.mock('leaflet', () => ({ default: { Icon: { Default: { prototype: {}, mergeOptions: () => {} } } } }));
vi.mock('leaflet/dist/leaflet.css', () => ({}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('MorningMapPage', () => {
  it('renders title and vehicle sidebar', async () => {
    wrap(<MorningMapPage />);
    expect(screen.getByText('Morning Map')).toBeInTheDocument();
    expect(await screen.findByText('V-101')).toBeInTheDocument();
    expect(screen.getByText(/1\/2/)).toBeInTheDocument();
  });
});
