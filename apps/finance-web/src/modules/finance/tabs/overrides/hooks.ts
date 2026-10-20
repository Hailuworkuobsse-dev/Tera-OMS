import { useQuery } from '@tanstack/react-query';
import { overridesKeys, fetchOverrides } from './api';
export const useOverrides = () => useQuery({ queryKey: overridesKeys.list(), queryFn: ({ signal }) => fetchOverrides(signal) });
