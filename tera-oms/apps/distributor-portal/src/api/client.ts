const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export const DISTRIBUTOR_KEY = 'tera_distributor_id';
export class ApiError extends Error { constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); } }
export function getCurrentDistributor(): string | null { return localStorage.getItem(DISTRIBUTOR_KEY); }
export function setCurrentDistributor(id: string): void { localStorage.setItem(DISTRIBUTOR_KEY, id); }
export async function api<T>({ method = 'GET', path, body, signal }: { method?: string; path: string; body?: unknown; signal?: AbortSignal }): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const id = getCurrentDistributor(); if (id) headers['X-Distributor-Id'] = id;
  const res = await fetch(`${BASE}${path}`, { method, headers, body: body !== undefined ? JSON.stringify(body) : undefined, signal });
  if (!res.ok) { const p = await res.json().catch(() => ({})); throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p); }
  return res.status === 204 ? (undefined as T) : res.json();
}
