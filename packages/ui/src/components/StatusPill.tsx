import type { ReactNode } from 'react';
type Tone = 'danger' | 'warn' | 'success' | 'neutral';
const tone: Record<Tone, string> = {
  danger: 'bg-dangerBg text-danger border-danger/30',
  warn: 'bg-warnBg text-warn border-warn/30',
  success: 'bg-successBg text-success border-success/30',
  neutral: 'bg-bg text-muted border-border',
};
export function StatusPill({ tone: t, children }: { tone: Tone; children: ReactNode }) {
  return <span className={`inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full border ${tone[t]}`}>{children}</span>;
}
