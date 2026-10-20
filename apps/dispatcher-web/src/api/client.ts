const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); }
}

// In-memory fallback state for AI Studio preview environment
const now = new Date();
const todayIso = (h: number, m = 0) => {
  const d = new Date(now);
  d.setHours(h, m, 0, 0);
  return d.toISOString();
};

const mockRoutes = [
  {
    id: 'route-today-d201',
    vehicle_id: 'V-101',
    driver_id: 'D-201',
    status: 'DISPATCHED' as const,
    planned_km: 42.5,
    planned_min: 240,
    start_lat: 9.0108,
    start_lng: 38.7613,
    stops: [
      { id: 'stop-1', seq: 1, distributor_id: 'seed-dist-1', distributor_name: 'Bole Retail', lat: 8.9948, lng: 38.7923, planned_eta: todayIso(9, 0), actual_arrival: todayIso(9, 5), status: 'DELIVERED' as const },
      { id: 'stop-2', seq: 2, distributor_id: 'seed-dist-2', distributor_name: 'Kazanchis Mart', lat: 9.0167, lng: 38.7667, planned_eta: todayIso(10, 0), actual_arrival: todayIso(10, 2), status: 'ARRIVED' as const },
      { id: 'stop-3', seq: 3, distributor_id: 'seed-dist-3', distributor_name: 'Piassa Traders', lat: 9.0333, lng: 38.7500, planned_eta: todayIso(11, 0), actual_arrival: null, status: 'PENDING' as const },
      { id: 'stop-4', seq: 4, distributor_id: 'seed-dist-4', distributor_name: 'Merkato Wholesale', lat: 9.0348, lng: 38.7466, planned_eta: todayIso(12, 0), actual_arrival: null, status: 'PENDING' as const },
      { id: 'stop-5', seq: 5, distributor_id: 'seed-dist-5', distributor_name: 'Saris Corner', lat: 8.9900, lng: 38.7400, planned_eta: todayIso(13, 0), actual_arrival: null, status: 'PENDING' as const },
    ],
  },
  {
    id: 'route-today-v102',
    vehicle_id: 'V-102',
    driver_id: 'D-202',
    status: 'PLANNED' as const,
    planned_km: 38.2,
    planned_min: 220,
    start_lat: 9.0108,
    start_lng: 38.7613,
    stops: [
      { id: 'v102-stop-1', seq: 1, distributor_id: 'seed-dist-v102-1', distributor_name: 'CMC Store', lat: 9.0200, lng: 38.8300, planned_eta: todayIso(9, 30), actual_arrival: null, status: 'PENDING' as const },
      { id: 'v102-stop-2', seq: 2, distributor_id: 'seed-dist-v102-2', distributor_name: 'Bole Medhanialem', lat: 9.0050, lng: 38.7850, planned_eta: todayIso(10, 30), actual_arrival: null, status: 'PENDING' as const },
      { id: 'v102-stop-3', seq: 3, distributor_id: 'seed-dist-v102-3', distributor_name: 'Megenagna Shop', lat: 9.0200, lng: 38.8000, planned_eta: todayIso(11, 30), actual_arrival: null, status: 'PENDING' as const },
      { id: 'v102-stop-4', seq: 4, distributor_id: 'seed-dist-v102-4', distributor_name: 'Sarbet Retail', lat: 8.9950, lng: 38.7600, planned_eta: todayIso(12, 30), actual_arrival: null, status: 'PENDING' as const },
    ],
  },
];

const mockCurfewZones = [
  { id: 'zone-merkato', name: 'Merkato Heavy Truck Ban', polygon: { type: 'Polygon' as const, coordinates: [[[38.7400, 9.0300], [38.7550, 9.0300], [38.7550, 9.0400], [38.7400, 9.0400], [38.7400, 9.0300]]] }, start_hour: 7, end_hour: 10, reason: 'Morning peak truck restriction', active: true },
  { id: 'zone-piassa', name: 'Piassa Central Ban', polygon: { type: 'Polygon' as const, coordinates: [[[38.7450, 9.0280], [38.7600, 9.0280], [38.7600, 9.0380], [38.7450, 9.0380], [38.7450, 9.0280]]] }, start_hour: 17, end_hour: 20, reason: 'Evening pedestrian zone', active: true },
  { id: 'zone-bole-overnight', name: 'Bole Overnight Restriction', polygon: { type: 'Polygon' as const, coordinates: [[[38.7800, 8.9900], [38.8000, 8.9900], [38.8000, 9.0100], [38.7800, 9.0100], [38.7800, 8.9900]]] }, start_hour: 22, end_hour: 6, reason: 'Overnight residential noise ban', active: true },
];

