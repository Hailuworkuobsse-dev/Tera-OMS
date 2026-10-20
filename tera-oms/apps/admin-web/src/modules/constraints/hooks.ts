import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { geoKeys, fetchCurfews, createCurfew, updateCurfewHours, toggleCurfewActive, fetchStations, createStation, setStationStatus, toggleStationActive } from './api';
import type { CreateCurfewZone, UpdateCurfewHours, CreateFuelStation, FuelStationStatus } from './types';
export const useCurfews = () => useQuery({ queryKey: geoKeys.curfews(), queryFn: ({ signal }) => fetchCurfews(signal) });
export function useCreateCurfew() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateCurfewZone) => createCurfew(b), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.curfews() }) }); }
export function useUpdateCurfewHours() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, body }: { id: string; body: UpdateCurfewHours }) => updateCurfewHours(id, body), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.curfews() }) }); }
export function useToggleCurfewActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => toggleCurfewActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.curfews() }) }); }
export const useStations = () => useQuery({ queryKey: geoKeys.stations(), queryFn: ({ signal }) => fetchStations(signal) });
export function useCreateStation() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateFuelStation) => createStation(b), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.stations() }) }); }
export function useSetStationStatus() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, status }: { id: string; status: FuelStationStatus }) => setStationStatus(id, status), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.stations() }) }); }
export function useToggleStationActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => toggleStationActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.stations() }) }); }
