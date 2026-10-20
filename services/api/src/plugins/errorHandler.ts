import type { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';

export function errorHandler(err: FastifyError | ZodError, _req: FastifyRequest, reply: FastifyReply) {
  if (err instanceof ZodError) {
    return reply.status(400).send({ code: 'validation', message: 'invalid request', issues: err.issues });
  }
  const status = (err as any).statusCode ?? 500;
  return reply.status(status).send({ code: (err as any).code ?? 'internal', message: err.message });
}
