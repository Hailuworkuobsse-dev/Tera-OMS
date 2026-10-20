#!/usr/bin/env bash
# tera-build.sh — Tera OMS complete build (Part 1 of 3: Phases 0-2)
# Idempotent. Overwrites existing files. Runnable from any directory.

set -euo pipefail

# ── Root detection ──────────────────────────────────────────
if [[ -f services/api/package.json ]]; then
  ROOT="."
elif [[ -d tera-oms/services/api ]]; then
  ROOT="tera-oms"
else
  ROOT="tera-oms"
  mkdir -p "$ROOT"
fi
cd "$ROOT"
echo "→ Building Tera OMS in $(pwd)"
echo ""

# ── Helpers ─────────────────────────────────────────────────
W() { local p="$1"; mkdir -p "$(dirname "$p")"; cat > "$p"; echo "  $p"; }
d() { mkdir -p "$1"; }

# ═══════════════════════════════════════════════════════════════════
# PHASE 0 — SCAFFOLD
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 0 — Scaffold"

# ── Root config ────────────────────────────────────────────
W README.md <<'EOF'
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
EOF

W .gitignore <<'EOF'
node_modules/
.pnpm-store/
dist/
build/
.turbo/
*.tsbuildinfo
coverage/
.env
.env.local
.env.*.local
!.env.example
experiments/*/inputs/
experiments/*/outputs/
packages/db/generated/
*.log
.DS_Store
.vscode/
.idea/
EOF

W .editorconfig <<'EOF'
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true
[*.md]
trim_trailing_whitespace = false
EOF

echo "20" > .nvmrc

W .prettierrc.json <<'EOF'
{ "semi": true, "singleQuote": true, "trailingComma": "all", "printWidth": 100, "tabWidth": 2 }
EOF

W .env.example <<'EOF'
NODE_ENV=development
LOG_LEVEL=debug
TZ=Africa/Addis_Ababa

DATABASE_URL=mysql://tera:tera@localhost:3306/tera
REDIS_URL=redis://localhost:6379

JWT_SECRET=change-me-in-production
JWT_TTL_MIN=60
DRIVER_TOKEN_TTL_H=24

TELEBIRR_BASE_URL=https://sandbox.telebirr.example
TELEBIRR_APP_KEY=
SMS_PRIMARY_URL=
SMS_PRIMARY_KEY=

OPT_SOLVE_TIMEOUT_S=30
OPT_W_DISTANCE=1.0
OPT_W_OVERTIME=1.5
OPT_W_LATENESS=3.0
OPT_SLACK_BUFFER_PCT=8
OPT_CONCURRENCY=2
OPT_SOLVE_TIMEOUT_MS=30000

VITE_API_BASE_URL=http://localhost:8000
VITE_DEFAULT_LOCALE=am
EOF

W package.json <<'EOF'
{
  "name": "tera-oms",
  "private": true,
  "packageManager": "pnpm@9.0.0",
  "engines": { "node": ">=20" },
  "scripts": {
    "dev": "pnpm -r --parallel dev",
    "build": "pnpm -r build",
    "lint": "pnpm -r lint",
    "test": "pnpm -r test",
    "e2e": "bash scripts/e2e/smoke-test.sh",
    "db:generate": "pnpm --filter @tera/db generate",
    "db:migrate": "pnpm --filter @tera/db migrate",
    "db:seed": "pnpm --filter @tera/db seed",
    "db:studio": "pnpm --filter @tera/db studio",
    "boundaries": "depcruise --config .dependency-cruiser.cjs services/api/src"
  },
  "devDependencies": {
    "@types/node": "^20.12.0",
    "dependency-cruiser": "^16.0.0",
    "prettier": "^3.2.0",
    "typescript": "^5.4.0"
  }
}
EOF

W pnpm-workspace.yaml <<'EOF'
packages:
  - 'apps/*'
  - 'packages/*'
  - 'services/*'
EOF

W tsconfig.base.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "types": ["node"]
  }
}
EOF

W .dependency-cruiser.cjs <<'EOF'
module.exports = {
  forbidden: [
    {
      name: 'no-cross-module-repository',
      severity: 'error',
      from: { path: '^services/api/src/modules/([^/]+)/' },
      to: {
        path: '^services/api/src/modules/([^/]+)/repository\\.ts$',
        pathNot: '^services/api/src/modules/$1/repository\\.ts$',
      },
    },
    {
      name: 'core-cannot-import-modules',
      severity: 'error',
      from: { path: '^services/api/src/(core|shared)/' },
      to: { path: '^services/api/src/modules/' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'services/api/tsconfig.json' },
  },
};
EOF

# ── Docker compose (final) ────────────────────────────────
W docker-compose.yml <<'EOF'
services:
  mysql:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: tera
      MYSQL_USER: tera
      MYSQL_PASSWORD: tera
    ports: ["3306:3306"]
    volumes: [mysqldata:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-utera", "-ptera"]
      interval: 5s
      timeout: 3s
      retries: 20

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  api:
    build: ./services/api
    env_file: .env
    depends_on:
      mysql: { condition: service_healthy }
      redis: { condition: service_started }
    ports: ["8000:8000"]
    volumes:
      - ./services/api:/app
      - ./packages:/packages
      - ./seeds:/seeds

  optimizer:
    build: ./services/optimizer
    env_file: .env
    depends_on: [redis, mysql]
    volumes:
      - ./services/optimizer:/app
      - ./packages:/packages

  worker:
    build: ./services/worker
    env_file: .env
    depends_on: [redis, mysql]
    volumes:
      - ./services/worker:/app
      - ./packages:/packages

volumes:
  mysqldata:
EOF

W Makefile <<'EOF'
.PHONY: up down migrate seed studio dev api optimizer worker web e2e bootstrap lint test boundaries

bootstrap:
	pnpm install
	pnpm db:generate
	pnpm db:migrate
	pnpm db:seed

up: ; docker compose up -d
down: ; docker compose down
migrate: ; pnpm db:migrate
seed: ; pnpm db:seed
studio: ; pnpm db:studio
dev: ; pnpm dev
api: ; pnpm --filter @tera/api dev
optimizer: ; pnpm --filter @tera/optimizer dev
worker: ; pnpm --filter @tera/worker dev
web: ; pnpm --filter dispatcher-web dev
e2e: ; bash scripts/e2e/smoke-test.sh
lint: ; pnpm -r lint && pnpm boundaries
test: ; pnpm -r test
boundaries: ; pnpm boundaries
EOF

# ── Docs ─────────────────────────────────────────────────
d docs/00-management docs/01-architecture/adr docs/02-api docs/03-data docs/04-pilot docs/05-operations docs/06-frontend
W docs/01-architecture/module-map.md <<'EOF'
# Module Map
B1–B18 backend modules; F-A–F-G frontend apps.
See section 2 of the module design document.
EOF
W docs/01-architecture/adr/0001-modular-monolith.md <<'EOF'
# ADR 0001 — Modular monolith
One Fastify app with N plugin modules. Boundaries enforced by dependency-cruiser.
EOF
W docs/01-architecture/adr/0004-sync-server-vs-client-authority.md <<'EOF'
# ADR 0004 — Sync authority
Server wins on money/credit/stock/route. Client wins on delivery proof.
EOF
W docs/03-data/naming-conventions.md <<'EOF'
# Naming
Tables: `<module>_<entity>`. Routes: `/{module}/v1/{resource}`. Packages: `@tera/<name>`.
EOF
W docs/04-pilot/pilot-plan.md <<'EOF'
# Pilot Plan
See the management blueprint.
EOF

# ── Experiments ──────────────────────────────────────────
d experiments/paper-vrp experiments/credit-shadow experiments/fuel-baseline
W experiments/README.md <<'EOF'
# P0 Experiments (run before the app)
- paper-vrp/     gate: ≥8% km reduction
- credit-shadow/ gate: ≥70% precision, ≥80% recall
- fuel-baseline/ gate: clean L/100km distribution
EOF

# ── Infra ────────────────────────────────────────────────
d infra/runbooks infra/monitoring/grafana-dashboards
W infra/runbooks/telebirr-outage.md <<'EOF'
# Runbook: Telebirr outage
1. Confirm outage via health checks.
2. e-POD marks payments PENDING (never blocks).
3. Worker reconcile backoff active.
4. On restore: run reconcile --since <outage_start>.
EOF
W infra/runbooks/sync-backlog-recovery.md <<'EOF'
# Runbook: Sync backlog
1. Check sync gateway health.
2. Inspect client_change_log growth.
3. Never purge; drain by processing.
EOF

# ── Scripts / Seeds ──────────────────────────────────────
d scripts/dev scripts/data scripts/ops scripts/pilot scripts/e2e seeds/masterdata seeds/geo seeds/demo
W scripts/dev/bootstrap.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -f .env ]] || cp .env.example .env
pnpm install
pnpm db:generate
pnpm db:migrate
pnpm db:seed
echo "✓ ready — run: make up && make dev"
EOF
chmod +x scripts/dev/bootstrap.sh

for f in seeds/masterdata/.gitkeep seeds/geo/.gitkeep seeds/demo/.gitkeep; do W "$f" <<<''; done

# ── CI ──────────────────────────────────────────────────
d .github/workflows
W .github/workflows/ci.yml <<'EOF'
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.4
        env: { MYSQL_ROOT_PASSWORD: root, MYSQL_DATABASE: tera, MYSQL_USER: tera, MYSQL_PASSWORD: tera }
        ports: ['3306:3306']
        options: --health-cmd="mysqladmin ping" --health-interval=5s --health-retries=10
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
    env:
      DATABASE_URL: mysql://tera:tera@localhost:3306/tera
      REDIS_URL: redis://localhost:6379
      JWT_SECRET: test-secret-please-change
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm db:generate
      - run: pnpm -r lint
      - run: pnpm boundaries
      - run: pnpm -r test
EOF

# ═══════════════════════════════════════════════════════════════════
# PACKAGES
# ═══════════════════════════════════════════════════════════════════

# ── @tera/db (Prisma) ──────────────────────────────────────
W packages/db/package.json <<'EOF'
{
  "name": "@tera/db",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "scripts": {
    "prisma": "prisma",
    "generate": "prisma generate",
    "migrate": "prisma migrate dev",
    "deploy": "prisma migrate deploy",
    "seed": "tsx prisma/seed.ts",
    "studio": "prisma studio",
    "lint": "tsc --noEmit"
  },
  "dependencies": { "@prisma/client": "^6.0.0" },
  "devDependencies": {
    "prisma": "^6.0.0",
    "tsx": "^4.7.0",
    "typescript": "^5.4.0"
  }
}
EOF
W packages/db/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": ".", "composite": true }, "include": ["src", "prisma"] }
EOF
W packages/db/prisma/schema.prisma <<'EOF'
generator client {
  provider = "prisma-client-js"
  output   = "../generated/client"
}

datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}
EOF

# Identity
W packages/db/prisma/models/identity.prisma <<'EOF'
// (reserved for Phase 7 JWT) — current auth uses headers + tokens
EOF

