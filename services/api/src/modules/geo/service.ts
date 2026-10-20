import type { CurfewZone, FuelStation, CreateCurfewZone, UpdateCurfewHours, CreateFuelStation, FuelStationStatus } from '@tera/contracts';
import * as repo from './repository.js';
import { validateGeoJsonPolygon, validateCurfewHours } from './validation.js';

export async function getCurfewZones(opts: { includeInactive?: boolean } = {}): Promise<{ zones: CurfewZone[] }> {
  const rows = opts.includeInactive ? await repo.findAllCurfewZones() : await repo.findActiveCurfewZones();
  return {
    zones: rows.map((z) => ({
      id: z.id, name: z.name, polygon: z.polygonJson as any,
      start_hour: z.startHour, end_hour: z.endHour,
      reason: z.reason, active: z.active,
    })),
  };
}

export async function createCurfewZone(input: CreateCurfewZone): Promise<CurfewZone> {
  const polygonErrors = validateGeoJsonPolygon(input.polygon);
  if (polygonErrors.length > 0) {
    const e = new Error(polygonErrors.join('; ')) as any; e.statusCode = 400; throw e;
  }
  const hourErrors = validateCurfewHours({ start_hour: input.start_hour, end_hour: input.end_hour });
  if (hourErrors.length > 0) {
    const e = new Error(hourErrors.join('; ')) as any; e.statusCode = 400; throw e;
  }
  const row = await repo.createCurfewZone({
    name: input.name.trim(),
    polygonJson: input.polygon as any,
    startHour: input.start_hour,
    endHour: input.end_hour,
    reason: input.reason.trim(),
  });
  return toCurfew(row);
}

export async function updateCurfewHours(id: string, input: UpdateCurfewHours): Promise<CurfewZone> {
  const existing = await repo.findCurfewZoneById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const hourErrors = validateCurfewHours({ start_hour: input.start_hour, end_hour: input.end_hour });
  if (hourErrors.length > 0) { const e = new Error(hourErrors.join('; ')) as any; e.statusCode = 400; throw e; }
  const row = await repo.updateCurfewHours(id, {
    startHour: input.start_hour, endHour: input.end_hour, reason: input.reason.trim(),
  });
  return toCurfew(row);
}

export async function toggleCurfewActive(id: string, active: boolean): Promise<CurfewZone> {
  const existing = await repo.findCurfewZoneById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  return toCurfew(await repo.updateCurfewActive(id, active));
}

function toCurfew(row: any): CurfewZone {
  return { id: row.id, name: row.name, polygon: row.polygonJson, start_hour: row.startHour, end_hour: row.endHour, reason: row.reason, active: row.active };
}

export async function getFuelStations(opts: { includeInactive?: boolean } = {}): Promise<{ stations: FuelStation[] }> {
  const rows = await repo.findFuelStations();
  const filtered = opts.includeInactive ? rows : rows.filter((r) => r.active);
  return {
    stations: filtered.map((s) => ({
      id: s.id, name: s.name,
      lat: Number(s.lat), lng: Number(s.lng),
      status: s.status as FuelStationStatus, active: s.active,
      updated_at: s.updatedAt.toISOString(),
    })),
  };
}

export async function createFuelStation(input: CreateFuelStation): Promise<FuelStation> {
  return toStation(await repo.createFuelStation({
    name: input.name.trim(), lat: input.lat, lng: input.lng, status: input.status,
  }));
}

export async function updateStationStatus(id: string, status: FuelStationStatus, actorId: string): Promise<FuelStation> {
  const existing = await repo.findFuelStationById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  return toStation(await repo.updateFuelStationStatus(id, status, actorId));
}

export async function toggleStationActive(id: string, active: boolean): Promise<FuelStation> {
  const existing = await repo.findFuelStationById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  return toStation(await repo.updateFuelStationActive(id, active));
}

function toStation(row: any): FuelStation {
  return {
    id: row.id, name: row.name,
    lat: Number(row.lat), lng: Number(row.lng),
    status: row.status as FuelStationStatus, active: row.active,
    updated_at: row.updatedAt.toISOString(),
  };
}
