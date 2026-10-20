import { api } from '../../api/client';
import type { CurfewZone, CreateCurfewZone, UpdateCurfewHours, FuelStation, FuelStationStatus, CreateFuelStation } from './types';
export const geoKeys = { all: ['constraints'] as const, curfews: () => [...geoKeys.all, 'curfews'] as const, stations: () => [...geoKeys.all, 'stations'] as const };
export function fetchCurfews(signal?: AbortSignal) { return api<{ zones: CurfewZone[] }>({ path: '/geo/v1/curfew-zones?includeInactive=1', signal }); }
export function createCurfew(body: CreateCurfewZone) { return api<CurfewZone>({ method: 'POST', path: '/geo/v1/curfew-zones', body }); }
export function updateCurfewHours(id: string, body: UpdateCurfewHours) { return api<CurfewZone>({ method: 'PATCH', path: `/geo/v1/curfew-zones/${id}/hours`, body }); }
export function toggleCurfewActive(id: string, active: boolean) { return api<CurfewZone>({ method: 'PATCH', path: `/geo/v1/curfew-zones/${id}`, body: { active } }); }
export function fetchStations(signal?: AbortSignal) { return api<{ stations: FuelStation[] }>({ path: '/geo/v1/fuel-stations?includeInactive=1', signal }); }
export function createStation(body: CreateFuelStation) { return api<FuelStation>({ method: 'POST', path: '/geo/v1/fuel-stations', body }); }
export function setStationStatus(id: string, status: FuelStationStatus) { return api<FuelStation>({ method: 'PATCH', path: `/geo/v1/fuel-stations/${id}/status`, body: { status } }); }
export function toggleStationActive(id: string, active: boolean) { return api<FuelStation>({ method: 'PATCH', path: `/geo/v1/fuel-stations/${id}`, body: { active } }); }
