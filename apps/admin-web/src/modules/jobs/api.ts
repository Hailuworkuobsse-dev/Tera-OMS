import { api } from '../../api/client';
import type { JobRun, JobScheduleEntry, JobKey } from './types';
export const jobsKeys = { all: ['jobs'] as const, runs: () => [...jobsKeys.all, 'runs'] as const, schedule: () => [...jobsKeys.all, 'schedule'] as const };
export const fetchRuns = () => api<{ total: number; runs: JobRun[] }>({ path: '/admin/jobs/v1/runs?limit=50' });
export const fetchSchedule = () => api<{ jobs: JobScheduleEntry[] }>({ path: '/admin/jobs/v1/schedule' });
export const runJob = (key: JobKey) => api<{ job_key: JobKey; enqueued: true }>({ method: 'POST', path: `/admin/jobs/v1/${key}/run` });
