import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { reconciliationKeys, fetchUnreconciled, reconcilePayment } from './api';
export const useUnreconciled = () => useQuery({ queryKey: reconciliationKeys.list(), queryFn: ({ signal }) => fetchUnreconciled(signal) });
export function useReconcile() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, notes }: { id: string; notes?: string }) => reconcilePayment(id, notes), onSuccess: () => qc.invalidateQueries({ queryKey: reconciliationKeys.all }) }); }