# Masterdata — FINAL (all fields from every phase)
W packages/db/prisma/models/masterdata.prisma <<'EOF'
model Distributor {
  id        String   @id @default(cuid())
  name      String   @db.VarChar(200)
  region    String   @db.VarChar(100)
  lat       Decimal? @db.Decimal(10, 7)
  lng       Decimal? @db.Decimal(10, 7)
  active    Boolean  @default(true)
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @default(now()) @updatedAt @map("updated_at")

  creditAccounts CreditAccount[]

  @@index([region])
  @@index([active])
  @@map("masterdata_distributor")
}

model Vehicle {
  id                String   @id @default(cuid())
  plate             String   @unique @db.VarChar(20)
  capacityKg        Decimal  @map("capacity_kg") @db.Decimal(8, 2)
  capacityM3        Decimal  @map("capacity_m3") @db.Decimal(8, 3)
  shiftStartH       Int      @map("shift_start_h")
  shiftEndH         Int      @map("shift_end_h")
  startLat          Decimal  @map("start_lat") @db.Decimal(10, 7)
  startLng          Decimal  @map("start_lng") @db.Decimal(10, 7)
  baselineLPer100Km Decimal? @map("baseline_l_per_100km") @db.Decimal(6, 2)
  active            Boolean  @default(true)
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @default(now()) @updatedAt @map("updated_at")

  @@index([active])
  @@map("masterdata_vehicle")
}

model Sku {
  id           String   @id @default(cuid())
  code         String   @unique @db.VarChar(40)
  name         String   @db.VarChar(200)
  unit         String   @db.VarChar(20)
  weightKg     Decimal  @map("weight_kg") @db.Decimal(8, 3)
  volumeM3     Decimal  @map("volume_m3") @db.Decimal(8, 4)
  unitPriceEtb Decimal  @default(0) @map("unit_price_etb") @db.Decimal(14, 2)
  stockOnHand  Int      @default(0) @map("stock_on_hand")
  reorderPoint Int      @default(0) @map("reorder_point")
  safetyStock  Int      @default(0) @map("safety_stock")
  leadTimeDays Int      @default(0) @map("lead_time_days")
  active       Boolean  @default(true)
  createdAt    DateTime @default(now()) @map("created_at")
  updatedAt    DateTime @default(now()) @updatedAt @map("updated_at")

  @@index([active])
  @@map("masterdata_sku")
}
EOF

# Config
W packages/db/prisma/models/config.prisma <<'EOF'
model Setting {
  key       String   @id @db.VarChar(100)
  value     String   @db.Text
  updatedAt DateTime @updatedAt @map("updated_at")

  @@map("config_setting")
}
EOF

# Credit
W packages/db/prisma/models/credit.prisma <<'EOF'
model CreditAccount {
  id             String    @id @default(cuid())
  distributorId  String    @unique @map("distributor_id")
  limitEtb       Decimal   @map("limit_etb") @db.Decimal(14, 2)
  graceDays      Int       @default(14) @map("grace_days")
  exposureEtb    Decimal   @default(0) @map("exposure_etb") @db.Decimal(14, 2)
  oldestUnpaidAt DateTime? @map("oldest_unpaid_at")
  createdAt      DateTime  @default(now()) @map("created_at")
  updatedAt      DateTime  @updatedAt @map("updated_at")

  distributor Distributor      @relation(fields: [distributorId], references: [id])
  decisions   CreditDecision[]
  overrides   CreditOverride[]

  @@map("credit_account")
}

model CreditDecision {
  id          String   @id @default(cuid())
  accountId   String   @map("account_id")
  orderId     String?  @map("order_id")
  outcome     String   @db.VarChar(16)
  reason      String   @db.VarChar(32)
  exposureEtb Decimal  @map("exposure_etb") @db.Decimal(14, 2)
  limitEtb    Decimal  @map("limit_etb") @db.Decimal(14, 2)
  daysOverdue Int      @map("days_overdue")
  createdAt   DateTime @default(now()) @map("created_at")

  account   CreditAccount    @relation(fields: [accountId], references: [id])
  overrides CreditOverride[]

  @@index([accountId, createdAt])
  @@map("credit_decision")
}

model CreditOverride {
  id            String   @id @default(cuid())
  decisionId    String?  @map("decision_id")
  distributorId String   @map("distributor_id")
  reason        String   @db.Text
  actorId       String   @map("actor_id")
  expiresAt     DateTime @map("expires_at")
  createdAt     DateTime @default(now()) @map("created_at")

  decision CreditDecision? @relation(fields: [decisionId], references: [id])

  @@index([distributorId, expiresAt])
  @@map("credit_override")
}
EOF

# Geo (curfew + fuel station)
W packages/db/prisma/models/geo.prisma <<'EOF'
model CurfewZone {
  id          String   @id @default(cuid())
  name        String   @db.VarChar(200)
  polygonJson Json     @map("polygon_json")
  startHour   Int      @map("start_hour")
  endHour     Int      @map("end_hour")
  reason      String   @db.VarChar(200)
  active      Boolean  @default(true)
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  @@index([active])
  @@map("geo_curfew_zone")
}

model FuelStation {
  id              String   @id @default(cuid())
  name            String   @db.VarChar(200)
  lat             Decimal  @db.Decimal(10, 7)
  lng             Decimal  @db.Decimal(10, 7)
  status          String   @db.VarChar(20) @default("operational")
  statusUpdatedBy String?  @map("status_updated_by") @db.VarChar(100)
  active          Boolean  @default(true)
  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")

  @@index([active, status])
  @@map("geo_fuel_station")
}
EOF

# Orders (final — with lines + totalQuantity)
W packages/db/prisma/models/orders.prisma <<'EOF'
model Order {
  id              String    @id @default(cuid())
  distributorId   String    @map("distributor_id")
  distributorName String    @map("distributor_name") @db.VarChar(200)
  lat             Decimal   @db.Decimal(10, 7)
  lng             Decimal   @db.Decimal(10, 7)
  weightKg        Decimal   @map("weight_kg") @db.Decimal(8, 2)
  volumeM3        Decimal   @map("volume_m3") @db.Decimal(8, 3)
  priority        Int       @default(5)
  timeWindowStart DateTime  @map("time_window_start")
  timeWindowEnd   DateTime  @map("time_window_end")
  status          String    @db.VarChar(20) @default("PENDING")
  totalQuantity   Int       @default(0) @map("total_quantity")
  createdAt       DateTime  @default(now()) @map("created_at")

  lines OrderLine[]

  @@index([status])
  @@index([distributorId, createdAt])
  @@map("orders_order")
}

model OrderLine {
  id        String   @id @default(cuid())
  orderId   String   @map("order_id")
  skuId     String   @map("sku_id") @db.VarChar(100)
  skuCode   String   @map("sku_code") @db.VarChar(40)
  skuName   String   @map("sku_name") @db.VarChar(200)
  quantity  Int
  unitPrice Decimal  @map("unit_price") @db.Decimal(14, 2)
  lineTotal Decimal  @map("line_total") @db.Decimal(14, 2)

  order Order @relation(fields: [orderId], references: [id], onDelete: Cascade)

  @@index([orderId])
  @@map("orders_order_line")
}
EOF

# Routing (final — with pickedAt, quantityOrdered, statusUpdatedAt)
W packages/db/prisma/models/routing.prisma <<'EOF'
model RoutePlan {
  id         String   @id @default(cuid())
  date       DateTime @db.Date
  vehicleId  String   @map("vehicle_id")
  driverId   String   @map("driver_id")
  status     String   @db.VarChar(20) @default("PLANNED")
  version    Int      @default(1)
  plannedKm  Decimal  @map("planned_km") @db.Decimal(8, 2)
  plannedMin Int      @map("planned_min")
  startLat   Decimal  @map("start_lat") @db.Decimal(10, 7)
  startLng   Decimal  @map("start_lng") @db.Decimal(10, 7)
  baselineKm Decimal? @map("baseline_km") @db.Decimal(8, 2)
  createdAt  DateTime @default(now()) @map("created_at")

  stops RouteStop[]

  @@unique([date, vehicleId, version])
  @@index([date, status])
  @@index([driverId, date])
  @@map("routing_route_plan")
}

model RouteStop {
  id              String    @id @default(cuid())
  routePlanId     String    @map("route_plan_id")
  orderId         String?   @map("order_id")
  seq             Int
  distributorId   String    @map("distributor_id")
  distributorName String    @map("distributor_name") @db.VarChar(200)
  lat             Decimal   @db.Decimal(10, 7)
  lng             Decimal   @db.Decimal(10, 7)
  plannedEta      DateTime  @map("planned_eta")
  actualArrival   DateTime? @map("actual_arrival")
  status          String    @db.VarChar(20) @default("PENDING")
  statusUpdatedAt DateTime  @default(now()) @map("status_updated_at")
  quantityOrdered Int       @default(0) @map("quantity_ordered")
  pickedAt        DateTime? @map("picked_at")

  routePlan RoutePlan @relation(fields: [routePlanId], references: [id], onDelete: Cascade)

  @@unique([routePlanId, seq])
  @@index([status])
  @@map("routing_route_stop")
}
EOF

# Dispatch (docks + slots)
W packages/db/prisma/models/dispatch.prisma <<'EOF'
model DispatchDock {
  id        String   @id @default(cuid())
  name      String   @db.VarChar(100)
  active    Boolean  @default(true)
  createdAt DateTime @default(now()) @map("created_at")

  slots DispatchDockSlot[]

  @@map("dispatch_dock")
}

model DispatchDockSlot {
  id          String    @id @default(cuid())
  dockId      String    @map("dock_id")
  date        DateTime  @db.Date
  startAt     DateTime  @map("start_at")
  endAt       DateTime  @map("end_at")
  status      String    @db.VarChar(20) @default("AVAILABLE")
  routePlanId String?   @unique @map("route_plan_id")
  confirmedAt DateTime? @map("confirmed_at")
  confirmedBy String?   @map("confirmed_by")
  createdAt   DateTime  @default(now()) @map("created_at")

  dock DispatchDock @relation(fields: [dockId], references: [id])

  @@index([date, status])
  @@index([dockId, date])
  @@map("dispatch_dock_slot")
}
EOF

# Sync
W packages/db/prisma/models/sync.prisma <<'EOF'
model SyncClient {
  id             String   @id @default(cuid())
  deviceId       String   @unique @map("device_id") @db.VarChar(200)
  driverId       String   @map("driver_id") @db.VarChar(100)
  lastPullCursor BigInt   @default(0) @map("last_pull_cursor")
  lastSeenAt     DateTime @default(now()) @map("last_seen_at")
  createdAt      DateTime @default(now()) @map("created_at")

  @@index([driverId])
  @@map("sync_client")
}