const mockFuelStations = [
  { id: 'fuel-1', name: 'Bole Total', lat: 8.9948, lng: 38.7923, status: 'operational' as const, active: true, updated_at: now.toISOString() },
  { id: 'fuel-2', name: 'Mexico Nile', lat: 9.0100, lng: 38.7500, status: 'queued' as const, active: true, updated_at: now.toISOString() },
  { id: 'fuel-3', name: 'CMC NOC', lat: 9.0200, lng: 38.8300, status: 'operational' as const, active: true, updated_at: now.toISOString() },
  { id: 'fuel-4', name: 'Sarbet Shell', lat: 8.9950, lng: 38.7600, status: 'dry' as const, active: true, updated_at: now.toISOString() },
];

const mockOrders = [
  { id: 'seed-order-1', distributor_id: 'seed-dist-1', distributor_name: 'Bole Retail', lat: 8.9948, lng: 38.7923, weight_kg: 80, volume_m3: 0.4, priority: 8, time_window_start: todayIso(8), time_window_end: todayIso(12), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-2', distributor_id: 'seed-dist-2', distributor_name: 'Kazanchis Mart', lat: 9.0167, lng: 38.7667, weight_kg: 120, volume_m3: 0.6, priority: 6, time_window_start: todayIso(9), time_window_end: todayIso(13), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-3', distributor_id: 'seed-dist-3', distributor_name: 'Piassa Traders', lat: 9.0333, lng: 38.7500, weight_kg: 95, volume_m3: 0.5, priority: 5, time_window_start: todayIso(10), time_window_end: todayIso(14), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-4', distributor_id: 'seed-dist-4', distributor_name: 'Merkato Wholesale', lat: 9.0348, lng: 38.7466, weight_kg: 200, volume_m3: 1.2, priority: 9, time_window_start: todayIso(11), time_window_end: todayIso(15), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-5', distributor_id: 'seed-dist-5', distributor_name: 'Saris Corner', lat: 8.9900, lng: 38.7400, weight_kg: 60, volume_m3: 0.3, priority: 4, time_window_start: todayIso(10), time_window_end: todayIso(16), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-6', distributor_id: 'seed-dist-6', distributor_name: 'CMC Store', lat: 9.0200, lng: 38.8300, weight_kg: 150, volume_m3: 0.8, priority: 7, time_window_start: todayIso(8), time_window_end: todayIso(12), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-7', distributor_id: 'seed-dist-7', distributor_name: 'Bole Medhanialem', lat: 9.0050, lng: 38.7850, weight_kg: 70, volume_m3: 0.35, priority: 6, time_window_start: todayIso(9), time_window_end: todayIso(14), status: 'PENDING' as const, created_at: todayIso(6) },
  { id: 'seed-order-8', distributor_id: 'seed-dist-8', distributor_name: 'Megenagna Shop', lat: 9.0200, lng: 38.8000, weight_kg: 110, volume_m3: 0.6, priority: 5, time_window_start: todayIso(10), time_window_end: todayIso(15), status: 'PENDING' as const, created_at: todayIso(6) },
];

const mockVehicles = [
  { id: 'V-101', plate: 'AA-3-B-101', capacity_kg: 1500, capacity_m3: 8, shift_start_h: 7, shift_end_h: 18, start_lat: 9.0108, start_lng: 38.7613 },
  { id: 'V-102', plate: 'AA-3-B-102', capacity_kg: 1500, capacity_m3: 8, shift_start_h: 7, shift_end_h: 18, start_lat: 9.0108, start_lng: 38.7613 },
  { id: 'V-103', plate: 'AA-3-B-103', capacity_kg: 1000, capacity_m3: 5, shift_start_h: 7, shift_end_h: 17, start_lat: 9.0108, start_lng: 38.7613 },
];

