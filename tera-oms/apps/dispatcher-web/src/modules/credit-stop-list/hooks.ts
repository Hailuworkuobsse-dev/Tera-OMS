import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { creditKeys, fetchCreditStopList, overrideCredit } from './api';
import type { OverrideRequest } from './types';

export function useCreditStopList() {
  return useQuery({
    queryKey: creditKeys.stopList(),
    queryFn: ({ signal }) => fetchCreditStopList(signal),
    refetchInterval: 60_000,
  });
}
export function useOverrideCredit() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: OverrideRequest) => overrideCredit(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: creditKeys.all }),
  });
}