model SyncChangeLog {
  id            BigInt   @id @default(autoincrement())
  entityType    String   @map("entity_type") @db.VarChar(40)
  entityId      String   @map("entity_id")   @db.VarChar(100)
  op            String   @db.VarChar(10)
  payloadJson   Json     @map("payload_json") @db.Text
  scopeDriverId String?  @map("scope_driver_id") @db.VarChar(100)
  createdAt     DateTime @default(now()) @map("created_at")

  @@index([id])
  @@index([scopeDriverId, id])
  @@map("sync_change_log")
}

model SyncOpLog {
  id         String   @id @default(cuid())
  clientOpId String   @unique @map("client_op_id") @db.VarChar(80)
  clientId   String   @map("client_id")
  opType     String   @map("op_type") @db.VarChar(40)
  resultJson Json     @map("result_json") @db.Text
  appliedAt  DateTime @default(now()) @map("applied_at")

  @@index([clientId, appliedAt])
  @@map("sync_op_log")
}

model SyncConflict {
  id             String    @id @default(cuid())
  clientId       String    @map("client_id")
  clientOpId     String    @map("client_op_id") @db.VarChar(80)
  entityType     String    @map("entity_type") @db.VarChar(40)
  entityId       String    @map("entity_id") @db.VarChar(100)
  reason         String    @db.VarChar(200)
  serverSnapshot Json      @map("server_snapshot") @db.Text
  clientSnapshot Json      @map("client_snapshot") @db.Text
  resolvedAt     DateTime? @map("resolved_at")
  createdAt      DateTime  @default(now()) @map("created_at")

  @@index([resolvedAt, createdAt])
  @@map("sync_conflict")
}
EOF

# Delivery proof
W packages/db/prisma/models/proof.prisma <<'EOF'
model ProofOfDelivery {
  id              String   @id @default(cuid())
  routeStopId     String   @map("route_stop_id") @db.VarChar(100)
  orderId         String?  @map("order_id") @db.VarChar(100)
  outcome         String   @db.VarChar(20)
  qtyConfirmed    Int?     @map("qty_confirmed")
  qtyOrdered      Int?     @map("qty_ordered")
  reason          String?  @db.Text
  signatureBase64 String?  @map("signature_base64") @db.MediumText
  photoBase64     String?  @map("photo_base64")     @db.MediumText
  clientOpId      String   @unique @map("client_op_id") @db.VarChar(80)
  capturedAt      DateTime @map("captured_at")
  receivedAt      DateTime @default(now()) @map("received_at")

  @@index([routeStopId, capturedAt])
  @@map("proof_of_delivery")
}
EOF

# Payment
W packages/db/prisma/models/payment.prisma <<'EOF'
model Payment {
  id             String    @id @default(cuid())
  routeStopId    String    @map("route_stop_id") @db.VarChar(100)
  orderId        String?   @map("order_id") @db.VarChar(100)
  method         String    @db.VarChar(20)
  amountEtb      Decimal   @map("amount_etb") @db.Decimal(14, 2)
  telebirrRef    String?   @unique @map("telebirr_ref") @db.VarChar(60)
  clientOpId     String    @unique @map("client_op_id") @db.VarChar(80)
  capturedAt     DateTime  @map("captured_at")
  receivedAt     DateTime  @default(now()) @map("received_at")
  reconciledAt   DateTime? @map("reconciled_at")
  reconciledBy   String?   @map("reconciled_by") @db.VarChar(100)
  reconcileNotes String?   @map("reconcile_notes") @db.Text

  @@index([routeStopId, capturedAt])
  @@index([reconciledAt, receivedAt])
  @@map("payment")
}
EOF

# Fuel
W packages/db/prisma/models/fuel.prisma <<'EOF'
model FuelLog {
  id            String   @id @default(cuid())
  driverId      String   @map("driver_id") @db.VarChar(100)
  vehicleId     String   @map("vehicle_id") @db.VarChar(100)
  liters        Decimal  @db.Decimal(8, 2)
  amountEtb     Decimal  @map("amount_etb") @db.Decimal(14, 2)
  odometerKm    Decimal  @map("odometer_km") @db.Decimal(12, 2)
  stationName   String   @map("station_name") @db.VarChar(100)
  stationId     String?  @map("station_id") @db.VarChar(100)
  varianceFlag  String   @map("variance_flag") @db.VarChar(20) @default("NO_BASELINE")
  varianceRatio Decimal? @map("variance_ratio") @db.Decimal(6, 3)
  clientOpId    String   @unique @map("client_op_id") @db.VarChar(80)
  capturedAt    DateTime @map("captured_at")
  receivedAt    DateTime @default(now()) @map("received_at")

  @@index([vehicleId, capturedAt])
  @@index([varianceFlag, receivedAt])
  @@map("fuel_log")
}
EOF

# Disputes
W packages/db/prisma/models/disputes.prisma <<'EOF'
model Dispute {
  id              String    @id @default(cuid())
  orderId         String    @map("order_id") @db.VarChar(100)
  distributorId   String    @map("distributor_id") @db.VarChar(100)
  type            String    @db.VarChar(40)
  description     String    @db.Text
  proofId         String?   @map("proof_id") @db.VarChar(100)
  status          String    @db.VarChar(20) @default("OPEN")
  resolutionNotes String?   @map("resolution_notes") @db.Text
  createdAt       DateTime  @default(now()) @map("created_at")
  resolvedAt      DateTime? @map("resolved_at")

  @@index([distributorId, createdAt])
  @@index([status])
  @@map("dispute")
}
EOF

# Analytics
W packages/db/prisma/models/analytics.prisma <<'EOF'
model Baseline {
  id       String   @id @default(cuid())
  key      String   @unique @db.VarChar(60)
  value    Float
  unit     String   @db.VarChar(20)
  notes    String?  @db.Text
  frozenAt DateTime @map("frozen_at")
  frozenBy String   @map("frozen_by") @db.VarChar(100)

  @@map("analytics_baseline")
}

model MetricSnapshot {
  id        String   @id @default(cuid())
  date      DateTime @db.Date
  key       String   @db.VarChar(60)
  value     Float
  metaJson  Json?    @map("meta_json")
  createdAt DateTime @default(now()) @map("created_at")

  @@unique([date, key])
  @@index([key, date])
  @@map("analytics_metric_snapshot")
}

model CostAssumption {
  key       String   @id @db.VarChar(60)
  value     Float
  unit      String   @db.VarChar(20)
  updatedAt DateTime @updatedAt @map("updated_at")

  @@map("analytics_cost_assumption")
}
EOF

# Audit
W packages/db/prisma/models/audit.prisma <<'EOF'
model AuditLog {
  id        String   @id @default(cuid())
  actorId   String   @map("actor_id") @db.VarChar(100)
  entity    String   @db.VarChar(40)
  entityId  String   @map("entity_id") @db.VarChar(100)
  action    String   @db.VarChar(40)
  reason    String   @db.Text
  metaJson  Json?    @map("meta_json")
  createdAt DateTime @default(now()) @map("created_at")

  @@index([entity, createdAt])
  @@index([actorId, createdAt])
  @@index([createdAt])
  @@map("audit_log")
}
EOF

# Notify
W packages/db/prisma/models/notify.prisma <<'EOF'
model NotificationLog {
  id           String   @id @default(cuid())
  channel      String   @db.VarChar(20)
  recipient    String   @db.VarChar(200)
  templateKey  String   @map("template_key") @db.VarChar(60)
  renderedBody String   @map("rendered_body") @db.Text
  status       String   @db.VarChar(20)
  providerRef  String?  @map("provider_ref") @db.VarChar(100)
  error        String?  @db.Text
  sentAt       DateTime @default(now()) @map("sent_at")

  @@index([channel, sentAt])
  @@index([status, sentAt])
  @@map("notification_log")
}
EOF

# Solve jobs
W packages/db/prisma/models/solve-job.prisma <<'EOF'
model SolveJob {
  id           String    @id @default(cuid())
  status       String    @db.VarChar(20) @default("QUEUED")
  orderIdsJson Json      @map("order_ids_json")
  vehicleId    String    @map("vehicle_id") @db.VarChar(100)
  resultJson   Json?     @map("result_json")
  error        String?   @db.Text
  startedAt    DateTime? @map("started_at")
  finishedAt   DateTime? @map("finished_at")
  durationMs   Int?      @map("duration_ms")
  createdAt    DateTime  @default(now()) @map("created_at")

  @@index([status, createdAt])
  @@map("routing_solve_job")
}
EOF

# Job runs
W packages/db/prisma/models/job-run.prisma <<'EOF'
model JobRun {
  id             String    @id @default(cuid())
  jobKey         String    @map("job_key") @db.VarChar(60)
  status         String    @db.VarChar(20) @default("RUNNING")
  startedAt      DateTime  @default(now()) @map("started_at")
  finishedAt     DateTime? @map("finished_at")
  durationMs     Int?      @map("duration_ms")
  processedCount Int       @default(0) @map("processed_count")
  skippedCount   Int       @default(0) @map("skipped_count")
  triggeredBy    String    @map("triggered_by") @db.VarChar(40) @default("schedule")
  error          String?   @db.Text

  @@index([jobKey, startedAt])
  @@index([status, startedAt])
  @@map("job_run")
}
EOF

W packages/db/src/index.ts <<'EOF'
export { PrismaClient, Prisma } from '../generated/client';
import { PrismaClient } from '../generated/client';

let _client: PrismaClient | null = null;

export function db(): PrismaClient {
  if (!_client) _client = new PrismaClient({ log: ['warn', 'error'] });
  return _client;
}
EOF

# ── @tera/contracts ────────────────────────────────────────
W packages/contracts/package.json <<'EOF'
{
  "name": "@tera/contracts",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": { "lint": "tsc --noEmit", "test": "vitest run", "build": "tsc -b" },
  "dependencies": { "zod": "^3.23.0" },
  "devDependencies": { "typescript": "^5.4.0", "vitest": "^1.6.0" }
}
EOF
W packages/contracts/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true }, "include": ["src"] }
EOF

# Credit contracts
W packages/contracts/src/credit.ts <<'EOF'
import { z } from 'zod';

export const CreditDecisionEnum = z.enum(['BLOCKED', 'WARNED', 'CLEARED']);
export const CreditReasonEnum = z.enum(['OVER_LIMIT', 'PAST_GRACE', 'BOTH', 'NONE']);

export const CreditStopRowSchema = z.object({
  distributor_id: z.string(), distributor_name: z.string(), region: z.string(),
  decision: CreditDecisionEnum, reason: CreditReasonEnum,
  amount_owed_etb: z.number(), credit_limit_etb: z.number(), exposure_etb: z.number(),
  days_overdue: z.number().int().nonnegative(), grace_days: z.number().int().nonnegative(),
  blocked_at: z.string().datetime(), active_override_until: z.string().datetime().nullable(),
});

export const CreditStopListResponseSchema = z.object({
  as_of: z.string().datetime(), hard_gate: z.boolean(),
  rows: z.array(CreditStopRowSchema),
});

export const OverrideRequestSchema = z.object({
  distributor_id: z.string().min(1),
  reason: z.string().trim().min(5),
  expires_at: z.string().datetime(),
});

