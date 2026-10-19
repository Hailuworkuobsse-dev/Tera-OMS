import type { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';

export function errorHandler(err: FastifyError | ZodError, req: FastifyRequest, reply: FastifyReply) {
  if (err instanceof ZodError) {
    return reply.status(400).send({ code: 'validation', message: 'invalid request', issues: err.issues });
  }
  const status = err.statusCode ?? 500;
  return reply.status(status).send({ code: err.code ?? 'internal', message: err.message });
}
