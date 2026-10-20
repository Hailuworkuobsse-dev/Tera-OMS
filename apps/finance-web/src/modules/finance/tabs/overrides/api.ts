import { api } from '../../../../api/client';
import type { OverridesListResponse } from '@tera/contracts';
export const overridesKeys = { all: ['overrides'] as const, list: () => [...overridesKeys.all, 'list'] as const };
export const fetchOverrides = (signal?: AbortSignal) => api<OverridesListResponse>({ path: '/credit/v1/overrides/list', signal });
