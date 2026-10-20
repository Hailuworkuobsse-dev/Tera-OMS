export type { PickListResponse, PickListStop, MarkPickedResponse } from '@tera/contracts';
export interface PickableRoute {
  route_id: string; vehicle_id: string; driver_id: string;
  stop_count: number; picked_count: number;
  slot_id: string; slot_status: 'ALLOCATED' | 'CONFIRMED';
  start_at: string; end_at: string;
}
