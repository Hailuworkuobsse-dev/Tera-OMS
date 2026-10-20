export function getDistributorId(req: any): string {
  const id = req.headers['x-distributor-id'];
  if (!id || typeof id !== 'string') { const e = new Error('X-Distributor-Id header required') as any; e.statusCode = 401; throw e; }
  return id;
}
