// OR-Tools-style model; swap library here only (ADR 0002).
export interface SolveRequest { orders: SolveOrder[]; vehicles: SolveVehicle[]; constraints: SolveConstraints; }
export interface SolveOrder { id: string; lat: number; lng: number; weightKg: number; volumeM3: number; timeWindow: [string, string]; priority: number; }
export interface SolveVehicle { id: string; capacityKg: number; capacityM3: number; shift: [string, string]; start: { lat: number; lng: number }; }
export interface SolveConstraints { curfewZones: { polygon: number[][]; startHour: number; endHour: number }[]; blockedRoads: string[]; slackPct: number; }
export interface SolveResult { routeId?: string; stops: { orderId: string; seq: number; eta: string }[]; totalKm: number; infeasible?: { orderId: string; reason: string }; }
