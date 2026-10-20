import type { MasterdataEntityType } from '../types';
export function parseCsv(text: string): Record<string, string>[] {
  const clean = text.replace(/^\uFEFF/, '');
  const raw = parseRawCsv(clean);
  if (raw.length === 0) return [];
  const headers = raw[0]!.map((h) => h.trim().toLowerCase());
  const rows: Record<string, string>[] = [];
  for (let i = 1; i < raw.length; i++) {
    const cells = raw[i]!;
    if (cells.every((c) => c.trim() === '')) continue;
    const obj: Record<string, string> = {};
    for (let j = 0; j < headers.length; j++) obj[headers[j]!] = (cells[j] ?? '').trim();
    rows.push(obj);
  }
  return rows;
}
function parseRawCsv(text: string): string[][] {
  const rows: string[][] = []; let row: string[] = []; let field = ''; let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i]!;
    if (inQuotes) { if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else inQuotes = false; } else field += c; }
    else { if (c === '"') inQuotes = true; else if (c === ',') { row.push(field); field = ''; } else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; } else if (c === '\r') {} else field += c; }
  }
  if (field !== '' || row.length > 0) { row.push(field); rows.push(row); }
  return rows;
}
const TEMPLATES: Record<MasterdataEntityType, { headers: string[]; example: string[] }> = {
  distributor: { headers: ['name', 'region'], example: ['Acme Trading Co.', 'Addis Ababa'] },
  vehicle: { headers: ['plate', 'capacity_kg', 'capacity_m3', 'shift_start_h', 'shift_end_h', 'start_lat', 'start_lng', 'baseline_l_per_100km'], example: ['AA-3-B-201', '1500', '8', '7', '18', '9.0108', '38.7613', '12'] },
  sku: { headers: ['code', 'name', 'unit', 'weight_kg', 'volume_m3', 'reorder_point', 'safety_stock', 'lead_time_days'], example: ['SKU-EXAMPLE', 'Example Product', 'each', '0.5', '0.001', '20', '10', '3'] },
};
export function downloadTemplate(type: MasterdataEntityType): void {
  const t = TEMPLATES[type];
  const csv = `${t.headers.join(',')}\n${t.example.map((c) => (c.includes(',') ? `"${c}"` : c)).join(',')}\n`;
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = `${type}-template.csv`; document.body.appendChild(a); a.click(); document.body.removeChild(a); URL.revokeObjectURL(url);
}
