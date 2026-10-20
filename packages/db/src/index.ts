export { PrismaClient, Prisma } from '../generated/client';
import { PrismaClient } from '../generated/client';

let _client: PrismaClient | null = null;

export function db(): PrismaClient {
  if (!_client) _client = new PrismaClient({ log: ['warn', 'error'] });
  return _client;
}