export const OverrideResponseSchema = z.object({
  ok: z.literal(true), expires_at: z.string().datetime(),
});

export const AgingBucketLabelEnum = z.enum(['current', 'watch', 'overdue', 'critical']);

export const ExposureAccountSchema = z.object({
  distributor_id: z.string(), distributor_name: z.string(), region: z.string(),
  exposure_etb: z.number(), limit_etb: z.number(), utilization_pct: z.number(),
  days_since_oldest_unpaid: z.number().int(),
  grace_days: z.number().int(), days_overdue: z.number().int(),
});

export const AgingBucketSchema = z.object({
  label: AgingBucketLabelEnum, days_range: z.string(),
  account_count: z.number().int(), exposure_etb: z.number(),
});

export const ExposureResponseSchema = z.object({
  as_of: z.string().datetime(),
  total_exposure_etb: z.number(), total_limit_etb: z.number(), utilization_pct: z.number(),
  accounts_over_limit: z.number().int(), accounts_past_grace: z.number().int(),
  aging_buckets: z.array(AgingBucketSchema),
  near_limit_accounts: z.array(ExposureAccountSchema),
  all_accounts: z.array(ExposureAccountSchema),
});

export const OverrideRowSchema = z.object({
  id: z.string(), distributor_id: z.string(), distributor_name: z.string(),
  reason: z.string(), actor_id: z.string(),
  created_at: z.string().datetime(), expires_at: z.string().datetime(), expired: z.boolean(),
});

export const OverridesListResponseSchema = z.object({
  total: z.number().int(), overrides: z.array(OverrideRowSchema),
});

export type CreditDecision = z.infer<typeof CreditDecisionEnum>;
export type CreditReason = z.infer<typeof CreditReasonEnum>;
export type CreditStopRow = z.infer<typeof CreditStopRowSchema>;
export type CreditStopListResponse = z.infer<typeof CreditStopListResponseSchema>;
export type OverrideRequest = z.infer<typeof OverrideRequestSchema>;
export type ExposureAccount = z.infer<typeof ExposureAccountSchema>;
export type AgingBucket = z.infer<typeof AgingBucketSchema>;
export type ExposureResponse = z.infer<typeof ExposureResponseSchema>;
export type OverrideRow = z.infer<typeof OverrideRowSchema>;
export type OverridesListResponse = z.infer<typeof OverridesListResponseSchema>;
EOF

# Geo contracts
W packages/contracts/src/geo.ts <<'EOF'
import { z } from 'zod';

export const GeoJsonPolygonSchema = z.object({
  type: z.literal('Polygon'),
  coordinates: z.array(z.array(z.tuple([z.number(), z.number()]))),
});

export const CurfewZoneSchema = z.object({
  id: z.string(), name: z.string(), polygon: GeoJsonPolygonSchema,
  start_hour: z.number().int().min(0).max(23),
  end_hour: z.number().int().min(0).max(23),
  reason: z.string(), active: z.boolean(),
});

export const CurfewZonesResponseSchema = z.object({ zones: z.array(CurfewZoneSchema) });
export const CreateCurfewZoneSchema = z.object({
  name: z.string().trim().min(1).max(200),
  polygon: GeoJsonPolygonSchema,
  start_hour: z.number().int().min(0).max(23),
  end_hour: z.number().int().min(0).max(23),
  reason: z.string().trim().min(1).max(200),
});
export const UpdateCurfewHoursSchema = z.object({
  start_hour: z.number().int().min(0).max(23),
  end_hour: z.number().int().min(0).max(23),
  reason: z.string().trim().min(1).max(200),
});

export const FuelStationStatusEnum = z.enum(['operational', 'queued', 'dry']);
export const FuelStationSchema = z.object({
  id: z.string(), name: z.string(), lat: z.number(), lng: z.number(),
  status: FuelStationStatusEnum, active: z.boolean(), updated_at: z.string().datetime(),
});
export const FuelStationsResponseSchema = z.object({ stations: z.array(FuelStationSchema) });
export const CreateFuelStationSchema = z.object({
  name: z.string().trim().min(1).max(200),
  lat: z.number().gte(-90).lte(90), lng: z.number().gte(-180).lte(180),
  status: FuelStationStatusEnum.default('operational'),
});
export const UpdateStationStatusSchema = z.object({ status: FuelStationStatusEnum });
export const ToggleActiveSchema = z.object({ active: z.boolean() });

export type GeoJsonPolygon = z.infer<typeof GeoJsonPolygonSchema>;
export type CurfewZone = z.infer<typeof CurfewZoneSchema>;
export type CreateCurfewZone = z.infer<typeof CreateCurfewZoneSchema>;
export type UpdateCurfewHours = z.infer<typeof UpdateCurfewHoursSchema>;
export type FuelStation = z.infer<typeof FuelStationSchema>;
export type FuelStationStatus = z.infer<typeof FuelStationStatusEnum>;
export type CreateFuelStation = z.infer<typeof CreateFuelStationSchema>;
EOF

# Routing contracts
W packages/contracts/src/routing.ts <<'EOF'
import { z } from 'zod';

export const StopStatusEnum = z.enum(['PENDING', 'ARRIVED', 'DELIVERED', 'FAILED']);
export const RouteStatusEnum = z.enum(['PLANNED', 'DISPATCHED', 'COMPLETED']);

export const RouteStopSchema = z.object({
  id: z.string(), seq: z.number().int(),
  distributor_id: z.string(), distributor_name: z.string(),
  lat: z.number(), lng: z.number(),
  planned_eta: z.string().datetime(), actual_arrival: z.string().datetime().nullable(),
  status: StopStatusEnum,
});

export const RoutePlanSchema = z.object({
  id: z.string(), vehicle_id: z.string(), driver_id: z.string(),
  status: RouteStatusEnum, planned_km: z.number(), planned_min: z.number().int(),
  start_lat: z.number(), start_lng: z.number(),
  stops: z.array(RouteStopSchema),
});

export const TodayRoutesResponseSchema = z.object({
  as_of: z.string().datetime(),
  routes: z.array(RoutePlanSchema),
});

export type RouteStop = z.infer<typeof RouteStopSchema>;
export type RoutePlan = z.infer<typeof RoutePlanSchema>;
EOF

# Orders contracts
W packages/contracts/src/orders.ts <<'EOF'
import { z } from 'zod';

export const OrderSchema = z.object({
  id: z.string(), distributor_id: z.string(), distributor_name: z.string(),
  lat: z.number(), lng: z.number(), weight_kg: z.number(), volume_m3: z.number(),
  priority: z.number().int(),
  time_window_start: z.string().datetime(), time_window_end: z.string().datetime(),
  status: z.enum(['PENDING', 'ROUTED', 'DELIVERED']),
  created_at: z.string().datetime(),
});

export const PendingOrdersResponseSchema = z.object({ orders: z.array(OrderSchema) });
export type Order = z.infer<typeof OrderSchema>;
EOF

# Route builder contracts (incl async)
W packages/contracts/src/route-builder.ts <<'EOF'
import { z } from 'zod';

export const VehicleSchema = z.object({
  id: z.string(), plate: z.string(),
  capacity_kg: z.number(), capacity_m3: z.number(),
  shift_start_h: z.number().int(), shift_end_h: z.number().int(),
  start_lat: z.number(), start_lng: z.number(),
});
export const VehiclesResponseSchema = z.object({ vehicles: z.array(VehicleSchema) });

export const SolveRequestSchema = z.object({
  order_ids: z.array(z.string()).min(2),
  vehicle_id: z.string().min(1),
});

export const SolveStopSchema = z.object({
  order_id: z.string(), distributor_name: z.string(),
  seq: z.number().int().positive(),
  eta: z.string(), lat: z.number(), lng: z.number(),
});
export const SolveSequenceSchema = z.object({
  stops: z.array(SolveStopSchema),
  total_km: z.number(), total_min: z.number().int(),
});
export const SolveResponseSchema = z.object({
  manual: SolveSequenceSchema, optimized: SolveSequenceSchema,
  savings_km_pct: z.number(), savings_time_pct: z.number(),
  infeasible: z.object({ order_id: z.string(), reason: z.string() }).nullable(),
});

export const AcceptRouteRequestSchema = z.object({
  order_ids: z.array(z.string()).min(2),
  vehicle_id: z.string().min(1),
  driver_id: z.string().min(1),
  mode: z.enum(['optimized', 'manual']),
});
export const AcceptRouteResponseSchema = z.object({
  route_id: z.string(), planned_km: z.number(), planned_min: z.number().int(),
});

export const AsyncSolveStatusEnum = z.enum(['QUEUED', 'RUNNING', 'DONE', 'FAILED', 'TIMEOUT']);
export const AsyncSolveRequestSchema = z.object({
  order_ids: z.array(z.string()).min(2).max(500),
  vehicle_id: z.string().min(1),
});
export const AsyncSolveSubmitResponseSchema = z.object({
  job_id: z.string(), status: AsyncSolveStatusEnum,
});
export const AsyncSolveJobResponseSchema = z.object({
  job_id: z.string(), status: AsyncSolveStatusEnum,
  submitted_at: z.string().datetime(),
  started_at: z.string().datetime().nullable(),
  finished_at: z.string().datetime().nullable(),
  duration_ms: z.number().int().nullable(),
  result: SolveResponseSchema.nullable(),
  error: z.string().nullable(),
});

export type Vehicle = z.infer<typeof VehicleSchema>;
export type SolveRequest = z.infer<typeof SolveRequestSchema>;
export type SolveResponse = z.infer<typeof SolveResponseSchema>;
export type SolveSequence = z.infer<typeof SolveSequenceSchema>;
export type AcceptRouteRequest = z.infer<typeof AcceptRouteRequestSchema>;
export type AcceptRouteResponse = z.infer<typeof AcceptRouteResponseSchema>;
export type AsyncSolveStatus = z.infer<typeof AsyncSolveStatusEnum>;
export type AsyncSolveSubmitResponse = z.infer<typeof AsyncSolveSubmitResponseSchema>;
export type AsyncSolveJobResponse = z.infer<typeof AsyncSolveJobResponseSchema>;
EOF

# Dispatch contracts
W packages/contracts/src/dispatch.ts <<'EOF'
import { z } from 'zod';

export const SlotStatusEnum = z.enum(['AVAILABLE', 'ALLOCATED', 'CONFIRMED', 'COMPLETED']);
export const RouteBoardStatusEnum = z.enum(['PLANNED', 'DISPATCHED', 'COMPLETED']);

export const RouteSummarySchema = z.object({
  id: z.string(), vehicle_id: z.string(), driver_id: z.string(),
  status: RouteBoardStatusEnum, planned_km: z.number(), planned_min: z.number().int(),
  stop_count: z.number().int(), picked_count: z.number().int(),
});

export const DockSlotSchema = z.object({
  id: z.string(), start_at: z.string().datetime(), end_at: z.string().datetime(),
  status: SlotStatusEnum,
  confirmed_at: z.string().datetime().nullable(),
  confirmed_by: z.string().nullable(),
  route: RouteSummarySchema.nullable(),
});

