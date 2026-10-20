import { api } from '../../api/client';
import type { RoutePlan, CurfewZone, FuelStation } from '@tera/contracts';

export const morningMapKeys = {
  all: ['morning-map'] as const,
  routes: () => [...morningMapKeys.all, 'routes'] as const,
  zones: () => [...morningMapKeys.all, 'zones'] as const,
  stations: () => [...morningMapKeys.all, 'stations'] as const,
};
export function fetchTodayRoutes(signal?: AbortSignal) {
  return api<{ as_of: string; routes: RoutePlan[] }>({ path: '/routing/v1/routes/today', signal });
}
export function fetchCurfewZones(signal?: AbortSignal) {
  return api<{ zones: CurfewZone[] }>({ path: '/geo/v1/curfew-zones', signal });
}
export function fetchFuelStations(signal?: AbortSignal) {
  return api<{ stations: FuelStation[] }>({ path: '/geo/v1/fuel-stations', signal });
}
