export interface CartLine { skuId: string; quantity: number; unitPrice: number; weightKg: number; volumeM3: number; }
export function computeCartTotals(lines: CartLine[]) {
  let q = 0, s = 0, w = 0, v = 0;
  for (const l of lines) { q += l.quantity; s += l.quantity * l.unitPrice; w += l.quantity * l.weightKg; v += l.quantity * l.volumeM3; }
  return { lineCount: lines.length, totalQuantity: q, subtotalEtb: Math.round(s * 100) / 100, totalWeightKg: Math.round(w * 100) / 100, totalVolumeM3: Math.round(v * 1000) / 1000 };
}
export function computeHeadroom(input: { limitEtb: number; exposureEtb: number; cartSubtotalEtb: number }) {
  const headroom = Math.max(0, input.limitEtb - input.exposureEtb);
  const after = headroom - input.cartSubtotalEtb;
  return { headroomEtb: Math.round(headroom * 100) / 100, afterOrderEtb: Math.round(after * 100) / 100, wouldExceed: after < 0 };
}
