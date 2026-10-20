import { db } from '@tera/db';

export function findDistributors() { return db().distributor.findMany({ orderBy: [{ active: 'desc' }, { name: 'asc' }] }); }
export function createDistributor(d: { name: string; region: string }) { return db().distributor.create({ data: d }); }
export function findDistributorById(id: string) { return db().distributor.findUnique({ where: { id } }); }
export function updateDistributorActive(id: string, active: boolean) { return db().distributor.update({ where: { id }, data: { active } }); }
export function findDistributorNames() { return db().distributor.findMany({ select: { name: true } }); }

export function findVehicles() { return db().vehicle.findMany({ orderBy: [{ active: 'desc' }, { plate: 'asc' }] }); }
export function createVehicle(d: any) { return db().vehicle.create({ data: d }); }
export function findVehicleById(id: string) { return db().vehicle.findUnique({ where: { id } }); }
export function updateVehicleActive(id: string, active: boolean) { return db().vehicle.update({ where: { id }, data: { active } }); }
export function findVehiclePlates() { return db().vehicle.findMany({ select: { plate: true } }); }

export function findSkus() { return db().sku.findMany({ orderBy: [{ active: 'desc' }, { code: 'asc' }] }); }
export function createSku(d: any) { return db().sku.create({ data: d }); }
export function findSkuById(id: string) { return db().sku.findUnique({ where: { id } }); }
export function updateSkuActive(id: string, active: boolean) { return db().sku.update({ where: { id }, data: { active } }); }
export function findSkuCodes() { return db().sku.findMany({ select: { code: true } }); }
