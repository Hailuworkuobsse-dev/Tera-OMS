import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { portalKeys, fetchMe, fetchCatalog, placeOrder, fetchOrders, fetchStatements, raiseDispute, fetchDisputes } from './api';
import type { PlaceOrderRequest, RaiseDisputeRequest } from './types';
export const useMe = () => useQuery({ queryKey: portalKeys.me(), queryFn: ({ signal }) => fetchMe(signal) });
export const useCatalog = () => useQuery({ queryKey: portalKeys.catalog(), queryFn: ({ signal }) => fetchCatalog(signal) });
export function usePlaceOrder() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: PlaceOrderRequest) => placeOrder(b), onSuccess: () => { void qc.invalidateQueries({ queryKey: portalKeys.orders() }); void qc.invalidateQueries({ queryKey: portalKeys.me() }); void qc.invalidateQueries({ queryKey: portalKeys.statements() }); } }); }
export const useOrders = () => useQuery({ queryKey: portalKeys.orders(), queryFn: ({ signal }) => fetchOrders(signal), refetchInterval: 30_000 });
export const useStatements = () => useQuery({ queryKey: portalKeys.statements(), queryFn: ({ signal }) => fetchStatements(signal) });
export const useDisputes = () => useQuery({ queryKey: portalKeys.disputes(), queryFn: ({ signal }) => fetchDisputes(signal) });
export function useRaiseDispute() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: RaiseDisputeRequest) => raiseDispute(b), onSuccess: () => qc.invalidateQueries({ queryKey: portalKeys.disputes() }) }); }
