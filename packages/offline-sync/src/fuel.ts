import type { SqliteAdapter, ClientOp } from './types.js';
import { queueOp } from './outbox.js';

export type FuelHintLevel = 'ok' | 'high' | 'low' | 'unknown';
export interface FuelHint { level: FuelHintLevel; l_per_100km: number | null; ratio: number | null; }

export interface LocalVehicle {
  id: string; plate: string; capacity_kg: number; baseline_l_per_100km: number | null;
}
export interface LocalFuelFill {
  id: string; vehicle_id: string; liters: number; amount_etb: number;
  odometer_km: number; station_name: string;
  variance_flag: string | null; variance_ratio: number | null;
  captured_at: string; synced_at: string | null;
}
export interface FuelContext {
  vehicle: LocalVehicle | null; last_fill: LocalFuelFill | null;
  recent_fills: LocalFuelFill[];
}

export async function getFuelContext(adapter: SqliteAdapter): Promise<FuelContext> {
  const vehicle = await adapter.get<LocalVehicle>(`SELECT * FROM vehicle LIMIT 1`);
  const recent = await adapter.all<LocalFuelFill>(
    `SELECT id, vehicle_id, liters, amount_etb, odometer_km, station_name,
            variance_flag, variance_ratio, captured_at, synced_at
     FROM fuel_log ORDER BY captured_at DESC LIMIT 10`,
  );
  return { vehicle: vehicle ?? null, last_fill: recent[0] ?? null, recent_fills: recent };
}

export function computeFuelHint(input: {
  liters: number; odometer_km: number;
  prev_odometer_km: number | null; baseline_l_per_100km: number | null;
}): FuelHint {
  if (!input.baseline_l_per_100km || input.baseline_l_per_100km <= 0) return { level: 'unknown', l_per_100km: null, ratio: null };
  if (input.prev_odometer_km === null) return { level: 'unknown', l_per_100km: null, ratio: null };
  const distance = input.odometer_km - input.prev_odometer_km;
  if (distance <= 0) return { level: 'unknown', l_per_100km: null, ratio: null };
  const l_per_100km = (input.liters / distance) * 100;
  const ratio = l_per_100km / input.baseline_l_per_100km;
  let level: FuelHintLevel = 'ok';
  if (ratio > 1.5) level = 'high';
  else if (ratio < 0.7) level = 'low';
  return { level, l_per_100km: Math.round(l_per_100km * 100) / 100, ratio: Math.round(ratio * 100) / 100 };
}

export interface ApplyFuelInput {
  vehicleId: string; driverId: string;
  liters: number; amountEtb: number; odometerKm: number;
  stationName: string; stationId: string | null; capturedAt: string;
  clientOpId?: string; logId?: string;
}
export interface ApplyFuelResult { clientOpId: string; logId: string; hint: FuelHint; }

export async function applyFuelLog(adapter: SqliteAdapter, input: ApplyFuelInput): Promise<ApplyFuelResult> {
  if (!Number.isFinite(input.liters) || input.liters <= 0) throw new Error('liters must be > 0');
  if (!Number.isFinite(input.amountEtb) || input.amountEtb <= 0) throw new Error('amount must be > 0');
  if (!Number.isFinite(input.odometerKm) || input.odometerKm <= 0) throw new Error('odometer must be > 0');
  if (!input.stationName || input.stationName.trim().length === 0) throw new Error('station name required');
  const last = await adapter.get<{ odometer_km: number }>(
    `SELECT odometer_km FROM fuel_log WHERE vehicle_id = ? ORDER BY odometer_km DESC LIMIT 1`, [input.vehicleId],
  );
  if (last && input.odometerKm <= last.odometer_km) {
    throw new Error(`odometer must be greater than last reading (${last.odometer_km})`);
  }
  const vehicle = await adapter.get<LocalVehicle>(`SELECT * FROM vehicle WHERE id = ?`, [input.vehicleId]);
  const hint = computeFuelHint({
    liters: input.liters, odometer_km: input.odometerKm,
    prev_odometer_km: last?.odometer_km ?? null,
    baseline_l_per_100km: vehicle?.baseline_l_per_100km ?? null,
  });
  const clientOpId = input.clientOpId ?? generateId('fuel-op');
  const logId = input.logId ?? generateId('fuel');
  const op: ClientOp = {
    client_op_id: clientOpId, op_type: 'driver.fuel_log', entity_id: logId,
    payload: {
      vehicle_id: input.vehicleId, liters: input.liters, amount_etb: input.amountEtb,
      odometer_km: input.odometerKm, station_name: input.stationName.trim(),
      station_id: input.stationId, captured_at: input.capturedAt,
    },
  };
  await adapter.transaction(async () => {
    await adapter.run(
      `INSERT INTO fuel_log
         (id, vehicle_id, driver_id, liters, amount_etb, odometer_km, station_name, station_id,
          variance_flag, variance_ratio, client_op_id, captured_at, synced_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
      [logId, input.vehicleId, input.driverId, input.liters, input.amountEtb, input.odometerKm,
       input.stationName.trim(), input.stationId,
       hint.level === 'unknown' ? 'NO_BASELINE' : hint.level.toUpperCase(),
       hint.ratio, clientOpId, input.capturedAt],
    );
    await queueOp(adapter, op);
  });
  return { clientOpId, logId, hint };
}
function generateId(prefix: string): string {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}
