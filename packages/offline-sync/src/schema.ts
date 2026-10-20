import type { SqliteAdapter } from './types.js';

export async function createSchema(adapter: SqliteAdapter): Promise<void> {
  await adapter.run(`CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS outbox (
      client_op_id TEXT PRIMARY KEY, op_type TEXT NOT NULL, entity_id TEXT NOT NULL,
      payload_json TEXT NOT NULL, queued_at TEXT NOT NULL, synced_at TEXT, result_json TEXT
    )
  `);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_outbox_unsynced ON outbox(synced_at)`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS route_plan (
      id TEXT PRIMARY KEY, driver_id TEXT NOT NULL, vehicle_id TEXT NOT NULL,
      status TEXT NOT NULL, planned_km REAL NOT NULL, planned_min INTEGER NOT NULL,
      start_lat REAL NOT NULL, start_lng REAL NOT NULL, updated_at TEXT NOT NULL
    )
  `);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS route_stop (
      id TEXT PRIMARY KEY, route_plan_id TEXT NOT NULL, seq INTEGER NOT NULL,
      distributor_id TEXT NOT NULL, distributor_name TEXT NOT NULL,
      lat REAL NOT NULL, lng REAL NOT NULL, planned_eta TEXT NOT NULL,
      status TEXT NOT NULL, status_updated_at TEXT NOT NULL,
      quantity_ordered INTEGER NOT NULL DEFAULT 0
    )
  `);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_route_stop_plan ON route_stop(route_plan_id, seq)`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS proof_of_delivery (
      id TEXT PRIMARY KEY, stop_id TEXT NOT NULL, outcome TEXT NOT NULL,
      qty_confirmed INTEGER, qty_ordered INTEGER, reason TEXT,
      signature_base64 TEXT, photo_base64 TEXT,
      captured_at TEXT NOT NULL, client_op_id TEXT NOT NULL, synced_at TEXT
    )
  `);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS payment (
      id TEXT PRIMARY KEY, stop_id TEXT NOT NULL, method TEXT NOT NULL,
      amount_etb REAL NOT NULL, telebirr_ref TEXT,
      client_op_id TEXT NOT NULL, captured_at TEXT NOT NULL
    )
  `);
  await adapter.run(`CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_telebirr_unique
                     ON payment(telebirr_ref) WHERE telebirr_ref IS NOT NULL`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS vehicle (
      id TEXT PRIMARY KEY, plate TEXT NOT NULL, capacity_kg REAL NOT NULL,
      baseline_l_per_100km REAL
    )
  `);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS fuel_log (
      id TEXT PRIMARY KEY, vehicle_id TEXT NOT NULL, driver_id TEXT NOT NULL,
      liters REAL NOT NULL, amount_etb REAL NOT NULL, odometer_km REAL NOT NULL,
      station_name TEXT NOT NULL, station_id TEXT,
      variance_flag TEXT, variance_ratio REAL,
      client_op_id TEXT, captured_at TEXT NOT NULL, synced_at TEXT
    )
  `);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_fuel_log_vehicle ON fuel_log(vehicle_id, odometer_km DESC)`);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_fuel_log_captured ON fuel_log(captured_at DESC)`);
}
