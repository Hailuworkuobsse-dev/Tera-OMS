import { api } from '../../../../api/client';
import type { ExposureResponse } from '@tera/contracts';
export const exposureKeys = { all: ['credit-exposure'] as const, data: () => [...exposureKeys.all, 'data'] as const };
export const fetchExposure = (signal?: AbortSignal) => api<ExposureResponse>({ path: '/credit/v1/exposure', signal });
