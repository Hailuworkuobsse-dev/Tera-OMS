import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { jobsKeys, fetchRuns, fetchSchedule, runJob } from './api';
import type { JobKey } from './types';
export const useRuns = () => useQuery({ queryKey: jobsKeys.runs(), queryFn: () => fetchRuns(), refetchInterval: 15_000 });
export const useSchedule = () => useQuery({ queryKey: jobsKeys.schedule(), queryFn: () => fetchSchedule(), refetchInterval: 30_000 });
export function useRunJob() { const qc = useQueryClient(); return useMutation({ mutationFn: (k: JobKey) => runJob(k), onSuccess: () => qc.invalidateQueries({ queryKey: jobsKeys.all }) }); }