export const DockSchema = z.object({
  id: z.string(), name: z.string(), slots: z.array(DockSlotSchema),
});

export const BoardResponseSchema = z.object({
  as_of: z.string().datetime(),
  summary: z.object({
    routes_planned: z.number().int(), routes_dispatched: z.number().int(),
    slots_available: z.number().int(), slots_allocated: z.number().int(),
    slots_confirmed: z.number().int(), unallocated_routes: z.number().int(),
  }),
  docks: z.array(DockSchema),
});

export const AllocateResponseSchema = z.object({
  allocated: z.number().int(), skipped_unallocatable: z.number().int(),
});
export const ConfirmSlotResponseSchema = z.object({
  slot_id: z.string(), status: SlotStatusEnum, confirmed_at: z.string().datetime(),
});
export const DispatchRouteResponseSchema = z.object({
  route_id: z.string(), status: RouteBoardStatusEnum, slot_status: SlotStatusEnum,
});

export const PickListStopSchema = z.object({
  stop_id: z.string(), seq: z.number().int(),
  distributor_name: z.string(), quantity_ordered: z.number().int(),
  picked_at: z.string().datetime().nullable(),
});
export const PickListResponseSchema = z.object({
  route_id: z.string(), vehicle_id: z.string(), driver_id: z.string(),
  slot_id: z.string().nullable(), slot_status: SlotStatusEnum.nullable(),
  stops: z.array(PickListStopSchema),
  picked_count: z.number().int(), total_count: z.number().int(),
  can_confirm_loading: z.boolean(),
});
export const MarkPickedResponseSchema = z.object({
  stop_id: z.string(), picked_at: z.string().datetime(),
  picked_count: z.number().int(), total_count: z.number().int(),
  can_confirm_loading: z.boolean(),
});

export type RouteSummary = z.infer<typeof RouteSummarySchema>;
export type DockSlot = z.infer<typeof DockSlotSchema>;
export type Dock = z.infer<typeof DockSchema>;
export type BoardResponse = z.infer<typeof BoardResponseSchema>;
export type PickListStop = z.infer<typeof PickListStopSchema>;
export type PickListResponse = z.infer<typeof PickListResponseSchema>;
EOF

# Sync contracts
W packages/contracts/src/sync.ts <<'EOF'
import { z } from 'zod';
import { FuelLogOpSchema } from './fuel.js';

export const SyncChangeSchema = z.object({
  cursor: z.string(), entity_type: z.string(), entity_id: z.string(),
  op: z.enum(['upsert', 'delete']),
  payload: z.record(z.unknown()),
  created_at: z.string().datetime(),
});

export const RegisterClientRequestSchema = z.object({
  device_id: z.string().min(3), driver_id: z.string().min(1),
});
export const RegisterClientResponseSchema = z.object({ client_id: z.string() });

export const PullRequestQuerySchema = z.object({
  client_id: z.string(), cursor: z.string().default('0'),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});
export const PullResponseSchema = z.object({
  changes: z.array(SyncChangeSchema),
  next_cursor: z.string(), server_time: z.string().datetime(),
});

export const RouteStopStatusUpdateOpSchema = z.object({
  client_op_id: z.string().min(8), op_type: z.literal('route_stop.status_update'),
  entity_id: z.string(),
  payload: z.object({
    status: z.enum(['PENDING', 'ARRIVED', 'DELIVERED', 'FAILED']),
    captured_at: z.string().datetime(),
  }),
});

export const ProofOutcomeEnum = z.enum(['DELIVERED', 'PARTIAL', 'NOT_AVAILABLE', 'RETURNED']);
export const PaymentMethodEnum = z.enum(['CASH', 'TELEBIRR']);

export const PaymentPayloadSchema = z.object({
  method: PaymentMethodEnum,
  amount_etb: z.number().positive(),
  telebirr_ref: z.string().min(6).max(40).nullable(),
}).refine(
  (d) => d.method === 'CASH' || (d.telebirr_ref !== null && d.telebirr_ref.trim().length >= 6),
  { message: 'telebirr_ref required for TELEBIRR', path: ['telebirr_ref'] },
);

export const RouteStopProofOpSchema = z.object({
  client_op_id: z.string().min(8), op_type: z.literal('route_stop.proof'),
  entity_id: z.string(),
  payload: z.object({
    outcome: ProofOutcomeEnum,
    qty_confirmed: z.number().int().nonnegative().nullable(),
    qty_ordered: z.number().int().nonnegative().nullable(),
    reason: z.string().max(500).nullable(),
    signature_base64: z.string().max(2_000_000).nullable(),
    photo_base64: z.string().max(3_000_000).nullable(),
    captured_at: z.string().datetime(),
    payment: z.union([PaymentPayloadSchema, z.null()]).optional(),
  }),
});

export const ClientOpSchema = z.discriminatedUnion('op_type', [
  RouteStopStatusUpdateOpSchema, RouteStopProofOpSchema, FuelLogOpSchema,
]);

export const PushRequestSchema = z.object({
  client_id: z.string(), ops: z.array(ClientOpSchema).min(1).max(100),
});
export const OpResultSchema = z.object({
  client_op_id: z.string(),
  status: z.enum(['accepted', 'rejected', 'conflict', 'duplicate']),
  server_cursor: z.string().nullable(), reason: z.string().nullable(),
});
export const PushResponseSchema = z.object({
  results: z.array(OpResultSchema), server_time: z.string().datetime(),
});

export type SyncChange = z.infer<typeof SyncChangeSchema>;
export type ClientOp = z.infer<typeof ClientOpSchema>;
export type ProofOutcome = z.infer<typeof ProofOutcomeEnum>;
export type PaymentMethod = z.infer<typeof PaymentMethodEnum>;
export type PaymentPayload = z.infer<typeof PaymentPayloadSchema>;
export type OpResult = z.infer<typeof OpResultSchema>;
export type PushResponse = z.infer<typeof PushResponseSchema>;
export type PullResponse = z.infer<typeof PullResponseSchema>;
EOF

# Fuel contracts
W packages/contracts/src/fuel.ts <<'EOF'
import { z } from 'zod';

export const VarianceFlagEnum = z.enum(['OK', 'HIGH', 'LOW', 'NO_BASELINE']);

export const FuelLogOpSchema = z.object({
  client_op_id: z.string().min(8), op_type: z.literal('driver.fuel_log'),
  entity_id: z.string(),
  payload: z.object({
    vehicle_id: z.string().min(1),
    liters: z.number().positive(),
    amount_etb: z.number().positive(),
    odometer_km: z.number().positive(),
    station_name: z.string().min(1).max(100),
    station_id: z.string().nullable(),
    captured_at: z.string().datetime(),
  }),
});

export type FuelLogOp = z.infer<typeof FuelLogOpSchema>;
export type VarianceFlag = z.infer<typeof VarianceFlagEnum>;
EOF

# Masterdata contracts
W packages/contracts/src/masterdata.ts <<'EOF'
import { z } from 'zod';

export const DistributorSchema = z.object({
  id: z.string(), name: z.string(), region: z.string(),
  active: z.boolean(),
  created_at: z.string().datetime(), updated_at: z.string().datetime(),
});
export const DistributorsResponseSchema = z.object({ distributors: z.array(DistributorSchema) });

export const VehicleSchema = z.object({
  id: z.string(), plate: z.string(),
  capacity_kg: z.number(), capacity_m3: z.number(),
  shift_start_h: z.number().int(), shift_end_h: z.number().int(),
  start_lat: z.number(), start_lng: z.number(),
  baseline_l_per_100km: z.number().nullable(), active: z.boolean(),
  created_at: z.string().datetime(), updated_at: z.string().datetime(),
});
export const VehiclesResponseSchema = z.object({ vehicles: z.array(VehicleSchema) });

export const SkuSchema = z.object({
  id: z.string(), code: z.string(), name: z.string(), unit: z.string(),
  weight_kg: z.number(), volume_m3: z.number(),
  reorder_point: z.number().int(), safety_stock: z.number().int(), lead_time_days: z.number().int(),
  active: z.boolean(),
  created_at: z.string().datetime(), updated_at: z.string().datetime(),
});
export const SkusResponseSchema = z.object({ skus: z.array(SkuSchema) });

export const CreateDistributorSchema = z.object({
  name: z.string().trim().min(1).max(200), region: z.string().trim().min(1).max(100),
});
export const CreateVehicleSchema = z.object({
  plate: z.string().trim().min(1).max(20),
  capacity_kg: z.number().positive(), capacity_m3: z.number().positive(),
  shift_start_h: z.number().int().min(0).max(23), shift_end_h: z.number().int().min(0).max(23),
  start_lat: z.number().gte(-90).lte(90), start_lng: z.number().gte(-180).lte(180),
  baseline_l_per_100km: z.number().positive().nullable(),
});
export const CreateSkuSchema = z.object({
  code: z.string().trim().min(1).max(40),
  name: z.string().trim().min(1).max(200),
  unit: z.string().trim().min(1).max(20),
  weight_kg: z.number().positive(), volume_m3: z.number().positive(),
  reorder_point: z.number().int().nonnegative().default(0),
  safety_stock: z.number().int().nonnegative().default(0),
  lead_time_days: z.number().int().nonnegative().default(0),
});
export const ToggleActiveSchema = z.object({ active: z.boolean() });

export const MasterdataEntityTypeEnum = z.enum(['distributor', 'vehicle', 'sku']);
export const ImportRequestSchema = z.object({
  type: MasterdataEntityTypeEnum,
  rows: z.array(z.record(z.string())).min(1).max(1000),
});
export const ImportRowResultSchema = z.object({
  row_number: z.number().int(), data: z.record(z.string()),
  status: z.enum(['valid', 'invalid']), errors: z.array(z.string()),
});
export const ValidateImportResponseSchema = z.object({
  type: MasterdataEntityTypeEnum,
  total_rows: z.number().int(), valid_rows: z.number().int(), invalid_rows: z.number().int(),
  rows: z.array(ImportRowResultSchema),
});
export const CommitImportResponseSchema = z.object({
  inserted: z.number().int(), skipped: z.number().int(),
  errors: z.array(z.object({ row_number: z.number().int(), error: z.string() })),
});

export type Distributor = z.infer<typeof DistributorSchema>;
export type Vehicle = z.infer<typeof VehicleSchema>;
export type Sku = z.infer<typeof SkuSchema>;
export type CreateDistributor = z.infer<typeof CreateDistributorSchema>;
export type CreateVehicle = z.infer<typeof CreateVehicleSchema>;
export type CreateSku = z.infer<typeof CreateSkuSchema>;
export type MasterdataEntityType = z.infer<typeof MasterdataEntityTypeEnum>;
export type ImportRowResult = z.infer<typeof ImportRowResultSchema>;
export type ValidateImportResponse = z.infer<typeof ValidateImportResponseSchema>;
export type CommitImportResponse = z.infer<typeof CommitImportResponseSchema>;
EOF

# Analytics
W packages/contracts/src/analytics.ts <<'EOF'
import { z } from 'zod';

