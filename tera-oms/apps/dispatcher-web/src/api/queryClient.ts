import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15_000,
      retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2),
    },
  },
});
