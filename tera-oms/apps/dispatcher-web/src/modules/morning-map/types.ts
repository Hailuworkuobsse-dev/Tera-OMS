import type { RoutePlan, CurfewZone, FuelStation } from '@tera/contracts';
export type { RoutePlan, CurfewZone, FuelStation };
export type LiveRouteStatus = 'on-track' | 'late' | 'off-route';
export interface LiveVehicle {
  route: RoutePlan; current_stop_index: number;
  status: LiveRouteStatus; minutes_behind: number;
}