export const MetricKeyEnum = z.enum([
  'variable_cost_per_month_etb', 'km_per_delivery', 'median_delivery_hours',
  'on_time_sla_pct', 'stockout_sku_days_per_month', 'dock_turnaround_minutes',
  'reserve_violations_per_100_routes', 'deliveries_per_vehicle_per_day',
  'clean_epod_rate_pct', 'credit_blocked_pre_dispatch_pct',
]);

export const TileSchema = z.object({
  metric_key: MetricKeyEnum, label_key: z.string(), unit: z.string(),
  baseline: z.number(), current: z.number(),
  target_min: z.number(), target_max: z.number(),
  direction: z.enum(['up', 'down']),
  target_mode: z.enum(['relative', 'absolute']),
  improvement_pct: z.number(), in_target: z.boolean(), fully_in_target: z.boolean(),
  trend_7d: z.array(z.number()),
  etb_impact: z.number().nullable(),
});

export const HeroSchema = z.object({
  monthly_savings_etb: z.number(), cumulative_savings_etb: z.number(),
  annualized_savings_etb: z.number(), days_since_baseline: z.number().int(),
});

export const DashboardResponseSchema = z.object({
  as_of: z.string().datetime(),
  baseline_frozen_at: z.string().datetime().nullable(),
  is_demo: z.boolean(),
  hero: HeroSchema.nullable(),
  tiles: z.array(TileSchema),
});

export const FreezeBaselineRequestSchema = z.object({ notes: z.string().max(500).optional() });

export const CostAssumptionSchema = z.object({
  key: z.string(), value: z.number(), unit: z.string(), updated_at: z.string().datetime(),
});
export const CostAssumptionsResponseSchema = z.object({ assumptions: z.array(CostAssumptionSchema) });
export const UpdateCostAssumptionSchema = z.object({ value: z.number() });

export type MetricKey = z.infer<typeof MetricKeyEnum>;
export type Tile = z.infer<typeof TileSchema>;
export type Hero = z.infer<typeof HeroSchema>;
export type DashboardResponse = z.infer<typeof DashboardResponseSchema>;
export type CostAssumption = z.infer<typeof CostAssumptionSchema>;
EOF

# Finance
W packages/contracts/src/finance.ts <<'EOF'
import { z } from 'zod';

export const UnreconciledPaymentSchema = z.object({
  id: z.string(), route_stop_id: z.string(),
  driver_id: z.string(), vehicle_id: z.string(),
  distributor_name: z.string(),
  method: z.enum(['CASH', 'TELEBIRR']),
  amount_etb: z.number(), telebirr_ref: z.string().nullable(),
  captured_at: z.string().datetime(),
});
export const UnreconciledPaymentsResponseSchema = z.object({
  total: z.number().int(), payments: z.array(UnreconciledPaymentSchema),
});
export const ReconcileRequestSchema = z.object({ notes: z.string().max(500).optional() });
export const ReconcileResponseSchema = z.object({
  ok: z.literal(true), reconciled_at: z.string().datetime(),
});

export type UnreconciledPayment = z.infer<typeof UnreconciledPaymentSchema>;
export type UnreconciledPaymentsResponse = z.infer<typeof UnreconciledPaymentsResponseSchema>;
EOF

# Portal
W packages/contracts/src/portal.ts <<'EOF'
import { z } from 'zod';

export const PortalProfileSchema = z.object({
  distributor_id: z.string(), name: z.string(), region: z.string(),
  credit_limit_etb: z.number(), exposure_etb: z.number(),
  headroom_etb: z.number(), utilization_pct: z.number(),
});

export const CatalogItemSchema = z.object({
  sku_id: z.string(), code: z.string(), name: z.string(), unit: z.string(),
  weight_kg: z.number(), volume_m3: z.number(),
  unit_price_etb: z.number(), stock_on_hand: z.number().int(),
});
export const CatalogResponseSchema = z.object({ items: z.array(CatalogItemSchema) });

export const PlaceOrderLineSchema = z.object({
  sku_id: z.string().min(1), quantity: z.number().int().positive(),
});
export const PlaceOrderRequestSchema = z.object({
  lines: z.array(PlaceOrderLineSchema).min(1).max(50),
  note: z.string().max(500).optional(),
});
export const PlaceOrderResponseSchema = z.object({
  order_id: z.string(), status: z.string(),
  total_etb: z.number(), total_quantity: z.number().int(),
  eta: z.string().nullable(),
});

export const OrderStatusEnum = z.enum(['PENDING', 'ROUTED', 'DELIVERED', 'FAILED']);
export const PortalOrderSummarySchema = z.object({
  order_id: z.string(), status: OrderStatusEnum,
  created_at: z.string().datetime(),
  total_etb: z.number(), total_quantity: z.number().int(),
  line_count: z.number().int(), eta: z.string().nullable(),
  vehicle_id: z.string().nullable(), last_stop_status: z.string().nullable(),
});
export const PortalOrdersResponseSchema = z.object({
  active: z.array(PortalOrderSummarySchema), recent: z.array(PortalOrderSummarySchema),
});
export const PortalOrderDetailSchema = PortalOrderSummarySchema.extend({
  driver_id: z.string().nullable(), route_stop_id: z.string().nullable(),
  lines: z.array(z.object({
    sku_id: z.string(), sku_code: z.string(), sku_name: z.string(),
    quantity: z.number().int(), unit_price_etb: z.number(), line_total_etb: z.number(),
  })),
});

export const StatementPaymentRowSchema = z.object({
  id: z.string(), method: z.enum(['CASH', 'TELEBIRR']),
  amount_etb: z.number(), captured_at: z.string().datetime(), reconciled: z.boolean(),
});
export const StatementDeliveryRowSchema = z.object({
  order_id: z.string(), delivered_at: z.string().datetime(),
  total_quantity: z.number().int(), vehicle_id: z.string(),
});
export const StatementResponseSchema = z.object({
  as_of: z.string().datetime(), balance_etb: z.number(), limit_etb: z.number(),
  grace_days: z.number().int(),
  days_since_oldest_unpaid: z.number().int().nullable(),
  recent_payments: z.array(StatementPaymentRowSchema),
  recent_deliveries: z.array(StatementDeliveryRowSchema),
});

export const DisputeTypeEnum = z.enum(['QUANTITY', 'WRONG_ITEM', 'NEVER_DELIVERED', 'DAMAGED', 'OTHER']);
export const RaiseDisputeRequestSchema = z.object({
  order_id: z.string().min(1), type: DisputeTypeEnum,
  description: z.string().trim().min(10).max(1000),
});
export const DisputeRowSchema = z.object({
  id: z.string(), order_id: z.string(), type: DisputeTypeEnum,
  description: z.string(),
  status: z.enum(['OPEN', 'UNDER_REVIEW', 'RESOLVED', 'REJECTED']),
  created_at: z.string().datetime(), resolution_notes: z.string().nullable(),
});
export const DisputesListResponseSchema = z.object({ disputes: z.array(DisputeRowSchema) });

export type PortalProfile = z.infer<typeof PortalProfileSchema>;
export type CatalogItem = z.infer<typeof CatalogItemSchema>;
export type PlaceOrderRequest = z.infer<typeof PlaceOrderRequestSchema>;
export type PlaceOrderResponse = z.infer<typeof PlaceOrderResponseSchema>;
export type PortalOrderSummary = z.infer<typeof PortalOrderSummarySchema>;
export type PortalOrdersResponse = z.infer<typeof PortalOrdersResponseSchema>;
export type PortalOrderDetail = z.infer<typeof PortalOrderDetailSchema>;
export type StatementResponse = z.infer<typeof StatementResponseSchema>;
export type DisputeRow = z.infer<typeof DisputeRowSchema>;
export type RaiseDisputeRequest = z.infer<typeof RaiseDisputeRequestSchema>;
EOF

# Audit
W packages/contracts/src/audit.ts <<'EOF'
import { z } from 'zod';

