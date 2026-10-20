export interface Sample { labels: Record<string, string>; value: number; }
export interface Metric { name: string; help: string; type: 'counter' | 'gauge'; samples: Sample[]; }
export function renderPrometheus(metrics: Metric[]): string {
  const lines: string[] = []; const seen = new Set<string>();
  for (const m of metrics) {
    if (m.samples.length === 0) continue;
    if (!seen.has(m.name)) { lines.push(`# HELP ${m.name} ${m.help}`); lines.push(`# TYPE ${m.name} ${m.type}`); seen.add(m.name); }
    for (const s of m.samples) lines.push(`${m.name}${labels(s.labels)} ${num(s.value)}`);
  }
  return lines.join('\n') + '\n';
}
export interface HistSeries { labels: Record<string, string>; bounds: number[]; cumulative: number[]; total: number; sum: number; }
export function renderHistogram(name: string, help: string, series: HistSeries[]): string {
  const lines = [`# HELP ${name} ${help}`, `# TYPE ${name} histogram`];
  for (const s of series) {
    for (let i = 0; i < s.bounds.length; i++) lines.push(`${name}_bucket${labels({ ...s.labels, le: String(s.bounds[i]) })} ${s.cumulative[i]}`);
    lines.push(`${name}_bucket${labels({ ...s.labels, le: '+Inf' })} ${s.total}`);
    lines.push(`${name}_sum${labels(s.labels)} ${num(s.sum)}`);
    lines.push(`${name}_count${labels(s.labels)} ${s.total}`);
  }
  return lines.join('\n') + '\n';
}
function labels(l: Record<string, string>): string {
  const k = Object.keys(l); if (k.length === 0) return '';
  return `{${k.map((x) => `${x}="${l[x]!.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`).join(',')}}`;
}
function num(n: number): string { if (Number.isNaN(n)) return 'NaN'; if (!Number.isFinite(n)) return n > 0 ? '+Inf' : '-Inf'; return String(n); }
