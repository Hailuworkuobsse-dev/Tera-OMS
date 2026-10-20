export function parseNumber(v: string | undefined): number | null {
  if (v === undefined || v.trim() === '') return null;
  const n = Number(v.trim());
  return Number.isFinite(n) ? n : null;
}
export function parseInt2(v: string | undefined): number | null {
  const n = parseNumber(v);
  if (n === null || !Number.isInteger(n)) return null;
  return n;
}
export function validateDistributorShape(row: Record<string, string>): string[] {
  const errs: string[] = [];
  const name = (row.name ?? '').trim();
  const region = (row.region ?? '').trim();
  if (!name) errs.push('name is required');
  else if (name.length > 200) errs.push('name must be <= 200 chars');
  if (!region) errs.push('region is required');
  else if (region.length > 100) errs.push('region must be <= 100 chars');
  return errs;
}
export function validateVehicleShape(row: Record<string, string>): string[] {
  const errs: string[] = [];
  const plate = (row.plate ?? '').trim();
  if (!plate) errs.push('plate is required');
  else if (plate.length > 20) errs.push('plate must be <= 20 chars');
  const capKg = parseNumber(row.capacity_kg);
  if (capKg === null || capKg <= 0) errs.push('capacity_kg must be > 0');
  const capM3 = parseNumber(row.capacity_m3);
  if (capM3 === null || capM3 <= 0) errs.push('capacity_m3 must be > 0');
  const sh = parseInt2(row.shift_start_h);
  if (sh === null || sh < 0 || sh > 23) errs.push('shift_start_h must be 0-23');
  const eh = parseInt2(row.shift_end_h);
  if (eh === null || eh < 0 || eh > 23) errs.push('shift_end_h must be 0-23');
  if (sh !== null && eh !== null && eh <= sh) errs.push('shift_end_h must be > shift_start_h');
  const lat = parseNumber(row.start_lat);
  if (lat === null || lat < -90 || lat > 90) errs.push('start_lat must be -90 to 90');
  const lng = parseNumber(row.start_lng);
  if (lng === null || lng < -180 || lng > 180) errs.push('start_lng must be -180 to 180');
  if (row.baseline_l_per_100km !== undefined && row.baseline_l_per_100km.trim() !== '') {
    const b = parseNumber(row.baseline_l_per_100km);
    if (b === null || b <= 0) errs.push('baseline_l_per_100km must be > 0 or empty');
  }
  return errs;
}
export function validateSkuShape(row: Record<string, string>): string[] {
  const errs: string[] = [];
  const code = (row.code ?? '').trim();
  if (!code) errs.push('code is required');
  else if (code.length > 40) errs.push('code must be <= 40 chars');
  const name = (row.name ?? '').trim();
  if (!name) errs.push('name is required');
  else if (name.length > 200) errs.push('name must be <= 200 chars');
  const unit = (row.unit ?? '').trim();
  if (!unit) errs.push('unit is required');
  const w = parseNumber(row.weight_kg);
  if (w === null || w <= 0) errs.push('weight_kg must be > 0');
  const v = parseNumber(row.volume_m3);
  if (v === null || v <= 0) errs.push('volume_m3 must be > 0');
  for (const f of ['reorder_point', 'safety_stock', 'lead_time_days'] as const) {
    const x = row[f];
    if (x !== undefined && x.trim() !== '') {
      const n = parseInt2(x);
      if (n === null || n < 0) errs.push(`${f} must be >= 0 or empty`);
    }
  }
  return errs;
}
