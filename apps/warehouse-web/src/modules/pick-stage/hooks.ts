import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { pickKeys, fetchPickList, markPicked, confirmLoading } from './api';
import { dockKeys } from '../dock-queue/api';
export function usePickList(routeId: string | null) {
  return useQuery({ queryKey: pickKeys.list(routeId ?? ''), queryFn: ({ signal }) => fetchPickList(routeId!, signal), enabled: routeId !== null });
}
export function useMarkPicked(routeId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (stopId: string) => markPicked(routeId, stopId),
    onSuccess: () => { void qc.invalidateQueries({ queryKey: pickKeys.all }); void qc.invalidateQueries({ queryKey: dockKeys.all }); },
  });
}
export function useConfirmLoading() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (slotId: string) => confirmLoading(slotId),
    onSuccess: () => { void qc.invalidateQueries({ queryKey: pickKeys.all }); void qc.invalidateQueries({ queryKey: dockKeys.all }); },
  });
}