const mockDocks = [
  {
    id: 'dock-a',
    name: 'Dock A',
    slots: [
      {
        id: 'dock-a-slot-0', start_at: todayIso(6), end_at: todayIso(7), status: 'ALLOCATED' as const,
        confirmed_at: null, confirmed_by: null,
        route: { id: 'route-today-v102', vehicle_id: 'V-102', driver_id: 'D-202', status: 'PLANNED' as const, planned_km: 38.2, planned_min: 220, stop_count: 4, picked_count: 4 },
      },
      {
        id: 'dock-a-slot-1', start_at: todayIso(7), end_at: todayIso(8), status: 'CONFIRMED' as const,
        confirmed_at: todayIso(7, 10), confirmed_by: 'Dispatcher',
        route: { id: 'route-today-d201', vehicle_id: 'V-101', driver_id: 'D-201', status: 'PLANNED' as const, planned_km: 42.5, planned_min: 240, stop_count: 5, picked_count: 5 },
      },
      { id: 'dock-a-slot-2', start_at: todayIso(8), end_at: todayIso(9), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-a-slot-3', start_at: todayIso(9), end_at: todayIso(10), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
    ],
  },
  {
    id: 'dock-b',
    name: 'Dock B',
    slots: [
      { id: 'dock-b-slot-0', start_at: todayIso(6), end_at: todayIso(7), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-b-slot-1', start_at: todayIso(7), end_at: todayIso(8), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-b-slot-2', start_at: todayIso(8), end_at: todayIso(9), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-b-slot-3', start_at: todayIso(9), end_at: todayIso(10), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
    ],
  },
  {
    id: 'dock-c',
    name: 'Dock C',
    slots: [
      { id: 'dock-c-slot-0', start_at: todayIso(6), end_at: todayIso(7), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-c-slot-1', start_at: todayIso(7), end_at: todayIso(8), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-c-slot-2', start_at: todayIso(8), end_at: todayIso(9), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
      { id: 'dock-c-slot-3', start_at: todayIso(9), end_at: todayIso(10), status: 'AVAILABLE' as const, confirmed_at: null, confirmed_by: null, route: null },
    ],
  },
];

const mockCreditStops = [
  {
    distributor_id: 'seed-dist-2', distributor_name: 'Bole Wholesale Co.', region: 'Addis',
    decision: 'BLOCKED' as const, reason: 'BOTH' as const,
    amount_owed_etb: 250000, credit_limit_etb: 200000, exposure_etb: 250000,
    days_overdue: 65, grace_days: 14,
    blocked_at: new Date(Date.now() - 51 * 86400000).toISOString(),
    active_override_until: null,
  },
  {
    distributor_id: 'seed-dist-5', distributor_name: 'CMC Retailers', region: 'Addis',
    decision: 'WARNED' as const, reason: 'PAST_GRACE' as const,
    amount_owed_etb: 180000, credit_limit_etb: 200000, exposure_etb: 180000,
    days_overdue: 25, grace_days: 14,
    blocked_at: new Date(Date.now() - 11 * 86400000).toISOString(),
    active_override_until: null,
  },
  {
    distributor_id: 'seed-dist-3', distributor_name: 'Kazanchis Distributors', region: 'Addis',
    decision: 'CLEARED' as const, reason: 'NONE' as const,
    amount_owed_etb: 90000, credit_limit_etb: 100000, exposure_etb: 90000,
    days_overdue: 0, grace_days: 14,
    blocked_at: now.toISOString(),
    active_override_until: null,
  },
  {
    distributor_id: 'seed-dist-1', distributor_name: 'Abebe Distribution', region: 'Addis',
    decision: 'CLEARED' as const, reason: 'NONE' as const,
    amount_owed_etb: 25000, credit_limit_etb: 100000, exposure_etb: 25000,
    days_overdue: 0, grace_days: 14,
    blocked_at: now.toISOString(),
    active_override_until: null,
  },
];

function handleMockRequest(path: string, method = 'GET', body?: any): any {
  if (path === '/routing/v1/routes/today') {
    return { as_of: new Date().toISOString(), routes: mockRoutes };
  }
  if (path === '/geo/v1/curfew-zones') {
    return { zones: mockCurfewZones };
  }
  if (path === '/geo/v1/fuel-stations') {
    return { stations: mockFuelStations };
  }
  if (path === '/orders/v1/pending') {
    return { orders: mockOrders };
  }
  if (path === '/routing/v1/vehicles') {
    return { vehicles: mockVehicles };
  }
  if (path === '/routing/v1/solve' && method === 'POST') {
    const selectedIds = new Set(body?.order_ids ?? []);
    const chosenOrders = mockOrders.filter((o) => selectedIds.has(o.id));
    const manualStops = chosenOrders.map((o, idx) => ({
      order_id: o.id, distributor_name: o.distributor_name, seq: idx + 1,
      eta: todayIso(9 + idx, 15), lat: o.lat, lng: o.lng,
    }));
    const optimizedStops = [...manualStops].reverse().map((s, idx) => ({
      ...s, seq: idx + 1, eta: todayIso(9 + idx, 0),
    }));
    return {
      manual: { stops: manualStops, total_km: 46.8, total_min: 245 },
      optimized: { stops: optimizedStops, total_km: 37.4, total_min: 198 },
      savings_km_pct: 20.1,
      savings_time_pct: 19.2,
      infeasible: null,
    };
  }
  if (path === '/routing/v1/solve/async' && method === 'POST') {
    return { job_id: 'job-' + Date.now(), status: 'DONE' };
  }
  if (path.startsWith('/routing/v1/solve/jobs/')) {
    const jobId = path.split('/').pop() ?? 'job-1';
    const manualStops = mockOrders.slice(0, 4).map((o, idx) => ({
      order_id: o.id, distributor_name: o.distributor_name, seq: idx + 1,
      eta: todayIso(9 + idx, 15), lat: o.lat, lng: o.lng,
    }));
    const optimizedStops = [...manualStops].reverse().map((s, idx) => ({
      ...s, seq: idx + 1, eta: todayIso(9 + idx, 0),
    }));
    return {
      job_id: jobId,
      status: 'DONE',
      submitted_at: todayIso(8, 0),
      started_at: todayIso(8, 0),
      finished_at: todayIso(8, 0),
      duration_ms: 120,
      result: {
        manual: { stops: manualStops, total_km: 46.8, total_min: 245 },
        optimized: { stops: optimizedStops, total_km: 37.4, total_min: 198 },
        savings_km_pct: 20.1,
        savings_time_pct: 19.2,
        infeasible: null,
      },
      error: null,
    };
  }
  if (path === '/routing/v1/routes' && method === 'POST') {
    return { route_id: 'route-gen-' + Date.now(), planned_km: 37.4, planned_min: 198 };
  }
  if (path === '/dispatch/v1/board') {
    return {
      as_of: new Date().toISOString(),
      summary: {
        routes_planned: 1, routes_dispatched: 1,
        slots_available: 10, slots_allocated: 1,
        slots_confirmed: 1, unallocated_routes: 0,
      },
      docks: mockDocks,
    };
  }
  if (path === '/dispatch/v1/slots/allocate' && method === 'POST') {
    return { allocated: 1, skipped_unallocatable: 0 };
  }
  if (path.includes('/confirm') && method === 'POST') {
    const match = path.match(/\/slots\/([^/]+)\/confirm/);
    const slotId = match ? match[1] : 'slot-0';
    for (const d of mockDocks) {
      for (const s of d.slots) {
        if (s.id === slotId) {
          (s as any).status = 'CONFIRMED';
          (s as any).confirmed_at = new Date().toISOString();
        }
      }
    }
    return { slot_id: slotId, status: 'CONFIRMED', confirmed_at: new Date().toISOString() };
  }
  if (path.includes('/dispatch') && method === 'POST') {
    const match = path.match(/\/routes\/([^/]+)\/dispatch/);
    const routeId = match ? match[1] : 'route-0';
    for (const d of mockDocks) {
      for (const s of d.slots) {
        if (s.route && s.route.id === routeId) {
          (s.route as any).status = 'DISPATCHED';
        }
      }
    }
    return { route_id: routeId, status: 'DISPATCHED', slot_status: 'CONFIRMED' };
  }
  if (path === '/credit/v1/stop-list') {
    return {
      as_of: new Date().toISOString(),
      hard_gate: false,
      rows: mockCreditStops,
    };
  }
  if (path === '/credit/v1/overrides' && method === 'POST') {
    const target = mockCreditStops.find((s) => s.distributor_id === body?.distributor_id);
    if (target) {
      target.decision = 'CLEARED';
      target.active_override_until = body?.expires_at ?? todayIso(23, 59);
    }
    return { ok: true, expires_at: body?.expires_at ?? todayIso(23, 59) };
  }
  return {};
}

export async function api<T>({ method = 'GET', path, body, signal }: {
  method?: string; path: string; body?: unknown; signal?: AbortSignal;
}): Promise<T> {
  try {
    const res = await fetch(`${BASE}${path}`, {
      method, headers: { 'Content-Type': 'application/json' },
      body: body !== undefined ? JSON.stringify(body) : undefined, signal,
    });
    if (!res.ok) {
      // If server returns error, check if local fallback is appropriate
      const p = await res.json().catch(() => ({}));
      throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p);
    }
    return res.status === 204 ? (undefined as T) : res.json();
  } catch (err: any) {
    if (err instanceof ApiError) throw err;
    // Network failure / server offline fallback
    console.info(`[Tera OMS] Backend offline (${path}) — serving in-memory preview data`);
    return handleMockRequest(path, method, body) as T;
  }
}

