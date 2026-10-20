export interface Point { lat: number; lng: number }
export interface Polygon { type: 'Polygon'; coordinates: [number, number][][] }
export interface SolveOrder extends Point {
  id: string; distributor_name: string;
  weight_kg: number; volume_m3: number; priority: number;
  time_window_start: string; time_window_end: string;
}
export interface SolveVehicle extends Point {
  id: string; capacity_kg: number; capacity_m3: number;
  shift_start_h: number; shift_end_h: number;
}
export interface CurfewZone { id: string; name: string; polygon: Polygon; start_hour: number; end_hour: number; }
export interface SolveConstraints {
  curfew_zones: CurfewZone[];
  avg_speed_kmh?: number; service_min_per_stop?: number;
}
export interface SolveStop {
  order_id: string; distributor_name: string; seq: number;
  eta: string; lat: number; lng: number;
}
export interface SolveSequence { stops: SolveStop[]; total_km: number; total_min: number; }
export interface Infeasible { order_id: string; reason: string; }
export interface SolveResult {
  manual: SolveSequence; optimized: SolveSequence;
  savings_km_pct: number; savings_time_pct: number;
  infeasible: Infeasible | null;
}
