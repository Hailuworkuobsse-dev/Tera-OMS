import { z } from 'zod';

const Env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z.string().default('info'),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(16),
  JWT_TTL_MIN: z.coerce.number().default(60),
  TELEBIRR_BASE_URL: z.string().url().optional(),
  TELEBIRR_APP_KEY: z.string().optional(),
  SMS_PRIMARY_URL: z.string().optional(),
  SMS_PRIMARY_KEY: z.string().optional(),
});

export const config = Env.parse(process.env);
