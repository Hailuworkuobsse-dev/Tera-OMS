import { api } from '../../api/client';
import type { PortalProfile, CatalogItem, PlaceOrderRequest, PlaceOrderResponse, PortalOrdersResponse, StatementResponse, DisputeRow, RaiseDisputeRequest } from './types';
export const portalKeys = {
  all: ['portal'] as const, me: () => [...portalKeys.all, 'me'] as const, catalog: () => [...portalKeys.all, 'catalog'] as const,
  orders: () => [...portalKeys.all, 'orders'] as const, statements: () => [...portalKeys.all, 'statements'] as const, disputes: () => [...portalKeys.all, 'disputes'] as const,
};
export const fetchMe = (signal?: AbortSignal) => api<PortalProfile>({ path: '/portal/v1/me', signal });
export const fetchCatalog = (signal?: AbortSignal) => api<{ items: CatalogItem[] }>({ path: '/portal/v1/catalog', signal });
export const placeOrder = (body: PlaceOrderRequest) => api<PlaceOrderResponse>({ method: 'POST', path: '/portal/v1/orders', body });
export const fetchOrders = (signal?: AbortSignal) => api<PortalOrdersResponse>({ path: '/portal/v1/orders', signal });
export const fetchStatements = (signal?: AbortSignal) => api<StatementResponse>({ path: '/portal/v1/statements', signal });
export const raiseDispute = (body: RaiseDisputeRequest) => api<{ disputes: DisputeRow[] }>({ method: 'POST', path: '/portal/v1/disputes', body });
export const fetchDisputes = (signal?: AbortSignal) => api<{ disputes: DisputeRow[] }>({ path: '/portal/v1/disputes', signal });
