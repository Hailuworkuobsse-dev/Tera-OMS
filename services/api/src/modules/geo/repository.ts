import { db } from '@tera/db';

export function findActiveCurfewZones() {
  return db().curfewZone.findMany({ where: { active: true }, orderBy: { name: 'asc' } });
}
export function findAllCurfewZones() {
  return db().curfewZone.findMany({ orderBy: [{ active: 'desc' }, { name: 'asc' }] });
}
export function findCurfewZoneById(id: string) { return db().curfewZone.findUnique({ where: { id } }); }
export function createCurfewZone(data: { name: string; polygonJson: object; startHour: number; endHour: number; reason: string }) {
  return db().curfewZone.create({ data });
}
export function updateCurfewHours(id: string, data: { startHour: number; endHour: number; reason: string }) {
  return db().curfewZone.update({ where: { id }, data });
}
export function updateCurfewActive(id: string, active: boolean) {
  return db().curfewZone.update({ where: { id }, data: { active } });
}

export function findFuelStations() {
  return db().fuelStation.findMany({ orderBy: [{ active: 'desc' }, { name: 'asc' }] });
}
export function findFuelStationById(id: string) { return db().fuelStation.findUnique({ where: { id } }); }
export function createFuelStation(data: { name: string; lat: number; lng: number; status: string }) {
  return db().fuelStation.create({ data });
}
export function updateFuelStationStatus(id: string, status: string, actorId: string) {
  return db().fuelStation.update({ where: { id }, data: { status, statusUpdatedBy: actorId } });
}
export function updateFuelStationActive(id: string, active: boolean) {
  return db().fuelStation.update({ where: { id }, data: { active } });
}
