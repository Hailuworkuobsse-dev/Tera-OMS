export type Locale = 'am' | 'en' | 'om';
export type TranslateFn = (key: string, vars?: Record<string, string | number>) => string;