export const AuditLogEntrySchema = z.object({
  id: z.string(), actor_id: z.string(),
  entity: z.string(), entity_id: z.string(), action: z.string(),
  reason: z.string(), meta: z.record(z.unknown()).nullable(),
  created_at: z.string().datetime(),
});
export const AuditListResponseSchema = z.object({
  total: z.number().int(), entries: z.array(AuditLogEntrySchema),
});
export const AuditFilterQuerySchema = z.object({
  entity: z.string().optional(), actor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

export type AuditLogEntry = z.infer<typeof AuditLogEntrySchema>;
export type AuditListResponse = z.infer<typeof AuditListResponseSchema>;
EOF

# Notify
W packages/contracts/src/notify.ts <<'EOF'
import { z } from 'zod';

export const NotificationChannelEnum = z.enum(['sms', 'telegram', 'email']);
export const NotificationStatusEnum = z.enum(['SENT', 'FAILED', 'STUB']);

export const NotificationLogEntrySchema = z.object({
  id: z.string(), channel: NotificationChannelEnum, recipient: z.string(),
  template_key: z.string(), rendered_body: z.string(),
  status: NotificationStatusEnum, provider_ref: z.string().nullable(),
  error: z.string().nullable(), sent_at: z.string().datetime(),
});
export const NotificationListResponseSchema = z.object({
  total: z.number().int(), entries: z.array(NotificationLogEntrySchema),
});
export const SendNotificationRequestSchema = z.object({
  channel: NotificationChannelEnum, recipient: z.string().min(3).max(200),
  template_key: z.string().min(1).max(60),
  vars: z.record(z.string()).default({}),
});
export const TestSendRequestSchema = z.object({
  channel: NotificationChannelEnum, recipient: z.string().min(3).max(200),
});
export const SendNotificationResponseSchema = z.object({
  id: z.string(), status: NotificationStatusEnum, provider_ref: z.string().nullable(),
});

export type NotificationChannel = z.infer<typeof NotificationChannelEnum>;
export type NotificationLogEntry = z.infer<typeof NotificationLogEntrySchema>;
export type SendNotificationRequest = z.infer<typeof SendNotificationRequestSchema>;
export type TestSendRequest = z.infer<typeof TestSendRequestSchema>;
EOF

# Jobs
W packages/contracts/src/jobs.ts <<'EOF'
import { z } from 'zod';

export const JobKeyEnum = z.enum(['metric_snapshot', 'fuel_variance', 'credit_rebuild']);
export const JobStatusEnum = z.enum(['RUNNING', 'DONE', 'FAILED', 'SKIPPED']);

export const JobRunSchema = z.object({
  id: z.string(), job_key: JobKeyEnum, status: JobStatusEnum,
  started_at: z.string().datetime(), finished_at: z.string().datetime().nullable(),
  duration_ms: z.number().int().nullable(),
  processed_count: z.number().int(), skipped_count: z.number().int(),
  triggered_by: z.string(), error: z.string().nullable(),
});
export const JobRunsResponseSchema = z.object({
  total: z.number().int(), runs: z.array(JobRunSchema),
});
export const JobScheduleEntrySchema = z.object({
  job_key: JobKeyEnum, label_key: z.string(), schedule: z.string(),
  next_run_at: z.string().datetime().nullable(),
  last_run: JobRunSchema.nullable(),
});
export const JobScheduleResponseSchema = z.object({ jobs: z.array(JobScheduleEntrySchema) });
export const RunJobResponseSchema = z.object({
  job_key: JobKeyEnum, enqueued: z.literal(true),
});

export type JobKey = z.infer<typeof JobKeyEnum>;
export type JobStatus = z.infer<typeof JobStatusEnum>;
export type JobRun = z.infer<typeof JobRunSchema>;
export type JobRunsResponse = z.infer<typeof JobRunsResponseSchema>;
export type JobScheduleEntry = z.infer<typeof JobScheduleEntrySchema>;
export type JobScheduleResponse = z.infer<typeof JobScheduleResponseSchema>;
EOF

# Monitoring
W packages/contracts/src/monitoring.ts <<'EOF'
import { z } from 'zod';

export const JobRun24hRowSchema = z.object({
  job: z.string(), status: z.string(), count: z.number().int(),
});
export const MonitoringSnapshotSchema = z.object({
  as_of: z.string().datetime(), uptime_seconds: z.number(),
  http_requests_total: z.number().int(), http_5xx_total: z.number().int(),
  http_error_rate_pct: z.number(),
  solve_jobs_by_status: z.record(z.number().int()),
  solve_duration_avg_ms: z.number(), solve_duration_p95_ms: z.number(),
  pending_orders: z.number().int(),
  unreconciled_payments: z.number().int(),
  stale_sync_clients: z.number().int(),
  high_variance_fuel_logs_7d: z.number().int(),
  job_runs_24h: z.array(JobRun24hRowSchema),
});

export type JobRun24hRow = z.infer<typeof JobRun24hRowSchema>;
export type MonitoringSnapshot = z.infer<typeof MonitoringSnapshotSchema>;
EOF

# Contracts index
W packages/contracts/src/index.ts <<'EOF'
export * from './credit.js';
export * from './geo.js';
export * from './routing.js';
export * from './orders.js';
export * from './route-builder.js';
export * from './dispatch.js';
export * from './sync.js';
export * from './fuel.js';
export * from './masterdata.js';
export * from './analytics.js';
export * from './finance.js';
export * from './portal.js';
export * from './audit.js';
export * from './notify.js';
export * from './jobs.js';
export * from './monitoring.js';
EOF

# ── @tera/i18n (structure; keys applied in Phase 13) ──────
W packages/i18n/package.json <<'EOF'
{
  "name": "@tera/i18n",
  "version": "0.1.0",
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": { "lint": "tsc --noEmit", "test": "vitest run", "build": "tsc -b" },
  "peerDependencies": { "react": ">=18" },
  "dependencies": { "react": "^18.3.0" },
  "devDependencies": { "typescript": "^5.4.0", "vitest": "^1.6.0", "@types/react": "^18.3.0" }
}
EOF
W packages/i18n/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true }, "include": ["src"] }
EOF
W packages/i18n/src/types.ts <<'EOF'
export type Locale = 'am' | 'en' | 'om';
export type TranslateFn = (key: string, vars?: Record<string, string | number>) => string;
EOF
W packages/i18n/src/locales/en.json <<'EOF'
{ "app.name": "Tera OMS" }
EOF
W packages/i18n/src/locales/am.json <<'EOF'
{ "app.name": "ተራ OMS" }
EOF
W packages/i18n/src/locales/om.json <<'EOF'
{ "app.name": "Tera OMS" }
EOF
W packages/i18n/src/format.ts <<'EOF'
import type { Locale } from './types';

const INTL: Record<Locale, string> = { am: 'am-ET', en: 'en-ET', om: 'om-ET' };

export function formatETB(amount: number, locale: Locale = 'am'): string {
  return new Intl.NumberFormat(INTL[locale], {
    style: 'currency', currency: 'ETB',
    maximumFractionDigits: 0, currencyDisplay: 'code',
  }).format(amount);
}
export function formatNumber(n: number, locale: Locale = 'am'): string {
  return new Intl.NumberFormat(INTL[locale]).format(n);
}
export function formatDate(d: Date | string, locale: Locale = 'am'): string {
  const date = typeof d === 'string' ? new Date(d) : d;
  return new Intl.DateTimeFormat(INTL[locale], {
    year: 'numeric', month: 'short', day: 'numeric', timeZone: 'Africa/Addis_Ababa',
  }).format(date);
}
EOF
W packages/i18n/src/I18nProvider.tsx <<'EOF'
import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import type { Locale, TranslateFn } from './types';
import AM from './locales/am.json';
import EN from './locales/en.json';
import OM from './locales/om.json';

const LOCALES: Record<Locale, Record<string, string>> = { am: AM, en: EN, om: OM };
const FALLBACK: Locale = 'en';

interface Ctx { locale: Locale; setLocale: (l: Locale) => void; t: TranslateFn; }
const I18nContext = createContext<Ctx | null>(null);

export function I18nProvider({ children, initialLocale = 'am' }: { children: ReactNode; initialLocale?: Locale }) {
  const [locale, setLocale] = useState<Locale>(initialLocale);
  const value = useMemo<Ctx>(() => {
    const t: TranslateFn = (key, vars) => {
      let s = LOCALES[locale][key] ?? LOCALES[FALLBACK][key] ?? key;
      if (vars) for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, String(v));
      return s;
    };
    return { locale, setLocale, t };
  }, [locale]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}
export function useI18n(): Ctx {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n must be used inside <I18nProvider>');
  return ctx;
}
EOF
W packages/i18n/src/index.ts <<'EOF'
export type { Locale, TranslateFn } from './types';
export { I18nProvider, useI18n } from './I18nProvider';
export { formatETB, formatNumber, formatDate } from './format';
EOF

