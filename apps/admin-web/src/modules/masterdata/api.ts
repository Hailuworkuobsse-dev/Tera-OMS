import { api } from '../../api/client';
import type { Distributor, Vehicle, Sku, CreateDistributor, CreateVehicle, CreateSku, MasterdataEntityType, ValidateImportResponse, CommitImportResponse } from './types';
export const mdKeys = { all: ['masterdata'] as const, distributors: () => [...mdKeys.all, 'distributors'] as const, vehicles: () => [...mdKeys.all, 'vehicles'] as const, skus: () => [...mdKeys.all, 'skus'] as const };
export function fetchDistributors(signal?: AbortSignal) { return api<{ distributors: Distributor[] }>({ path: '/masterdata/v1/distributors', signal }); }
export function createDistributor(body: CreateDistributor) { return api<Distributor>({ method: 'POST', path: '/masterdata/v1/distributors', body }); }
export function setDistributorActive(id: string, active: boolean) { return api<Distributor>({ method: 'PATCH', path: `/masterdata/v1/distributors/${id}`, body: { active } }); }
export function fetchVehicles(signal?: AbortSignal) { return api<{ vehicles: Vehicle[] }>({ path: '/masterdata/v1/vehicles', signal }); }
export function createVehicle(body: CreateVehicle) { return api<Vehicle>({ method: 'POST', path: '/masterdata/v1/vehicles', body }); }
export function setVehicleActive(id: string, active: boolean) { return api<Vehicle>({ method: 'PATCH', path: `/masterdata/v1/vehicles/${id}`, body: { active } }); }
export function fetchSkus(signal?: AbortSignal) { return api<{ skus: Sku[] }>({ path: '/masterdata/v1/skus', signal }); }
export function createSku(body: CreateSku) { return api<Sku>({ method: 'POST', path: '/masterdata/v1/skus', body }); }
export function setSkuActive(id: string, active: boolean) { return api<Sku>({ method: 'PATCH', path: `/masterdata/v1/skus/${id}`, body: { active } }); }
export function validateImport(type: MasterdataEntityType, rows: Record<string, string>[]) { return api<ValidateImportResponse>({ method: 'POST', path: '/masterdata/v1/import/validate', body: { type, rows } }); }
export function commitImport(type: MasterdataEntityType, rows: Record<string, string>[]) { return api<CommitImportResponse>({ method: 'POST', path: '/masterdata/v1/import/commit', body: { type, rows } }); }
