import type { Order } from '@tera/contracts';
import * as repo from './repository.js';

export async function getPendingOrders(): Promise<{ orders: Order[] }> {
  const rows = await repo.findPendingOrders();
  return {
    orders: rows.map((r) => ({
      id: r.id,
      distributor_id: r.distributorId,
      distributor_name: r.distributorName,
      lat: Number(r.lat), lng: Number(r.lng),
      weight_kg: Number(r.weightKg), volume_m3: Number(r.volumeM3),
      priority: r.priority,
      time_window_start: r.timeWindowStart.toISOString(),
      time_window_end: r.timeWindowEnd.toISOString(),
      status: r.status as Order['status'],
      created_at: r.createdAt.toISOString(),
    })),
  };
}
