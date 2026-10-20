import { useQuery } from '@tanstack/react-query';
import { morningMapKeys, fetchTodayRoutes, fetchCurfewZones, fetchFuelStations } from './api';
import type { RoutePlan } from './types';

export function useTodayRoutes() {
  return useQuery({ queryKey: morningMapKeys.routes(), queryFn: ({ signal }) => fetchTodayRoutes(signal), refetchInterval: 30_000 });
}
export function useCurfewZones() {
  return useQuery({ queryKey: morningMapKeys.zones(), queryFn: ({ signal }) => fetchCurfewZones(signal), refetchInterval: 300_000 });
}
export function useFuelStations() {
  return useQuery({ queryKey: morningMapKeys.stations(), queryFn: ({ signal }) => fetchFuelStations(signal), refetchInterval: 300_000 });
}

export function deriveLiveVehicles(routes: RoutePlan[]): LiveVehicleDerived[] {
  const now = Date.now();
  return routes.map((route) => {
    const currentIndex = route.stops.findIndex((s) => s.status === 'PENDING');
    const idx = currentIndex < 0 ? route.stops.length - 1 : currentIndex;
    const current = route.stops[idx];
    const etaMs = current ? new Date(current.planned_eta).getTime() : now;
    const minutesBehind = Math.max(0, Math.round((now - etaMs) / 60_000));
    const status = minutesBehind > 20 ? 'late' : 'on-track';
    return { route, current_stop_index: idx, status, minutes_behind: minutesBehind };
  });
}
interface LiveVehicleDerived {
  route: RoutePlan; current_stop_index: number;
  status: 'on-track' | 'late'; minutes_behind: number;
}
