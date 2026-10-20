const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); }
}
export async function api<T>({ method = 'GET', path, body, signal }: {
  method?: string; path: string; body?: unknown; signal?: AbortSignal;
}): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method, headers: { 'Content-Type': 'application/json' },
    body: body !== undefined ? JSON.stringify(body) : undefined, signal,
  });
  if (!res.ok) {
    const p = await res.json().catch(() => ({}));
    throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p);
  }
  return res.status === 204 ? (undefined as T) : res.json();
}
