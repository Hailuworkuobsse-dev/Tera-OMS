import type { FastifyReply, FastifyRequest } from 'fastify';
import { recordHttpRequest } from './metrics-state.js';
const SKIP = new Set(['/metrics', '/health']);
interface Tagged extends FastifyRequest { _startNs?: bigint; }
export async function onRequestHook(req: Tagged) { req._startNs = process.hrtime.bigint(); }
export async function onResponseHook(req: Tagged, reply: FastifyReply) {
  const start = req._startNs; if (!start) return;
  const route = req.routeOptions.url; if (!route || SKIP.has(route)) return;
  recordHttpRequest(req.method, route, String(reply.statusCode), Number(process.hrtime.bigint() - start) / 1e9);
}
