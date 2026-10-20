import { useQuery } from '@tanstack/react-query';
import { monitoringKeys, fetchSnapshot } from './api';
export const useSnapshot = () => useQuery({ queryKey: monitoringKeys.snapshot(), queryFn: ({ signal }) => fetchSnapshot(signal), refetchInterval: 10_000 });
