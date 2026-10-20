# Tera OMS

Optimization-first Order Management System for Ethiopian distribution.

## Stack
- **Backend:** Node 20 · TypeScript · Fastify · Prisma · MySQL 8 · Redis · BullMQ · node-cron
- **Frontend:** React 18 · Vite 5 · Tailwind 3 · TanStack Query 5 · Leaflet · Expo (driver mobile)

## Services (3)
- `services/api` — 14 modules, ~95 endpoints, `/metrics`, `/docs` (Swagger)
- `services/optimizer` — VRP worker (BullMQ consumer for async route solve)
- `services/worker` — 3 nightly jobs (metric_snapshot, credit_rebuild, fuel_variance)

## Frontends (8)
| App | Port | Purpose |
|---|---|---|
| `dispatcher-web` | 5173 | Morning map · Route builder · Dispatch board · Credit stop list |
| `driver-mobile` | Expo | Manifest · e-POD · Payment · Fuel · Sync (offline-first) |
| `warehouse-web` | 5174 | Dock queue · Pick & stage |
| `admin-web` | 5175 | Masterdata · Constraints · Audit · Notifications · Jobs · Monitoring |
| `exec-web` | 5176 | ROI dashboard (hero + 10 tiles) |
| `finance-web` | 5177 | Credit exposure · Overrides · Reconciliation |
| `distributor-portal` | 5178 | Order · Track · Statements · Disputes |

## Quick start
```bash
cp .env.example .env
pnpm install
docker compose up -d mysql redis
pnpm db:generate && pnpm db:migrate && pnpm db:seed
