import { useQuery } from '@tanstack/react-query';
import { exposureKeys, fetchExposure } from './api';
export const useExposure = () => useQuery({ queryKey: exposureKeys.data(), queryFn: ({ signal }) => fetchExposure(signal) });
