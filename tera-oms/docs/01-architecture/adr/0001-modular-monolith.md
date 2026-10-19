# ADR 0001 — Modular monolith in Node

One Fastify app (`services/api`) with 18 plugin modules. Boundaries enforced by
`dependency-cruiser` — no cross-module repository imports, core stays leaf.
Optimizer and worker are separate processes for isolation, not scale.
