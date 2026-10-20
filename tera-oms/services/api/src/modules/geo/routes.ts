import type { FastifyPluginAsync } from 'fastify';
import {
  CurfewZonesResponseSchema, CurfewZoneSchema, CreateCurfewZoneSchema, UpdateCurfewHoursSchema,
  FuelStationsResponseSchema, FuelStationSchema, CreateFuelStationSchema, UpdateStationStatusSchema, ToggleActiveSchema,
} from './schemas.js';
import * as service from './service.js';

export const geoRoutes: FastifyPluginAsync = async (app) => {
  app.get('/curfew-zones', {
    schema: { response: { 200: CurfewZonesResponseSchema as any } },
  }, async (req: any) => service.getCurfewZones({ includeInactive: req.query?.includeInactive === '1' }));

  app.post('/curfew-zones', {
    schema: { body: CreateCurfewZoneSchema as any, response: { 200: CurfewZoneSchema as any } },
  }, async (req: any) => service.createCurfewZone(req.body));

  app.patch('/curfew-zones/:id/hours', {
    schema: { body: UpdateCurfewHoursSchema as any, response: { 200: CurfewZoneSchema as any } },
  }, async (req: any) => service.updateCurfewHours(req.params.id, req.body));

  app.patch('/curfew-zones/:id', {
    schema: { body: ToggleActiveSchema as any, response: { 200: CurfewZoneSchema as any } },
  }, async (req: any) => service.toggleCurfewActive(req.params.id, req.body.active));

  app.get('/fuel-stations', {
    schema: { response: { 200: FuelStationsResponseSchema as any } },
  }, async (req: any) => service.getFuelStations({ includeInactive: req.query?.includeInactive === '1' }));

  app.post('/fuel-stations', {
    schema: { body: CreateFuelStationSchema as any, response: { 200: FuelStationSchema as any } },
  }, async (req: any) => service.createFuelStation(req.body));

  app.patch('/fuel-stations/:id/status', {
    schema: { body: UpdateStationStatusSchema as any, response: { 200: FuelStationSchema as any } },
  }, async (req: any) => {
    const actorId = req.user?.sub ?? 'admin';
    return service.updateStationStatus(req.params.id, req.body.status, actorId);
  });

  app.patch('/fuel-stations/:id', {
    schema: { body: ToggleActiveSchema as any, response: { 200: FuelStationSchema as any } },
  }, async (req: any) => service.toggleStationActive(req.params.id, req.body.active));
};
