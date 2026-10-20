import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { mdKeys, fetchDistributors, fetchVehicles, fetchSkus, createDistributor, createVehicle, createSku, setDistributorActive, setVehicleActive, setSkuActive, validateImport, commitImport } from './api';
import type { CreateDistributor, CreateVehicle, CreateSku, MasterdataEntityType } from './types';
export const useDistributors = () => useQuery({ queryKey: mdKeys.distributors(), queryFn: ({ signal }) => fetchDistributors(signal) });
export const useVehicles = () => useQuery({ queryKey: mdKeys.vehicles(), queryFn: ({ signal }) => fetchVehicles(signal) });
export const useSkus = () => useQuery({ queryKey: mdKeys.skus(), queryFn: ({ signal }) => fetchSkus(signal) });
export function useCreateDistributor() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateDistributor) => createDistributor(b), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.distributors() }) }); }
export function useCreateVehicle() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateVehicle) => createVehicle(b), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.vehicles() }) }); }
export function useCreateSku() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateSku) => createSku(b), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.skus() }) }); }
export function useToggleDistributorActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => setDistributorActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.distributors() }) }); }
export function useToggleVehicleActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => setVehicleActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.vehicles() }) }); }
export function useToggleSkuActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => setSkuActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.skus() }) }); }
export function useValidateImport() { return useMutation({ mutationFn: ({ type, rows }: { type: MasterdataEntityType; rows: Record<string, string>[] }) => validateImport(type, rows) }); }
export function useCommitImport() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ type, rows }: { type: MasterdataEntityType; rows: Record<string, string>[] }) => commitImport(type, rows), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.all }) }); }
