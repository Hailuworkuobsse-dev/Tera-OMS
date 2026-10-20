export function canReconcile(input: { reconciledAt: string | null }) {
  if (input.reconciledAt !== null) return { allowed: false, reason: 'already reconciled' };
  return { allowed: true, reason: null };
}
