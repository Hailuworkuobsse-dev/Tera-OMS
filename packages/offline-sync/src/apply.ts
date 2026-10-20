import type { SqliteAdapter, SyncChange } from './types.js';

export async function applyChange(adapter: SqliteAdapter, change: SyncChange): Promise<void> {
  if (change.entity_type === 'route_plan') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM route_plan WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO route_plan(id, driver_id, vehicle_id, status, planned_km, planned_min, start_lat, start_lng, updated_at)
       VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET status = excluded.status, updated_at = excluded.updated_at`,
      [change.entity_id, p.driver_id, p.vehicle_id, p.status, p.planned_km, p.planned_min, p.start_lat, p.start_lng, change.created_at],
    );
    return;
  }
  if (change.entity_type === 'route_stop') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM route_stop WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO route_stop(id, route_plan_id, seq, distributor_id, distributor_name, lat, lng, planned_eta, status, status_updated_at, quantity_ordered)
       VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET status = excluded.status, status_updated_at = excluded.status_updated_at`,
      [change.entity_id, p.route_plan_id, p.seq, p.distributor_id, p.distributor_name, p.lat, p.lng, p.planned_eta, p.status, p.status_updated_at, p.quantity_ordered ?? 0],
    );
    return;
  }
  if (change.entity_type === 'vehicle') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM vehicle WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO vehicle(id, plate, capacity_kg, baseline_l_per_100km)
       VALUES(?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET plate = excluded.plate, baseline_l_per_100km = excluded.baseline_l_per_100km`,
      [change.entity_id, p.plate, p.capacity_kg, p.baseline_l_per_100km ?? null],
    );
    return;
  }
  if (change.entity_type === 'fuel_log') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM fuel_log WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO fuel_log(id, vehicle_id, driver_id, liters, amount_etb, odometer_km, station_name, station_id, variance_flag, variance_ratio, client_op_id, captured_at, synced_at)
       VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?) ON CONFLICT(id) DO NOTHING`,
      [change.entity_id, p.vehicle_id, p.driver_id, p.liters, p.amount_etb, p.odometer_km,
       p.station_name, p.station_id ?? null, p.variance_flag ?? 'NO_BASELINE',
       p.variance_ratio ?? null, p.captured_at, new Date().toISOString()],
    );
  }
}
