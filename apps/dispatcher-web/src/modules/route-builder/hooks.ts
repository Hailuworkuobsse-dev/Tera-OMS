import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { routeBuilderKeys, fetchPendingOrders, fetchVehicles, solveRoutes, submitAsyncSolve, getAsyncSolveJob, acceptRoute } from './api';
import type { AcceptRouteRequest } from './types';

export function usePendingOrders() {
  return useQuery({ queryKey: routeBuilderKeys.pending(), queryFn: ({ signal }) => fetchPendingOrders(signal) });
}
export function useVehicles() {
  return useQuery({ queryKey: routeBuilderKeys.vehicles(), queryFn: ({ signal }) => fetchVehicles(signal) });
}
export function useSolveRoutesSync() {
  return useMutation({ mutationFn: (input: { order_ids: string[]; vehicle_id: string }) => solveRoutes(input) });
}
export function useSubmitAsyncSolve() {
  return useMutation({ mutationFn: (input: { order_ids: string[]; vehicle_id: string }) => submitAsyncSolve(input) });
}
export function useAsyncSolveJob(jobId: string | null) {
  return useQuery({
    queryKey: jobId ? routeBuilderKeys.solveJob(jobId) : ['solve-job', 'none'],
    queryFn: ({ signal }) => getAsyncSolveJob(jobId!, signal),
    enabled: jobId !== null,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      if (status === 'DONE' || status === 'FAILED' || status === 'TIMEOUT') return false;
      return 500;
    },
  });
}
export function useAcceptRoute() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: AcceptRouteRequest) => acceptRoute(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: routeBuilderKeys.all }),
  });
}
