import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { dispatchKeys, fetchBoard, allocateAll, confirmSlot, dispatchRoute } from './api';

export function useBoard() {
  return useQuery({ queryKey: dispatchKeys.board(), queryFn: ({ signal }) => fetchBoard(signal), refetchInterval: 10_000 });
}
export function useAllocateAll() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: () => allocateAll(), onSuccess: () => qc.invalidateQueries({ queryKey: dispatchKeys.all }) });
}
export function useConfirmSlot() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (slotId: string) => confirmSlot(slotId), onSuccess: () => qc.invalidateQueries({ queryKey: dispatchKeys.all }) });
}
export function useDispatchRoute() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (routeId: string) => dispatchRoute(routeId), onSuccess: () => qc.invalidateQueries({ queryKey: dispatchKeys.all }) });
}
