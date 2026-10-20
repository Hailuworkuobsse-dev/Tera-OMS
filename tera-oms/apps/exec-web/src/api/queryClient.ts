import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2) } } });
