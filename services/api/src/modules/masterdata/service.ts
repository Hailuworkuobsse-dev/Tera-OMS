import type {
  Distributor, Vehicle, Sku, CreateDistributor, CreateVehicle, CreateSku,
  MasterdataEntityType, ImportRowResult, ValidateImportResponse, CommitImportResponse,
} from '@tera/contracts';
import * as repo from './repository.js';
import { validateDistributorShape, validateVehicleShape, validateSkuShape, parseNumber, parseInt2 } from './validation.js';

export async function listDistributors(): Promise<{ distributors: Distributor[] }> {
  const rows = await repo.findDistributors();
  return { distributors: rows.map((r) => ({ id: r.id, name: r.name, region: r.region, active: r.active, created_at: r.createdAt.toISOString(), updated_at: r.updatedAt.toISOString() })) };
}
export async function createDistributor(input: CreateDistributor): Promise<Distributor> {
  const names = await repo.findDistributorNames();
  if (names.some((n) => n.name.toLowerCase() === input.name.toLowerCase())) {
    const e = new Error(`distributor "${input.name}" already exists`) as any; e.statusCode = 409; throw e;
  }
  const row = await repo.createDistributor({ name: input.name, region: input.region });
  return { id: row.id, name: row.name, region: row.region, active: row.active, created_at: row.createdAt.toISOString(), updated_at: row.updatedAt.toISOString() };
}
export async function toggleDistributorActive(id: string, active: boolean): Promise<Distributor> {
  const row = await repo.findDistributorById(id);
  if (!row) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const u = await repo.updateDistributorActive(id, active);
  return { id: u.id, name: u.name, region: u.region, active: u.active, created_at: u.createdAt.toISOString(), updated_at: u.updatedAt.toISOString() };
}

export async function listVehicles(): Promise<{ vehicles: Vehicle[] }> {
  const rows = await repo.findVehicles();
  return { vehicles: rows.map((v) => ({
    id: v.id, plate: v.plate, capacity_kg: Number(v.capacityKg), capacity_m3: Number(v.capacityM3),
    shift_start_h: v.shiftStartH, shift_end_h: v.shiftEndH,
    start_lat: Number(v.startLat), start_lng: Number(v.startLng),
    baseline_l_per_100km: v.baselineLPer100Km ? Number(v.baselineLPer100Km) : null,
    active: v.active, created_at: v.createdAt.toISOString(), updated_at: v.updatedAt.toISOString(),
  })) };
}
export async function createVehicle(input: CreateVehicle): Promise<Vehicle> {
  const plates = await repo.findVehiclePlates();
  if (plates.some((p) => p.plate.toLowerCase() === input.plate.toLowerCase())) {
    const e = new Error(`vehicle "${input.plate}" already exists`) as any; e.statusCode = 409; throw e;
  }
  const row = await repo.createVehicle({
    plate: input.plate.toUpperCase(), capacityKg: input.capacity_kg, capacityM3: input.capacity_m3,
    shiftStartH: input.shift_start_h, shiftEndH: input.shift_end_h,
    startLat: input.start_lat, startLng: input.start_lng,
    baselineLPer100Km: input.baseline_l_per_100km,
  });
  return { id: row.id, plate: row.plate, capacity_kg: Number(row.capacityKg), capacity_m3: Number(row.capacityM3),
    shift_start_h: row.shiftStartH, shift_end_h: row.shiftEndH, start_lat: Number(row.startLat), start_lng: Number(row.startLng),
    baseline_l_per_100km: row.baselineLPer100Km ? Number(row.baselineLPer100Km) : null,
    active: row.active, created_at: row.createdAt.toISOString(), updated_at: row.updatedAt.toISOString() };
}
export async function toggleVehicleActive(id: string, active: boolean): Promise<Vehicle> {
  const row = await repo.findVehicleById(id);
  if (!row) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const u = await repo.updateVehicleActive(id, active);
  return { id: u.id, plate: u.plate, capacity_kg: Number(u.capacityKg), capacity_m3: Number(u.capacityM3),
    shift_start_h: u.shiftStartH, shift_end_h: u.shiftEndH, start_lat: Number(u.startLat), start_lng: Number(u.startLng),
    baseline_l_per_100km: u.baselineLPer100Km ? Number(u.baselineLPer100Km) : null,
    active: u.active, created_at: u.createdAt.toISOString(), updated_at: u.updatedAt.toISOString() };
}

