export function Sparkline({ data, color, width = 120, height = 28 }: { data: number[]; color: string; width?: number; height?: number }) {
  if (data.length < 2) return <div style={{ width, height }} className="bg-bg rounded" />;
  const min = Math.min(...data); const max = Math.max(...data); const range = max - min || 1; const pad = 2;
  const points = data.map((v, i) => `${((i / (data.length - 1)) * width).toFixed(1)},${(height - pad - ((v - min) / range) * (height - 2 * pad)).toFixed(1)}`).join(' ');
  return <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} role="img"><polyline points={points} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" /></svg>;
}
