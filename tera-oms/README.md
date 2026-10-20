# Tera OMS

Optimization-first OMS for Ethiopian distribution.

- **Architecture:** `docs/01-architecture/module-map.md`
- **Pilot plan:** `docs/04-pilot/pilot-plan.md`

## Stack
Node 20 · TypeScript · Fastify · Prisma · MySQL 8 · Redis · BullMQ
React 18 · Vite · Tailwind · TanStack Query · Expo (driver mobile)

## Quick start
    cp .env.example .env
    pnpm install
    pnpm db:generate && pnpm db:migrate && pnpm db:seed
    docker compose up -d mysql redis
    pnpm dev

## Services
- `services/api` — Fastify API (13 modules, ~95 endpoints)
- `services/optimizer` — VRP worker (BullMQ)
- `services/worker` — nightly jobs (metric snapshot, fuel variance, credit rebuild)

## Frontends
8 apps: dispatcher, driver-mobile, warehouse, admin, exec, finance, distributor-portal
