import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { dockKeys, fetchBoard, confirmLoading } from './api';
export function useBoard() { return useQuery({ queryKey: dockKeys.board(), queryFn: ({ signal }) => fetchBoard(signal), refetchInterval: 10_000 }); }
export function useConfirmLoading() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (slotId: string) => confirmLoading(slotId), onSuccess: () => qc.invalidateQueries({ queryKey: dockKeys.all }) });
}