# ── @tera/ui ─────────────────────────────────────────────
W packages/ui/package.json <<'EOF'
{
  "name": "@tera/ui",
  "version": "0.1.0",
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": { ".": "./src/index.ts", "./tailwind-preset": "./tailwind-preset.cjs" },
  "scripts": { "lint": "tsc --noEmit", "test": "vitest run" },
  "peerDependencies": { "react": ">=18", "react-dom": ">=18" },
  "dependencies": { "react": "^18.3.0", "react-dom": "^18.3.0", "@tera/i18n": "workspace:*" },
  "devDependencies": { "typescript": "^5.4.0", "vitest": "^1.6.0", "@types/react": "^18.3.0", "@types/react-dom": "^18.3.0" }
}
EOF
W packages/ui/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true }, "include": ["src"] }
EOF
W packages/ui/src/tokens.json <<'EOF'
{
  "color": {
    "bg": "#fafaf7", "surface": "#ffffff", "border": "#e5e5e0",
    "text": "#1a1a1a", "muted": "#6b6b6b",
    "primary": "#0f766e", "primaryHover": "#115e59",
    "danger": "#b91c1c", "dangerBg": "#fef2f2",
    "warn": "#b45309", "warnBg": "#fffbeb",
    "success": "#166534", "successBg": "#f0fdf4"
  },
  "radius": { "sm": "6px", "md": "10px", "lg": "14px" },
  "font": {
    "sans": "\"Noto Sans Ethiopic\", \"Noto Sans\", system-ui, sans-serif",
    "mono": "ui-monospace, \"SF Mono\", Menlo, monospace"
  }
}
EOF
W packages/ui/tailwind-preset.cjs <<'EOF'
const tokens = require('./src/tokens.json');
module.exports = {
  theme: {
    extend: {
      colors: tokens.color,
      fontFamily: { sans: tokens.font.sans, mono: tokens.font.mono },
      borderRadius: tokens.radius,
    },
  },
};
EOF
W packages/ui/src/components/Button.tsx <<'EOF'
import type { ButtonHTMLAttributes, ReactNode } from 'react';
type Variant = 'primary' | 'secondary' | 'danger' | 'ghost';
type Size = 'sm' | 'md' | 'lg';
interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant; size?: Size; loading?: boolean; children: ReactNode;
}
const base = 'inline-flex items-center justify-center font-medium rounded-md transition disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary';
const v: Record<Variant, string> = {
  primary: 'bg-primary text-white hover:bg-primaryHover',
  secondary: 'bg-white border border-border text-text hover:bg-bg',
  danger: 'bg-danger text-white hover:opacity-90',
  ghost: 'text-text hover:bg-bg',
};
const s: Record<Size, string> = {
  sm: 'text-sm px-3 py-1.5 gap-1.5',
  md: 'text-sm px-4 py-2 gap-2',
  lg: 'text-base px-6 py-3 gap-2',
};
export function Button({ variant = 'primary', size = 'md', loading = false, disabled, children, className = '', ...rest }: Props) {
  return (
    <button {...rest} disabled={disabled || loading} className={`${base} ${v[variant]} ${s[size]} ${className}`}>
      {loading && <span className="inline-block w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />}
      {children}
    </button>
  );
}
EOF
W packages/ui/src/components/StatusPill.tsx <<'EOF'
import type { ReactNode } from 'react';
type Tone = 'danger' | 'warn' | 'success' | 'neutral';
const tone: Record<Tone, string> = {
  danger: 'bg-dangerBg text-danger border-danger/30',
  warn: 'bg-warnBg text-warn border-warn/30',
  success: 'bg-successBg text-success border-success/30',
  neutral: 'bg-bg text-muted border-border',
};
export function StatusPill({ tone: t, children }: { tone: Tone; children: ReactNode }) {
  return <span className={`inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full border ${tone[t]}`}>{children}</span>;
}
EOF
W packages/ui/src/components/Money.tsx <<'EOF'
import { useI18n, formatETB } from '@tera/i18n';
export function Money({ value, bold = false }: { value: number; bold?: boolean }) {
  const { locale } = useI18n();
  return <span className={`tabular-nums ${bold ? 'font-semibold' : ''}`}>{formatETB(value, locale)}</span>;
}
EOF
W packages/ui/src/components/DataTable.tsx <<'EOF'
import type { ReactNode } from 'react';
export interface Column<T> {
  key: string; header: ReactNode;
  render: (row: T) => ReactNode;
  align?: 'left' | 'right' | 'center'; width?: string;
}
interface Props<T> {
  columns: Column<T>[]; rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  emptyMessage: ReactNode;
}
export function DataTable<T>({ columns, rows, rowKey, onRowClick, emptyMessage }: Props<T>) {
  if (rows.length === 0) return <div className="border border-border rounded-md bg-surface px-6 py-10 text-center text-muted text-sm">{emptyMessage}</div>;
  return (
    <div className="border border-border rounded-md bg-surface overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-bg border-b border-border">
          <tr>{columns.map((c) => (
            <th key={c.key} style={c.width ? { width: c.width } : undefined} className={`px-4 py-3 font-medium text-muted text-${c.align ?? 'left'}`}>{c.header}</th>
          ))}</tr>
        </thead>
        <tbody>{rows.map((row) => (
          <tr key={rowKey(row)} onClick={onRowClick ? () => onRowClick(row) : undefined}
              className={`border-b border-border last:border-0 ${onRowClick ? 'cursor-pointer hover:bg-bg' : ''}`}>
            {columns.map((c) => <td key={c.key} className={`px-4 py-3 text-${c.align ?? 'left'}`}>{c.render(row)}</td>)}
          </tr>
        ))}</tbody>
      </table>
    </div>
  );
}
EOF
W packages/ui/src/components/Spinner.tsx <<'EOF'
export function Spinner({ label }: { label?: string }) {
  return (
    <div className="flex items-center gap-2 text-muted text-sm" role="status">
      <span className="inline-block w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
      {label ?? 'Loading…'}
    </div>
  );
}
EOF
W packages/ui/src/components/EmptyState.tsx <<'EOF'
import type { ReactNode } from 'react';
export function EmptyState({ icon, title, hint }: { icon?: ReactNode; title: ReactNode; hint?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center py-12 px-6 text-center">
      {icon && <div className="mb-3 text-muted">{icon}</div>}
      <p className="font-medium text-text">{title}</p>
      {hint && <p className="text-muted text-sm mt-1">{hint}</p>}
    </div>
  );
}
EOF
W packages/ui/src/index.ts <<'EOF'
export { Button } from './components/Button';
export { StatusPill } from './components/StatusPill';
export { Money } from './components/Money';
export { DataTable, type Column } from './components/DataTable';
export { Spinner } from './components/Spinner';
export { EmptyState } from './components/EmptyState';
EOF

# ── @tera/solver (VRP package) ──────────────────────────
W packages/solver/package.json <<'EOF'
{
  "name": "@tera/solver",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": { "lint": "tsc --noEmit", "test": "vitest run" },
  "devDependencies": { "typescript": "^5.4.0", "vitest": "^1.6.0" }
}
EOF
W packages/solver/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true }, "include": ["src"] }
EOF
W packages/solver/src/types.ts <<'EOF'
export interface Point { lat: number; lng: number }
export interface Polygon { type: 'Polygon'; coordinates: [number, number][][] }
export interface SolveOrder extends Point {
  id: string; distributor_name: string;
  weight_kg: number; volume_m3: number; priority: number;
  time_window_start: string; time_window_end: string;
}
export interface SolveVehicle extends Point {
  id: string; capacity_kg: number; capacity_m3: number;
  shift_start_h: number; shift_end_h: number;
}
export interface CurfewZone { id: string; name: string; polygon: Polygon; start_hour: number; end_hour: number; }
export interface SolveConstraints {
  curfew_zones: CurfewZone[];
  avg_speed_kmh?: number; service_min_per_stop?: number;
}
export interface SolveStop {
  order_id: string; distributor_name: string; seq: number;
  eta: string; lat: number; lng: number;
}
export interface SolveSequence { stops: SolveStop[]; total_km: number; total_min: number; }
export interface Infeasible { order_id: string; reason: string; }
export interface SolveResult {
  manual: SolveSequence; optimized: SolveSequence;
  savings_km_pct: number; savings_time_pct: number;
  infeasible: Infeasible | null;
}
EOF
W packages/solver/src/geo.ts <<'EOF'
import type { Point, Polygon } from './types.js';
const R_KM = 6371;
export function haversineKm(a: Point, b: Point): number {
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const x = Math.sin(dLat / 2) ** 2 + Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * R_KM * Math.asin(Math.sqrt(x));
}
export function pointInPolygon(point: Point, polygon: Polygon): boolean {
  const ring = polygon.coordinates[0];
  if (!ring || ring.length < 3) return false;
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i]!;
    const [xj, yj] = ring[j]!;
    const intersect = yi > point.lat !== yj > point.lat && point.lng < ((xj - xi) * (point.lat - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}
export function hourInWindow(hour: number, start: number, end: number): boolean {
  if (start <= end) return hour >= start && hour < end;
  return hour >= start || hour < end;
}
EOF
W packages/solver/src/algorithms.ts <<'EOF'
import { haversineKm } from './geo.js';
import type { Point, SolveOrder } from './types.js';
export function naiveSequence(orders: SolveOrder[]): SolveOrder[] {
  return [...orders].sort((a, b) => a.time_window_start.localeCompare(b.time_window_start));
}
export function nearestNeighbor(orders: SolveOrder[], depot: Point): number[] {
  const remaining = new Set(orders.map((_, i) => i));
  const sequence: number[] = [];
  let current: Point = depot;
  while (remaining.size > 0) {
    let bestIdx = -1; let bestDist = Infinity;
    for (const i of remaining) {
      const d = haversineKm(current, orders[i]!);
      if (d < bestDist) { bestDist = d; bestIdx = i; }
    }
    remaining.delete(bestIdx);
    sequence.push(bestIdx);
    current = orders[bestIdx]!;
  }
  return sequence;
}
export function twoOpt(points: SolveOrder[], order: number[], maxIterations = 200): number[] {
  let best = [...order];
  let improved = true;
  let iter = 0;
  while (improved && iter < maxIterations) {
    improved = false;
    for (let i = 0; i < best.length - 1; i++) {
      for (let j = i + 2; j < best.length; j++) {
        const a = i > 0 ? points[best[i - 1]!]! : null;
        const b = points[best[i]!]!;
        const c = points[best[j]!]!;
        const d = j < best.length - 1 ? points[best[j + 1]!]! : null;
        const before = (a ? haversineKm(a, b) : 0) + (d ? haversineKm(c, d) : 0);
        const after = (a ? haversineKm(a, c) : 0) + (d ? haversineKm(b, d) : 0);
        if (after + 1e-9 < before) {
          best = [...best.slice(0, i), ...best.slice(i, j + 1).reverse(), ...best.slice(j + 1)];
          improved = true;
        }
      }
    }
    iter++;
  }
  return best;
}
EOF
W packages/solver/src/solve.ts <<'EOF'
import { haversineKm, pointInPolygon, hourInWindow } from './geo.js';
import { nearestNeighbor, twoOpt, naiveSequence } from './algorithms.js';
import type { SolveOrder, SolveVehicle, SolveConstraints, SolveResult, SolveSequence, Infeasible, SolveStop } from './types.js';
const DEFAULT_SPEED_KMH = 25;
const DEFAULT_SERVICE_MIN = 10;
interface SequenceInput { orders: SolveOrder[]; vehicle: SolveVehicle; constraints: SolveConstraints; }
function sequenceToResult(input: SequenceInput, order: SolveOrder[]): { result: SolveSequence; infeasible: Infeasible | null } {
  const { vehicle, constraints } = input;
  const speed = constraints.avg_speed_kmh ?? DEFAULT_SPEED_KMH;
  const service = constraints.service_min_per_stop ?? DEFAULT_SERVICE_MIN;
  const stops: SolveStop[] = [];
  let totalKm = 0;
  let clock = new Date();
  clock.setHours(vehicle.shift_start_h, 0, 0, 0);
  let prev: { lat: number; lng: number } = vehicle;
  for (let i = 0; i < order.length; i++) {
    const o = order[i]!;
    const km = haversineKm(prev, o);
    totalKm += km;
    const legMin = (km / speed) * 60;
    clock = new Date(clock.getTime() + legMin * 60_000);
    const eta = new Date(clock);
    const twStart = new Date(o.time_window_start);
    const twEnd = new Date(o.time_window_end);
    if (eta < twStart || eta > twEnd) {
      return { result: { stops: [], total_km: 0, total_min: 0 }, infeasible: { order_id: o.id, reason: `ETA ${eta.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })} outside window` } };
    }
    for (const zone of constraints.curfew_zones) {
      if (pointInPolygon(o, zone.polygon) && hourInWindow(eta.getHours(), zone.start_hour, zone.end_hour)) {
        return { result: { stops: [], total_km: 0, total_min: 0 }, infeasible: { order_id: o.id, reason: `curfew "${zone.name}"` } };
      }
    }
    stops.push({ order_id: o.id, distributor_name: o.distributor_name, seq: i + 1, eta: eta.toISOString(), lat: o.lat, lng: o.lng });
    prev = o;
    clock = new Date(clock.getTime() + service * 60_000);
  }
  return { result: { stops, total_km: round(totalKm), total_min: Math.round((totalKm / speed) * 60) }, infeasible: null };
}
export function solve(orders: SolveOrder[], vehicle: SolveVehicle, constraints: SolveConstraints): SolveResult {
  if (orders.length === 0) {
    const empty: SolveSequence = { stops: [], total_km: 0, total_min: 0 };
    return { manual: empty, optimized: empty, savings_km_pct: 0, savings_time_pct: 0, infeasible: null };
  }
  const input: SequenceInput = { orders, vehicle, constraints };
  const manualSeq = sequenceToResult(input, naiveSequence(orders));
  const nn = nearestNeighbor(orders, vehicle);
  const improved = twoOpt(orders, nn);
  const optimizedSeq = sequenceToResult(input, improved.map((i) => orders[i]!));
  const infeasible = optimizedSeq.infeasible ?? manualSeq.infeasible;
  const manualKm = manualSeq.result.total_km;
  const optKm = optimizedSeq.result.total_km;
  const manualMin = manualSeq.result.total_min;
  const optMin = optimizedSeq.result.total_min;
  return {
    manual: manualSeq.result, optimized: optimizedSeq.result,
    savings_km_pct: manualKm > 0 ? round(((manualKm - optKm) / manualKm) * 100) : 0,
    savings_time_pct: manualMin > 0 ? round(((manualMin - optMin) / manualMin) * 100) : 0,
    infeasible,
  };
}
function round(n: number): number { return Math.round(n * 100) / 100; }
EOF
W packages/solver/src/index.ts <<'EOF'
export { solve } from './solve.js';
export { haversineKm, pointInPolygon, hourInWindow } from './geo.js';
export { nearestNeighbor, twoOpt, naiveSequence } from './algorithms.js';
export type * from './types.js';
EOF

echo ""
echo "✓ Phase 0 — Scaffold complete (files written to disk)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📌 Part 1a of 3: Phases 0 (scaffold) complete."
echo "   The script continues with Phase 1 (credit) and Phase 2"
echo "   (dispatcher) in the next message."
echo ""
echo "   What's written so far:"
echo "   • Root config: package.json, tsconfig, docker-compose, Makefile, .env.example, CI"
echo "   • All 16 Prisma models (credit, geo, orders, routing, dispatch, sync, proof,"
echo "     payment, fuel, disputes, analytics, audit, notify, solve-job, job-run, masterdata)"
echo "   • All 16 contracts files (Zod schemas)"
echo "   • Shared packages: @tera/i18n, @tera/ui, @tera/solver"
echo "   • Docs, infra, experiments, scripts/, seeds/, CI"
echo ""
echo "   Do NOT run this file yet — it's incomplete (missing backend services,"
echo "   frontends, and API wiring). Wait for Part 1b + 1c which will finish"
echo "   Phases 1-2."
echo ""
echo "════════════════════════════════════════════════════════════════"