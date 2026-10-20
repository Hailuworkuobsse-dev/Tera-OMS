import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { dashKeys, fetchDashboard, freezeBaseline, fetchAssumptions, updateAssumption } from './api';
export const useDashboard = () => useQuery({ queryKey: dashKeys.dashboard(), queryFn: ({ signal }) => fetchDashboard(signal) });
export function useFreezeBaseline() { const qc = useQueryClient(); return useMutation({ mutationFn: (n?: string) => freezeBaseline(n), onSuccess: () => qc.invalidateQueries({ queryKey: dashKeys.all }) }); }
export const useAssumptions = () => useQuery({ queryKey: dashKeys.assumptions(), queryFn: ({ signal }) => fetchAssumptions(signal) });
export function useUpdateAssumption() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ key, value }: { key: string; value: number }) => updateAssumption(key, value), onSuccess: () => { void qc.invalidateQueries({ queryKey: dashKeys.assumptions() }); void qc.invalidateQueries({ queryKey: dashKeys.dashboard() }); } }); }