export async function listSkus(): Promise<{ skus: Sku[] }> {
  const rows = await repo.findSkus();
  return { skus: rows.map((s) => ({
    id: s.id, code: s.code, name: s.name, unit: s.unit,
    weight_kg: Number(s.weightKg), volume_m3: Number(s.volumeM3),
    reorder_point: s.reorderPoint, safety_stock: s.safetyStock, lead_time_days: s.leadTimeDays,
    active: s.active, created_at: s.createdAt.toISOString(), updated_at: s.updatedAt.toISOString(),
  })) };
}
export async function createSku(input: CreateSku): Promise<Sku> {
  const codes = await repo.findSkuCodes();
  if (codes.some((c) => c.code.toLowerCase() === input.code.toLowerCase())) {
    const e = new Error(`SKU "${input.code}" already exists`) as any; e.statusCode = 409; throw e;
  }
  const row = await repo.createSku({
    code: input.code.toUpperCase(), name: input.name, unit: input.unit,
    weightKg: input.weight_kg, volumeM3: input.volume_m3,
    reorderPoint: input.reorder_point, safetyStock: input.safety_stock, leadTimeDays: input.lead_time_days,
  });
  return { id: row.id, code: row.code, name: row.name, unit: row.unit,
    weight_kg: Number(row.weightKg), volume_m3: Number(row.volumeM3),
    reorder_point: row.reorderPoint, safety_stock: row.safetyStock, lead_time_days: row.leadTimeDays,
    active: row.active, created_at: row.createdAt.toISOString(), updated_at: row.updatedAt.toISOString() };
}
export async function toggleSkuActive(id: string, active: boolean): Promise<Sku> {
  const row = await repo.findSkuById(id);
  if (!row) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const u = await repo.updateSkuActive(id, active);
  return { id: u.id, code: u.code, name: u.name, unit: u.unit,
    weight_kg: Number(u.weightKg), volume_m3: Number(u.volumeM3),
    reorder_point: u.reorderPoint, safety_stock: u.safetyStock, lead_time_days: u.leadTimeDays,
    active: u.active, created_at: u.createdAt.toISOString(), updated_at: u.updatedAt.toISOString() };
}

export async function validateImport(type: MasterdataEntityType, rows: Record<string, string>[]): Promise<ValidateImportResponse> {
  const existingNames = type === 'distributor' ? new Set((await repo.findDistributorNames()).map((d) => d.name.toLowerCase())) : null;
  const existingPlates = type === 'vehicle' ? new Set((await repo.findVehiclePlates()).map((v) => v.plate.toLowerCase())) : null;
  const existingCodes = type === 'sku' ? new Set((await repo.findSkuCodes()).map((s) => s.code.toLowerCase())) : null;
  const seenInFile = new Set<string>();
  const result: ImportRowResult[] = [];
  let valid = 0; let invalid = 0;
  for (let i = 0; i < rows.length; i++) {
    const row_number = i + 2;
    const data = rows[i]!;
    const errors: string[] = [];
    if (type === 'distributor') {
      errors.push(...validateDistributorShape(data));
      const name = (data.name ?? '').trim();
      if (name) {
        const k = name.toLowerCase();
        if (existingNames!.has(k)) errors.push(`distributor "${name}" already exists`);
        else if (seenInFile.has(k)) errors.push(`duplicate "${name}" in file`);
        else seenInFile.add(k);
      }
    } else if (type === 'vehicle') {
      errors.push(...validateVehicleShape(data));
      const plate = (data.plate ?? '').trim();
      if (plate) {
        const k = plate.toLowerCase();
        if (existingPlates!.has(k)) errors.push(`vehicle "${plate}" already exists`);
        else if (seenInFile.has(k)) errors.push(`duplicate "${plate}" in file`);
        else seenInFile.add(k);
      }
    } else if (type === 'sku') {
      errors.push(...validateSkuShape(data));
      const code = (data.code ?? '').trim();
      if (code) {
        const k = code.toLowerCase();
        if (existingCodes!.has(k)) errors.push(`SKU "${code}" already exists`);
        else if (seenInFile.has(k)) errors.push(`duplicate "${code}" in file`);
        else seenInFile.add(k);
      }
    }
    result.push({ row_number, data, status: errors.length === 0 ? 'valid' : 'invalid', errors });
    if (errors.length === 0) valid++; else invalid++;
  }
  return { type, total_rows: rows.length, valid_rows: valid, invalid_rows: invalid, rows: result };
}

export async function commitImport(type: MasterdataEntityType, rows: Record<string, string>[]): Promise<CommitImportResponse> {
  const validation = await validateImport(type, rows);
  let inserted = 0; let skipped = 0; const errors: Array<{ row_number: number; error: string }> = [];
  for (const row of validation.rows) {
    if (row.status === 'invalid') { skipped++; continue; }
    try {
      if (type === 'distributor') {
        await repo.createDistributor({ name: row.data.name!.trim(), region: row.data.region!.trim() });
      } else if (type === 'vehicle') {
        await repo.createVehicle({
          plate: row.data.plate!.trim().toUpperCase(),
          capacityKg: parseNumber(row.data.capacity_kg)!, capacityM3: parseNumber(row.data.capacity_m3)!,
          shiftStartH: parseInt2(row.data.shift_start_h)!, shiftEndH: parseInt2(row.data.shift_end_h)!,
          startLat: parseNumber(row.data.start_lat)!, startLng: parseNumber(row.data.start_lng)!,
          baselineLPer100Km: row.data.baseline_l_per_100km?.trim() ? parseNumber(row.data.baseline_l_per_100km)! : null,
        });
      } else if (type === 'sku') {
        await repo.createSku({
          code: row.data.code!.trim().toUpperCase(), name: row.data.name!.trim(), unit: row.data.unit!.trim(),
          weightKg: parseNumber(row.data.weight_kg)!, volumeM3: parseNumber(row.data.volume_m3)!,
          reorderPoint: row.data.reorder_point?.trim() ? parseInt2(row.data.reorder_point)! : 0,
          safetyStock: row.data.safety_stock?.trim() ? parseInt2(row.data.safety_stock)! : 0,
          leadTimeDays: row.data.lead_time_days?.trim() ? parseInt2(row.data.lead_time_days)! : 0,
        });
      }
      inserted++;
    } catch (e) { skipped++; errors.push({ row_number: row.row_number, error: (e as Error).message }); }
  }
  return { inserted, skipped, errors };
}
