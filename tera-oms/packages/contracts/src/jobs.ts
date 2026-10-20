import { z } from 'zod';

export const JobKeyEnum = z.enum(['metric_snapshot', 'fuel_variance', 'credit_rebuild']);
export const JobStatusEnum = z.enum(['RUNNING', 'DONE', 'FAILED', 'SKIPPED']);

export const JobRunSchema = z.object({
  id: z.string(), job_key: JobKeyEnum, status: JobStatusEnum,
  started_at: z.string().datetime(), finished_at: z.string().datetime().nullable(),
  duration_ms: z.number().int().nullable(),
  processed_count: z.number().int(), skipped_count: z.number().int(),
  triggered_by: z.string(), error: z.string().nullable(),
});
export const JobRunsResponseSchema = z.object({
  total: z.number().int(), runs: z.array(JobRunSchema),
});
export const JobScheduleEntrySchema = z.object({
  job_key: JobKeyEnum, label_key: z.string(), schedule: z.string(),
  next_run_at: z.string().datetime().nullable(),
  last_run: JobRunSchema.nullable(),
});
export const JobScheduleResponseSchema = z.object({ jobs: z.array(JobScheduleEntrySchema) });
export const RunJobResponseSchema = z.object({
  job_key: JobKeyEnum, enqueued: z.literal(true),
});

export type JobKey = z.infer<typeof JobKeyEnum>;
export type JobStatus = z.infer<typeof JobStatusEnum>;
export type JobRun = z.infer<typeof JobRunSchema>;
export type JobRunsResponse = z.infer<typeof JobRunsResponseSchema>;
export type JobScheduleEntry = z.infer<typeof JobScheduleEntrySchema>;
export type JobScheduleResponse = z.infer<typeof JobScheduleResponseSchema>;
