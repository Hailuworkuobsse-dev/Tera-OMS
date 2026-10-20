import { api } from '../../api/client';
import type {
  Order, Vehicle, SolveResponse, AcceptRouteRequest, AcceptRouteResponse,
  AsyncSolveSubmitResponse, AsyncSolveJobResponse,
} from './types';

export const routeBuilderKeys = {
  all: ['route-builder'] as const,
  pending: () => [...routeBuilderKeys.all, 'pending'] as const,
  vehicles: () => [...routeBuilderKeys.all, 'vehicles'] as const,
  solveJob: (id: string) => [...routeBuilderKeys.all, 'solve-job', id] as const,
};
export function fetchPendingOrders(signal?: AbortSignal) {
  return api<{ orders: Order[] }>({ path: '/orders/v1/pending', signal });
}
export function fetchVehicles(signal?: AbortSignal) {
  return api<{ vehicles: Vehicle[] }>({ path: '/routing/v1/vehicles', signal });
}
export function solveRoutes(body: { order_ids: string[]; vehicle_id: string }) {
  return api<SolveResponse>({ method: 'POST', path: '/routing/v1/solve', body });
}
export function submitAsyncSolve(body: { order_ids: string[]; vehicle_id: string }) {
  return api<AsyncSolveSubmitResponse>({ method: 'POST', path: '/routing/v1/solve/async', body });
}
export function getAsyncSolveJob(jobId: string, signal?: AbortSignal) {
  return api<AsyncSolveJobResponse>({ path: `/routing/v1/solve/jobs/${jobId}`, signal });
}
export function acceptRoute(body: AcceptRouteRequest) {
  return api<AcceptRouteResponse>({ method: 'POST', path: '/routing/v1/routes', body });
}
