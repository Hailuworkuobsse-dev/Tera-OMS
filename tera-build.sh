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

# ═══════════════════════════════════════════════════════════════════
# PHASE 1 — API INFRASTRUCTURE + CREDIT MODULE
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 1 — API + credit module"

W services/api/package.json <<'EOF'
{
  "name": "@tera/api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/server.ts",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc -b",
    "start": "node dist/server.js",
    "lint": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "@fastify/cors": "^9.0.0",
    "@fastify/jwt": "^8.0.0",
    "@fastify/sensible": "^5.0.0",
    "@fastify/swagger": "^8.14.0",
    "@fastify/swagger-ui": "^4.0.0",
    "@prisma/client": "^6.0.0",
    "@tera/contracts": "workspace:*",
    "@tera/db": "workspace:*",
    "@tera/solver": "workspace:*",
    "bullmq": "^5.8.0",
    "fastify": "^4.28.0",
    "fastify-plugin": "^4.5.0",
    "ioredis": "^5.4.0",
    "pino": "^9.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/node": "^20.12.0",
    "tsx": "^4.7.0",
    "typescript": "^5.4.0",
    "vitest": "^1.6.0"
  }
}
EOF

W services/api/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true, "noEmit": false }, "include": ["src"] }
EOF

W services/api/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
RUN corepack enable
COPY package.json ./
RUN pnpm install --prod=false
COPY src ./src
CMD ["pnpm", "tsx", "src/server.ts"]
EOF

W services/api/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { environment: 'node', globals: true } });
EOF

W services/api/src/config.ts <<'EOF'
import { z } from 'zod';

const Env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z.string().default('info'),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(16),
  JWT_TTL_MIN: z.coerce.number().default(60),
});

export const config = Env.parse(process.env);
EOF

W services/api/src/core/events.ts <<'EOF'
import { EventEmitter } from 'node:events';
export const bus = new EventEmitter();
EOF

W services/api/src/core/errors.ts <<'EOF'
export class DomainError extends Error {
  constructor(public code: string, message: string, public status = 400) { super(message); }
}
EOF

W services/api/src/core/audit.ts <<'EOF'
import { db } from '@tera/db';

export interface AuditEntry {
  actorId: string;
  entity: string;
  entityId: string;
  action: string;
  reason: string;
  meta?: Record<string, unknown>;
}

export async function writeAudit(entry: AuditEntry): Promise<void> {
  await db().auditLog.create({
    data: {
      actorId: entry.actorId,
      entity: entry.entity,
      entityId: entry.entityId,
      action: entry.action,
      reason: entry.reason,
      metaJson: (entry.meta ?? undefined) as any,
    },
  });
}
EOF

W services/api/src/plugins/errorHandler.ts <<'EOF'
import type { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';

export function errorHandler(err: FastifyError | ZodError, _req: FastifyRequest, reply: FastifyReply) {
  if (err instanceof ZodError) {
    return reply.status(400).send({ code: 'validation', message: 'invalid request', issues: err.issues });
  }
  const status = (err as any).statusCode ?? 500;
  return reply.status(status).send({ code: (err as any).code ?? 'internal', message: err.message });
}
EOF

W services/api/src/plugins/auth.ts <<'EOF'
import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import { config } from '../config.js';

export const authPlugin = fp(async (app) => {
  await app.register(jwt, { secret: config.JWT_SECRET });
});
EOF

# ── config module ─────────────────────────────────────────
W services/api/src/modules/config/service.ts <<'EOF'
import { db } from '@tera/db';

export async function getFlag(key: string, defaultValue: boolean): Promise<boolean> {
  const row = await db().setting.findUnique({ where: { key } });
  if (!row) return defaultValue;
  return row.value === 'true';
}
EOF
W services/api/src/modules/config/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
export const configPlugin: FastifyPluginAsync = async (_app) => {};
export default configPlugin;
EOF

# ── credit: pure rules ─────────────────────────────────────
W services/api/src/modules/credit/rules.ts <<'EOF'
export type Decision = 'BLOCKED' | 'WARNED' | 'CLEARED';
export type Reason = 'OVER_LIMIT' | 'PAST_GRACE' | 'BOTH' | 'NONE';

export interface RuleInput {
  exposureEtb: number;
  limitEtb: number;
  daysOverdue: number;
  graceDays: number;
}

export interface RuleResult {
  triggered: boolean;
  reason: Reason;
  overLimit: boolean;
  pastGrace: boolean;
}

export function evaluateRule(input: RuleInput): RuleResult {
  const overLimit = input.exposureEtb > input.limitEtb;
  const pastGrace = input.daysOverdue > input.graceDays;
  if (overLimit && pastGrace) return { triggered: true, reason: 'BOTH', overLimit, pastGrace };
  if (overLimit) return { triggered: true, reason: 'OVER_LIMIT', overLimit, pastGrace };
  if (pastGrace) return { triggered: true, reason: 'PAST_GRACE', overLimit, pastGrace };
  return { triggered: false, reason: 'NONE', overLimit, pastGrace };
}

export function decide(triggered: boolean, hasOverride: boolean, hardGate: boolean): Decision {
  if (!triggered) return 'CLEARED';
  if (hasOverride) return 'WARNED';
  return hardGate ? 'BLOCKED' : 'WARNED';
}
EOF

# ── credit: pure finance helpers ───────────────────────────
W services/api/src/modules/credit/finance.ts <<'EOF'
export type AgingBucketLabel = 'current' | 'watch' | 'overdue' | 'critical';

export function bucketForDaysOverdue(daysOverdue: number): AgingBucketLabel {
  if (daysOverdue <= 0) return 'current';
  if (daysOverdue <= 14) return 'watch';
  if (daysOverdue <= 30) return 'overdue';
  return 'critical';
}

export interface RawAccount {
  distributorId: string;
  distributorName: string;
  region: string;
  limitEtb: number;
  exposureEtb: number;
  oldestUnpaidAt: Date | null;
  graceDays: number;
}

export interface EnrichedAccount {
  distributor_id: string;
  distributor_name: string;
  region: string;
  exposure_etb: number;
  limit_etb: number;
  utilization_pct: number;
  days_since_oldest_unpaid: number;
  grace_days: number;
  days_overdue: number;
}

export function enrichAccount(a: RawAccount, now: Date = new Date()): EnrichedAccount {
  const daysSince = a.oldestUnpaidAt
    ? Math.floor((now.getTime() - a.oldestUnpaidAt.getTime()) / 86_400_000)
    : 0;
  const daysOverdue = Math.max(0, daysSince - a.graceDays);
  const utilization = a.limitEtb > 0 ? (a.exposureEtb / a.limitEtb) * 100 : 0;
  return {
    distributor_id: a.distributorId,
    distributor_name: a.distributorName,
    region: a.region,
    exposure_etb: Math.round(a.exposureEtb),
    limit_etb: Math.round(a.limitEtb),
    utilization_pct: Math.round(utilization * 100) / 100,
    days_since_oldest_unpaid: daysSince,
    grace_days: a.graceDays,
    days_overdue: daysOverdue,
  };
}
EOF

# ── credit: repository ─────────────────────────────────────
W services/api/src/modules/credit/repository.ts <<'EOF'
import { db } from '@tera/db';

export function findAccounts() {
  return db().creditAccount.findMany({
    include: {
      distributor: { select: { id: true, name: true, region: true } },
      overrides: { where: { expiresAt: { gt: new Date() } } },
    },
    orderBy: { createdAt: 'asc' },
  });
}

export function findAllAccountsForFinance() {
  return db().creditAccount.findMany({
    include: { distributor: { select: { name: true, region: true } } },
    orderBy: { updatedAt: 'desc' },
  });
}

export function findAllOverrides(limit: number) {
  return db().creditOverride.findMany({ orderBy: { createdAt: 'desc' }, take: limit });
}

export function findDistributorsByIds(ids: string[]) {
  return db().distributor.findMany({
    where: { id: { in: ids } },
    select: { id: true, name: true },
  });
}

export function recordDecision(input: {
  accountId: string; outcome: string; reason: string;
  exposureEtb: number; limitEtb: number; daysOverdue: number;
}) {
  return db().creditDecision.create({ data: input });
}

export function createOverride(input: {
  decisionId?: string; distributorId: string;
  reason: string; actorId: string; expiresAt: Date;
}) {
  return db().creditOverride.create({ data: input });
}
EOF

# ── credit: service ────────────────────────────────────────
W services/api/src/modules/credit/service.ts <<'EOF'
import { getFlag } from '../config/service.js';
import { writeAudit } from '../../core/audit.js';
import * as repo from './repository.js';
import { evaluateRule, decide } from './rules.js';
import { enrichAccount, bucketForDaysOverdue, type RawAccount } from './finance.js';
import type {
  CreditStopRow, CreditStopListResponse,
  ExposureResponse, AgingBucket,
  OverridesListResponse, OverrideRow,
} from '@tera/contracts';

export async function getStopList(): Promise<CreditStopListResponse> {
  const hardGate = await getFlag('credit.hardGate', false);
  const accounts = await repo.findAccounts();
  const now = Date.now();
  const rows: CreditStopRow[] = [];

  for (const a of accounts) {
    const limitEtb = Number(a.limitEtb);
    const exposureEtb = Number(a.exposureEtb);
    const daysOverdue = a.oldestUnpaidAt
      ? Math.floor((now - a.oldestUnpaidAt.getTime()) / 86_400_000)
      : 0;
    const trigger = evaluateRule({ exposureEtb, limitEtb, daysOverdue, graceDays: a.graceDays });
    const override = a.overrides[0];
    const decision = decide(trigger.triggered, Boolean(override), hardGate);
    if (decision === 'CLEARED') continue;

    rows.push({
      distributor_id: a.distributorId,
      distributor_name: a.distributor.name,
      region: a.distributor.region,
      decision,
      reason: trigger.reason,
      amount_owed_etb: exposureEtb,
      credit_limit_etb: limitEtb,
      exposure_etb: exposureEtb,
      days_overdue: daysOverdue,
      grace_days: a.graceDays,
      blocked_at: a.updatedAt.toISOString(),
      active_override_until: override ? override.expiresAt.toISOString() : null,
    });

    void repo.recordDecision({
      accountId: a.id, outcome: decision, reason: trigger.reason,
      exposureEtb, limitEtb, daysOverdue,
    });
  }

  const order: Record<string, number> = { BLOCKED: 0, WARNED: 1, CLEARED: 2 };
  rows.sort((x, y) => {
    const d = order[x.decision]! - order[y.decision]!;
    return d !== 0 ? d : y.amount_owed_etb - x.amount_owed_etb;
  });

  return { as_of: new Date().toISOString(), hard_gate: hardGate, rows };
}

export async function createOverride(input: {
  distributorId: string; reason: string; actorId: string; expiresAt: Date;
}): Promise<{ expiresAt: Date }> {
  if (input.expiresAt.getTime() <= Date.now()) {
    const err = new Error('expires_at must be in the future') as any;
    err.statusCode = 400; throw err;
  }
  const override = await repo.createOverride(input);
  await writeAudit({
    actorId: input.actorId, entity: 'credit_override', entityId: override.id,
    action: 'create', reason: input.reason,
    meta: { distributorId: input.distributorId, expiresAt: input.expiresAt.toISOString() },
  });
  return { expiresAt: override.expiresAt };
}

export async function getExposure(): Promise<ExposureResponse> {
  const rows = await repo.findAllAccountsForFinance();
  const enriched = rows.map((a) => enrichAccount({
    distributorId: a.distributorId,
    distributorName: a.distributor.name,
    region: a.distributor.region,
    limitEtb: Number(a.limitEtb),
    exposureEtb: Number(a.exposureEtb),
    oldestUnpaidAt: a.oldestUnpaidAt,
    graceDays: a.graceDays,
  }));

  const totalExposure = enriched.reduce((s, a) => s + a.exposure_etb, 0);
  const totalLimit = enriched.reduce((s, a) => s + a.limit_etb, 0);

  const bucketDefs: { label: AgingBucket['label']; range: string }[] = [
    { label: 'current',  range: '0 days overdue' },
    { label: 'watch',    range: '1–14 days' },
    { label: 'overdue',  range: '15–30 days' },
    { label: 'critical', range: '31+ days' },
  ];

  const agingBuckets: AgingBucket[] = bucketDefs.map((b) => {
    const members = enriched.filter((a) => bucketForDaysOverdue(a.days_overdue) === b.label);
    return {
      label: b.label, days_range: b.range,
      account_count: members.length,
      exposure_etb: members.reduce((s, a) => s + a.exposure_etb, 0),
    };
  });

  const nearLimit = enriched
    .filter((a) => a.limit_etb > 0 && a.exposure_etb / a.limit_etb >= 0.8)
    .sort((a, b) => b.utilization_pct - a.utilization_pct);

  return {
    as_of: new Date().toISOString(),
    total_exposure_etb: Math.round(totalExposure),
    total_limit_etb: Math.round(totalLimit),
    utilization_pct: totalLimit > 0 ? Math.round((totalExposure / totalLimit) * 10000) / 100 : 0,
    accounts_over_limit: enriched.filter((a) => a.exposure_etb > a.limit_etb).length,
    accounts_past_grace: enriched.filter((a) => a.days_overdue > 0).length,
    aging_buckets: agingBuckets,
    near_limit_accounts: nearLimit,
    all_accounts: [...enriched].sort((a, b) => b.exposure_etb - a.exposure_etb),
  };
}

export async function listOverrides(limit = 100): Promise<OverridesListResponse> {
  const rows = await repo.findAllOverrides(limit);
  const distributorIds = Array.from(new Set(rows.map((r) => r.distributorId)));
  const distributors = await repo.findDistributorsByIds(distributorIds);
  const nameById = new Map(distributors.map((d) => [d.id, d.name]));
  const now = Date.now();

  const overrides: OverrideRow[] = rows.map((o) => ({
    id: o.id,
    distributor_id: o.distributorId,
    distributor_name: nameById.get(o.distributorId) ?? '(unknown)',
    reason: o.reason, actor_id: o.actorId,
    created_at: o.createdAt.toISOString(),
    expires_at: o.expiresAt.toISOString(),
    expired: o.expiresAt.getTime() < now,
  }));

  return { total: overrides.length, overrides };
}
EOF

W services/api/src/modules/credit/schemas.ts <<'EOF'
export {
  CreditStopListResponseSchema, OverrideRequestSchema, OverrideResponseSchema,
  CreditStopRowSchema, CreditDecisionEnum, CreditReasonEnum,
  ExposureResponseSchema, ExposureAccountSchema, AgingBucketSchema, AgingBucketLabelEnum,
  OverridesListResponseSchema, OverrideRowSchema,
} from '@tera/contracts';
EOF

W services/api/src/modules/credit/events.ts <<'EOF'
import { bus } from '../../core/events.js';
export function emitCreditOverridden(payload: { distributorId: string; expiresAt: string; actorId: string }): void {
  bus.emit('credit.overridden', payload);
}
EOF

W services/api/src/modules/credit/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import {
  CreditStopListResponseSchema, OverrideRequestSchema, OverrideResponseSchema,
  ExposureResponseSchema, OverridesListResponseSchema,
} from './schemas.js';
import * as service from './service.js';
import { emitCreditOverridden } from './events.js';

export const creditRoutes: FastifyPluginAsync = async (app) => {
  app.get('/stop-list', {
    schema: { response: { 200: CreditStopListResponseSchema as any } },
  }, async () => service.getStopList());

  app.post('/overrides', {
    schema: { body: OverrideRequestSchema as any, response: { 200: OverrideResponseSchema as any } },
  }, async (req: any) => {
    const actorId = req.user?.sub ?? 'system';
    const result = await service.createOverride({
      distributorId: req.body.distributor_id,
      reason: req.body.reason,
      actorId,
      expiresAt: new Date(req.body.expires_at),
    });
    emitCreditOverridden({
      distributorId: req.body.distributor_id,
      expiresAt: result.expiresAt.toISOString(),
      actorId,
    });
    return { ok: true as const, expires_at: result.expiresAt.toISOString() };
  });

  app.get('/exposure', {
    schema: { response: { 200: ExposureResponseSchema as any } },
  }, async () => service.getExposure());

  app.get('/overrides/list', {
    schema: { response: { 200: OverridesListResponseSchema as any } },
  }, async (req: any) => {
    const limit = req.query?.limit ? parseInt(req.query.limit, 10) : 100;
    return service.listOverrides(limit);
  });
};
EOF

W services/api/src/modules/credit/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { creditRoutes } from './routes.js';
export const creditPlugin: FastifyPluginAsync = async (app) => { await app.register(creditRoutes); };
export default creditPlugin;
EOF

W services/api/src/modules/credit/__tests__/rules.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { evaluateRule, decide } from '../rules.js';

describe('evaluateRule', () => {
  it('clears under limit and inside grace', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 3, graceDays: 14 });
    expect(r.triggered).toBe(false);
    expect(r.reason).toBe('NONE');
  });
  it('triggers OVER_LIMIT', () => {
    const r = evaluateRule({ exposureEtb: 120, limitEtb: 100, daysOverdue: 0, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('OVER_LIMIT');
  });
  it('triggers PAST_GRACE', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 20, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('PAST_GRACE');
  });
  it('triggers BOTH', () => {
    const r = evaluateRule({ exposureEtb: 120, limitEtb: 100, daysOverdue: 30, graceDays: 14 });
    expect(r.triggered).toBe(true);
    expect(r.reason).toBe('BOTH');
  });
  it('grace boundary is inclusive (not > graceDays)', () => {
    const r = evaluateRule({ exposureEtb: 50, limitEtb: 100, daysOverdue: 14, graceDays: 14 });
    expect(r.triggered).toBe(false);
  });
});

describe('decide', () => {
  it('CLEARED when not triggered', () => expect(decide(false, false, true)).toBe('CLEARED'));
  it('WARNED in soft mode', () => expect(decide(true, false, false)).toBe('WARNED'));
  it('BLOCKED in hard mode', () => expect(decide(true, false, true)).toBe('BLOCKED'));
  it('WARNED when override present', () => expect(decide(true, true, true)).toBe('WARNED'));
});
EOF

W services/api/src/modules/credit/__tests__/finance.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { bucketForDaysOverdue, enrichAccount } from '../finance.js';

describe('bucketForDaysOverdue', () => {
  it('current at 0 or negative', () => {
    expect(bucketForDaysOverdue(0)).toBe('current');
    expect(bucketForDaysOverdue(-3)).toBe('current');
  });
  it('watch 1-14', () => {
    expect(bucketForDaysOverdue(1)).toBe('watch');
    expect(bucketForDaysOverdue(14)).toBe('watch');
  });
  it('overdue 15-30', () => {
    expect(bucketForDaysOverdue(15)).toBe('overdue');
    expect(bucketForDaysOverdue(30)).toBe('overdue');
  });
  it('critical 31+', () => {
    expect(bucketForDaysOverdue(31)).toBe('critical');
  });
});

describe('enrichAccount', () => {
  const NOW = new Date('2026-04-12T12:00:00.000Z');
  it('computes utilization and days_overdue', () => {
    const r = enrichAccount({
      distributorId: 'd1', distributorName: 'A', region: 'Addis',
      limitEtb: 100_000, exposureEtb: 120_000,
      oldestUnpaidAt: new Date('2026-03-01T00:00:00.000Z'), graceDays: 14,
    }, NOW);
    expect(r.utilization_pct).toBe(120);
    expect(r.days_overdue).toBe(28); // 42 days - 14 grace
  });
  it('null oldest => 0 days overdue', () => {
    const r = enrichAccount({
      distributorId: 'd', distributorName: 'A', region: 'A',
      limitEtb: 100, exposureEtb: 10, oldestUnpaidAt: null, graceDays: 14,
    }, NOW);
    expect(r.days_since_oldest_unpaid).toBe(0);
    expect(r.days_overdue).toBe(0);
  });
  it('zero limit => 0%', () => {
    const r = enrichAccount({
      distributorId: 'd', distributorName: 'A', region: 'A',
      limitEtb: 0, exposureEtb: 5000, oldestUnpaidAt: null, graceDays: 14,
    }, NOW);
    expect(r.utilization_pct).toBe(0);
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 2 — GEO + ORDERS + ROUTING MODULES
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 2 — geo + orders + routing modules"

# ── geo: pure validation ───────────────────────────────────
W services/api/src/modules/geo/validation.ts <<'EOF'
export interface GeoJsonPolygon {
  type: 'Polygon';
  coordinates: [number, number][][];
}

export function validateGeoJsonPolygon(polygon: unknown): string[] {
  const errors: string[] = [];
  if (!polygon || typeof polygon !== 'object') return ['polygon must be an object'];
  const p = polygon as Partial<GeoJsonPolygon>;
  if (p.type !== 'Polygon') errors.push('polygon.type must be "Polygon"');
  if (!Array.isArray(p.coordinates) || p.coordinates.length !== 1) {
    errors.push('polygon.coordinates must contain exactly one ring');
    return errors;
  }
  const ring = p.coordinates[0];
  if (!Array.isArray(ring)) { errors.push('ring must be array'); return errors; }
  if (ring.length < 4) { errors.push(`ring must have >=4 coords, got ${ring.length}`); return errors; }
  const first = ring[0]; const last = ring[ring.length - 1];
  if (!Array.isArray(first) || !Array.isArray(last) || first.length !== 2 || last.length !== 2) {
    errors.push('first and last must be [lng, lat]'); return errors;
  }
  if (first[0] !== last[0] || first[1] !== last[1]) errors.push('ring must be closed');
  for (let i = 0; i < ring.length; i++) {
    const c = ring[i];
    if (!Array.isArray(c) || c.length !== 2) { errors.push(`coord ${i} invalid`); continue; }
    const [lng, lat] = c;
    if (typeof lng !== 'number' || !Number.isFinite(lng) || lng < -180 || lng > 180) errors.push(`coord ${i}: lng ${lng} out of range`);
    if (typeof lat !== 'number' || !Number.isFinite(lat) || lat < -90 || lat > 90) errors.push(`coord ${i}: lat ${lat} out of range`);
  }
  return errors;
}

export function validateCurfewHours(input: { start_hour: number; end_hour: number }): string[] {
  const errors: string[] = [];
  if (!Number.isInteger(input.start_hour) || input.start_hour < 0 || input.start_hour > 23) errors.push('start_hour must be 0-23');
  if (!Number.isInteger(input.end_hour) || input.end_hour < 0 || input.end_hour > 23) errors.push('end_hour must be 0-23');
  if (input.start_hour === input.end_hour) errors.push('start_hour and end_hour must differ');
  return errors;
}
EOF

W services/api/src/modules/geo/repository.ts <<'EOF'
import { db } from '@tera/db';

export function findActiveCurfewZones() {
  return db().curfewZone.findMany({ where: { active: true }, orderBy: { name: 'asc' } });
}
export function findAllCurfewZones() {
  return db().curfewZone.findMany({ orderBy: [{ active: 'desc' }, { name: 'asc' }] });
}
export function findCurfewZoneById(id: string) { return db().curfewZone.findUnique({ where: { id } }); }
export function createCurfewZone(data: { name: string; polygonJson: object; startHour: number; endHour: number; reason: string }) {
  return db().curfewZone.create({ data });
}
export function updateCurfewHours(id: string, data: { startHour: number; endHour: number; reason: string }) {
  return db().curfewZone.update({ where: { id }, data });
}
export function updateCurfewActive(id: string, active: boolean) {
  return db().curfewZone.update({ where: { id }, data: { active } });
}

export function findFuelStations() {
  return db().fuelStation.findMany({ orderBy: [{ active: 'desc' }, { name: 'asc' }] });
}
export function findFuelStationById(id: string) { return db().fuelStation.findUnique({ where: { id } }); }
export function createFuelStation(data: { name: string; lat: number; lng: number; status: string }) {
  return db().fuelStation.create({ data });
}
export function updateFuelStationStatus(id: string, status: string, actorId: string) {
  return db().fuelStation.update({ where: { id }, data: { status, statusUpdatedBy: actorId } });
}
export function updateFuelStationActive(id: string, active: boolean) {
  return db().fuelStation.update({ where: { id }, data: { active } });
}
EOF

W services/api/src/modules/geo/service.ts <<'EOF'
import type { CurfewZone, FuelStation, CreateCurfewZone, UpdateCurfewHours, CreateFuelStation, FuelStationStatus } from '@tera/contracts';
import * as repo from './repository.js';
import { validateGeoJsonPolygon, validateCurfewHours } from './validation.js';

export async function getCurfewZones(opts: { includeInactive?: boolean } = {}): Promise<{ zones: CurfewZone[] }> {
  const rows = opts.includeInactive ? await repo.findAllCurfewZones() : await repo.findActiveCurfewZones();
  return {
    zones: rows.map((z) => ({
      id: z.id, name: z.name, polygon: z.polygonJson as any,
      start_hour: z.startHour, end_hour: z.endHour,
      reason: z.reason, active: z.active,
    })),
  };
}

export async function createCurfewZone(input: CreateCurfewZone): Promise<CurfewZone> {
  const polygonErrors = validateGeoJsonPolygon(input.polygon);
  if (polygonErrors.length > 0) {
    const e = new Error(polygonErrors.join('; ')) as any; e.statusCode = 400; throw e;
  }
  const hourErrors = validateCurfewHours({ start_hour: input.start_hour, end_hour: input.end_hour });
  if (hourErrors.length > 0) {
    const e = new Error(hourErrors.join('; ')) as any; e.statusCode = 400; throw e;
  }
  const row = await repo.createCurfewZone({
    name: input.name.trim(),
    polygonJson: input.polygon as any,
    startHour: input.start_hour,
    endHour: input.end_hour,
    reason: input.reason.trim(),
  });
  return toCurfew(row);
}

export async function updateCurfewHours(id: string, input: UpdateCurfewHours): Promise<CurfewZone> {
  const existing = await repo.findCurfewZoneById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const hourErrors = validateCurfewHours({ start_hour: input.start_hour, end_hour: input.end_hour });
  if (hourErrors.length > 0) { const e = new Error(hourErrors.join('; ')) as any; e.statusCode = 400; throw e; }
  const row = await repo.updateCurfewHours(id, {
    startHour: input.start_hour, endHour: input.end_hour, reason: input.reason.trim(),
  });
  return toCurfew(row);
}

export async function toggleCurfewActive(id: string, active: boolean): Promise<CurfewZone> {
  const existing = await repo.findCurfewZoneById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  return toCurfew(await repo.updateCurfewActive(id, active));
}

function toCurfew(row: any): CurfewZone {
  return { id: row.id, name: row.name, polygon: row.polygonJson, start_hour: row.startHour, end_hour: row.endHour, reason: row.reason, active: row.active };
}

export async function getFuelStations(opts: { includeInactive?: boolean } = {}): Promise<{ stations: FuelStation[] }> {
  const rows = await repo.findFuelStations();
  const filtered = opts.includeInactive ? rows : rows.filter((r) => r.active);
  return {
    stations: filtered.map((s) => ({
      id: s.id, name: s.name,
      lat: Number(s.lat), lng: Number(s.lng),
      status: s.status as FuelStationStatus, active: s.active,
      updated_at: s.updatedAt.toISOString(),
    })),
  };
}

export async function createFuelStation(input: CreateFuelStation): Promise<FuelStation> {
  return toStation(await repo.createFuelStation({
    name: input.name.trim(), lat: input.lat, lng: input.lng, status: input.status,
  }));
}

export async function updateStationStatus(id: string, status: FuelStationStatus, actorId: string): Promise<FuelStation> {
  const existing = await repo.findFuelStationById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  return toStation(await repo.updateFuelStationStatus(id, status, actorId));
}

export async function toggleStationActive(id: string, active: boolean): Promise<FuelStation> {
  const existing = await repo.findFuelStationById(id);
  if (!existing) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  return toStation(await repo.updateFuelStationActive(id, active));
}

function toStation(row: any): FuelStation {
  return {
    id: row.id, name: row.name,
    lat: Number(row.lat), lng: Number(row.lng),
    status: row.status as FuelStationStatus, active: row.active,
    updated_at: row.updatedAt.toISOString(),
  };
}
EOF

W services/api/src/modules/geo/schemas.ts <<'EOF'
export {
  CurfewZoneSchema, CurfewZonesResponseSchema, CreateCurfewZoneSchema, UpdateCurfewHoursSchema,
  FuelStationSchema, FuelStationsResponseSchema, FuelStationStatusEnum,
  CreateFuelStationSchema, UpdateStationStatusSchema, ToggleActiveSchema, GeoJsonPolygonSchema,
} from '@tera/contracts';
EOF

W services/api/src/modules/geo/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import {
  CurfewZonesResponseSchema, CurfewZoneSchema, CreateCurfewZoneSchema, UpdateCurfewHoursSchema,
  FuelStationsResponseSchema, FuelStationSchema, CreateFuelStationSchema, UpdateStationStatusSchema, ToggleActiveSchema,
} from './schemas.js';
import * as service from './service.js';

export const geoRoutes: FastifyPluginAsync = async (app) => {
  app.get('/curfew-zones', {
    schema: { response: { 200: CurfewZonesResponseSchema as any } },
  }, async (req: any) => service.getCurfewZones({ includeInactive: req.query?.includeInactive === '1' }));

  app.post('/curfew-zones', {
    schema: { body: CreateCurfewZoneSchema as any, response: { 200: CurfewZoneSchema as any } },
  }, async (req: any) => service.createCurfewZone(req.body));

  app.patch('/curfew-zones/:id/hours', {
    schema: { body: UpdateCurfewHoursSchema as any, response: { 200: CurfewZoneSchema as any } },
  }, async (req: any) => service.updateCurfewHours(req.params.id, req.body));

  app.patch('/curfew-zones/:id', {
    schema: { body: ToggleActiveSchema as any, response: { 200: CurfewZoneSchema as any } },
  }, async (req: any) => service.toggleCurfewActive(req.params.id, req.body.active));

  app.get('/fuel-stations', {
    schema: { response: { 200: FuelStationsResponseSchema as any } },
  }, async (req: any) => service.getFuelStations({ includeInactive: req.query?.includeInactive === '1' }));

  app.post('/fuel-stations', {
    schema: { body: CreateFuelStationSchema as any, response: { 200: FuelStationSchema as any } },
  }, async (req: any) => service.createFuelStation(req.body));

  app.patch('/fuel-stations/:id/status', {
    schema: { body: UpdateStationStatusSchema as any, response: { 200: FuelStationSchema as any } },
  }, async (req: any) => {
    const actorId = req.user?.sub ?? 'admin';
    return service.updateStationStatus(req.params.id, req.body.status, actorId);
  });

  app.patch('/fuel-stations/:id', {
    schema: { body: ToggleActiveSchema as any, response: { 200: FuelStationSchema as any } },
  }, async (req: any) => service.toggleStationActive(req.params.id, req.body.active));
};
EOF

W services/api/src/modules/geo/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { geoRoutes } from './routes.js';
export const geoPlugin: FastifyPluginAsync = async (app) => { await app.register(geoRoutes); };
export default geoPlugin;
EOF

W services/api/src/modules/geo/__tests__/validation.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { validateGeoJsonPolygon, validateCurfewHours } from '../validation.js';

const VALID = { type: 'Polygon' as const, coordinates: [[
  [38.74, 9.03] as [number, number], [38.76, 9.03] as [number, number],
  [38.76, 9.04] as [number, number], [38.74, 9.04] as [number, number],
  [38.74, 9.03] as [number, number],
]]};

describe('validateGeoJsonPolygon', () => {
  it('accepts valid closed polygon', () => expect(validateGeoJsonPolygon(VALID)).toEqual([]));
  it('rejects null', () => expect(validateGeoJsonPolygon(null).length).toBeGreaterThan(0));
  it('rejects wrong type', () => expect(validateGeoJsonPolygon({ type: 'LineString', coordinates: [] }).some((e) => e.includes('Polygon'))).toBe(true));
  it('rejects unclosed ring', () => {
    const bad = { type: 'Polygon', coordinates: [[[38.74, 9.03], [38.76, 9.03], [38.76, 9.04], [38.74, 9.04]]] };
    expect(validateGeoJsonPolygon(bad).some((e) => e.includes('closed'))).toBe(true);
  });
  it('rejects out-of-range lat', () => {
    const bad = { type: 'Polygon', coordinates: [[[38.74, 9.03], [38.76, 95], [38.76, 9.04], [38.74, 9.03]]] };
    expect(validateGeoJsonPolygon(bad).some((e) => e.includes('lat'))).toBe(true);
  });
});

describe('validateCurfewHours', () => {
  it('accepts standard', () => expect(validateCurfewHours({ start_hour: 7, end_hour: 10 })).toEqual([]));
  it('accepts overnight', () => expect(validateCurfewHours({ start_hour: 22, end_hour: 6 })).toEqual([]));
  it('rejects out of range', () => expect(validateCurfewHours({ start_hour: -1, end_hour: 5 }).length).toBeGreaterThan(0));
  it('rejects equal', () => expect(validateCurfewHours({ start_hour: 8, end_hour: 8 }).length).toBeGreaterThan(0));
});
EOF

# ── orders module ──────────────────────────────────────────
W services/api/src/modules/orders/repository.ts <<'EOF'
import { db } from '@tera/db';

export function findPendingOrders() {
  return db().order.findMany({ where: { status: 'PENDING' }, orderBy: { createdAt: 'asc' } });
}

export function findOrdersByIds(ids: string[]) {
  return db().order.findMany({ where: { id: { in: ids }, status: 'PENDING' } });
}

export function markOrdersRouted(orderIds: string[]) {
  return db().order.updateMany({ where: { id: { in: orderIds } }, data: { status: 'ROUTED' } });
}
EOF

W services/api/src/modules/orders/service.ts <<'EOF'
import type { Order } from '@tera/contracts';
import * as repo from './repository.js';

export async function getPendingOrders(): Promise<{ orders: Order[] }> {
  const rows = await repo.findPendingOrders();
  return {
    orders: rows.map((r) => ({
      id: r.id,
      distributor_id: r.distributorId,
      distributor_name: r.distributorName,
      lat: Number(r.lat), lng: Number(r.lng),
      weight_kg: Number(r.weightKg), volume_m3: Number(r.volumeM3),
      priority: r.priority,
      time_window_start: r.timeWindowStart.toISOString(),
      time_window_end: r.timeWindowEnd.toISOString(),
      status: r.status as Order['status'],
      created_at: r.createdAt.toISOString(),
    })),
  };
}
EOF

W services/api/src/modules/orders/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { PendingOrdersResponseSchema } from '@tera/contracts';
import * as service from './service.js';

export const ordersRoutes: FastifyPluginAsync = async (app) => {
  app.get('/pending', {
    schema: { response: { 200: PendingOrdersResponseSchema as any } },
  }, async () => service.getPendingOrders());
};
EOF

W services/api/src/modules/orders/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { ordersRoutes } from './routes.js';
export const ordersPlugin: FastifyPluginAsync = async (app) => { await app.register(ordersRoutes); };
export default ordersPlugin;
EOF

# ── dispatch/rules (dependency for routing gates) ─────────
W services/api/src/modules/dispatch/rules.ts <<'EOF'
export type SlotStatus = 'AVAILABLE' | 'ALLOCATED' | 'CONFIRMED' | 'COMPLETED';
export type RouteStatus = 'PLANNED' | 'DISPATCHED' | 'COMPLETED';

export interface GateInput { routeStatus: RouteStatus; slotStatus: SlotStatus | null; }
export interface GateResult { allowed: boolean; reason: string | null; }

export function canDispatch(input: GateInput): GateResult {
  if (input.routeStatus === 'DISPATCHED' || input.routeStatus === 'COMPLETED') return { allowed: false, reason: 'route already dispatched or completed' };
  if (input.slotStatus === null) return { allowed: false, reason: 'no dock slot allocated' };
  if (input.slotStatus === 'AVAILABLE') return { allowed: false, reason: 'slot not allocated to a route' };
  if (input.slotStatus === 'ALLOCATED') return { allowed: false, reason: 'loading not confirmed by warehouse' };
  return { allowed: true, reason: null };
}

export function nextRouteStatus(): RouteStatus { return 'DISPATCHED'; }
export function nextSlotStatus(): SlotStatus { return 'COMPLETED'; }

export interface ConfirmLoadingInput { slotStatus: SlotStatus; pickedCount: number; totalCount: number; }
export interface ConfirmLoadingResult { allowed: boolean; reason: string | null; }

export function canConfirmLoading(input: ConfirmLoadingInput): ConfirmLoadingResult {
  if (input.slotStatus !== 'ALLOCATED') return { allowed: false, reason: `cannot confirm: slot is ${input.slotStatus}` };
  if (input.totalCount === 0) return { allowed: false, reason: 'cannot confirm: route has no stops' };
  if (input.pickedCount < input.totalCount) return { allowed: false, reason: `cannot confirm: ${input.pickedCount} of ${input.totalCount} stops picked` };
  return { allowed: true, reason: null };
}

export interface MarkPickedInput { slotStatus: SlotStatus | null; currentPickedAt: string | null; }
export interface MarkPickedResult { allowed: boolean; reason: string | null; already_picked_at: string | null; }

export function canMarkPicked(input: MarkPickedInput): MarkPickedResult {
  if (input.slotStatus === null) return { allowed: false, reason: 'no dock slot allocated to this route', already_picked_at: null };
  if (input.slotStatus === 'AVAILABLE') return { allowed: false, reason: 'slot not allocated to a route', already_picked_at: null };
  if (input.slotStatus === 'CONFIRMED' || input.slotStatus === 'COMPLETED') return { allowed: false, reason: 'loading already confirmed — cannot pick', already_picked_at: null };
  if (input.currentPickedAt !== null) return { allowed: true, reason: null, already_picked_at: input.currentPickedAt };
  return { allowed: true, reason: null, already_picked_at: null };
}
EOF

# ── routing: repository ───────────────────────────────────
W services/api/src/modules/routing/repository.ts <<'EOF'
import { db } from '@tera/db';

export function findRoutesForDate(date: Date) {
  return db().routePlan.findMany({
    where: { date },
    include: { stops: { orderBy: { seq: 'asc' } } },
    orderBy: { vehicleId: 'asc' },
  });
}

export function findVehicles() {
  return db().vehicle.findMany({ where: { active: true }, orderBy: { plate: 'asc' } });
}

export function findVehicleById(id: string) {
  return db().vehicle.findUnique({ where: { id } });
}

export function findRouteWithStops(id: string) {
  return db().routePlan.findUnique({
    where: { id },
    include: { stops: { orderBy: { seq: 'asc' } } },
  });
}

export function findStopById(stopId: string) { return db().routeStop.findUnique({ where: { id } }); }
export function findSlotForRoute(routeId: string) { return db().dispatchDockSlot.findUnique({ where: { routePlanId: routeId } }); }
export function countPickedStopsForRoute(routeId: string) {
  return db().routeStop.count({ where: { routePlanId: routeId, pickedAt: { not: null } } });
}
export function countStopsForRoute(routeId: string) {
  return db().routeStop.count({ where: { routePlanId: routeId } });
}

export async function markStopPicked(stopId: string) {
  return db().routeStop.update({ where: { id: stopId }, data: { pickedAt: new Date() } });
}

export async function createRoutePlanWithStops(input: {
  date: Date; vehicleId: string; driverId: string;
  plannedKm: number; plannedMin: number;
  startLat: number; startLng: number; baselineKm: number;
  stops: {
    orderId: string; seq: number; distributorId: string; distributorName: string;
    lat: number; lng: number; plannedEta: Date; quantityOrdered?: number;
  }[];
}) {
  return db().$transaction(async (tx) => {
    const plan = await tx.routePlan.create({
      data: {
        date: input.date, vehicleId: input.vehicleId, driverId: input.driverId,
        status: 'PLANNED', version: 1,
        plannedKm: input.plannedKm, plannedMin: input.plannedMin,
        startLat: input.startLat, startLng: input.startLng,
        baselineKm: input.baselineKm,
      },
    });
    for (const s of input.stops) {
      await tx.routeStop.create({
        data: {
          routePlanId: plan.id, orderId: s.orderId, seq: s.seq,
          distributorId: s.distributorId, distributorName: s.distributorName,
          lat: s.lat, lng: s.lng, plannedEta: s.plannedEta,
          status: 'PENDING', quantityOrdered: s.quantityOrdered ?? 0,
        },
      });
    }
    await tx.order.updateMany({
      where: { id: { in: input.stops.map((s) => s.orderId) } },
      data: { status: 'ROUTED' },
    });
    return plan;
  });
}
EOF

# ── routing: service ───────────────────────────────────────
W services/api/src/modules/routing/service.ts <<'EOF'
import { solve } from '@tera/solver';
import type {
  RoutePlan, Vehicle, SolveResponse, AcceptRouteRequest, AcceptRouteResponse,
  PickListResponse, PickListStop, MarkPickedResponse,
} from '@tera/contracts';
import * as repo from './repository.js';
import * as ordersRepo from '../orders/repository.js';
import { getCurfewZones } from '../geo/service.js';
import { canConfirmLoading, canMarkPicked } from '../dispatch/rules.js';

function startOfTodayUTC(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

export async function getTodayRoutes(): Promise<{ as_of: string; routes: RoutePlan[] }> {
  const rows = await repo.findRoutesForDate(startOfTodayUTC());
  return {
    as_of: new Date().toISOString(),
    routes: rows.map((r) => ({
      id: r.id, vehicle_id: r.vehicleId, driver_id: r.driverId,
      status: r.status as RoutePlan['status'],
      planned_km: Number(r.plannedKm), planned_min: r.plannedMin,
      start_lat: Number(r.startLat), start_lng: Number(r.startLng),
      stops: r.stops.map((s) => ({
        id: s.id, seq: s.seq,
        distributor_id: s.distributorId, distributor_name: s.distributorName,
        lat: Number(s.lat), lng: Number(s.lng),
        planned_eta: s.plannedEta.toISOString(),
        actual_arrival: s.actualArrival ? s.actualArrival.toISOString() : null,
        status: s.status as any,
      })),
    })),
  };
}

export async function getVehicles(): Promise<{ vehicles: Vehicle[] }> {
  const rows = await repo.findVehicles();
  return {
    vehicles: rows.map((v) => ({
      id: v.id, plate: v.plate,
      capacity_kg: Number(v.capacityKg), capacity_m3: Number(v.capacityM3),
      shift_start_h: v.shiftStartH, shift_end_h: v.shiftEndH,
      start_lat: Number(v.startLat), start_lng: Number(v.startLng),
    })),
  };
}

async function solveCore(orderIds: string[], vehicleId: string) {
  const [vehicle, orderRows, zones] = await Promise.all([
    repo.findVehicleById(vehicleId),
    ordersRepo.findOrdersByIds(orderIds),
    getCurfewZones(),
  ]);
  if (!vehicle) { const e = new Error('vehicle not found') as any; e.statusCode = 404; throw e; }
  if (orderRows.length < 2) { const e = new Error('at least 2 pending orders required') as any; e.statusCode = 400; throw e; }
  const result = solve(
    orderRows.map((o) => ({
      id: o.id, distributor_name: o.distributorName,
      lat: Number(o.lat), lng: Number(o.lng),
      weight_kg: Number(o.weightKg), volume_m3: Number(o.volumeM3),
      priority: o.priority,
      time_window_start: o.timeWindowStart.toISOString(),
      time_window_end: o.timeWindowEnd.toISOString(),
    })),
    {
      id: vehicle.id, lat: Number(vehicle.startLat), lng: Number(vehicle.startLng),
      capacity_kg: Number(vehicle.capacityKg), capacity_m3: Number(vehicle.capacityM3),
      shift_start_h: vehicle.shiftStartH, shift_end_h: vehicle.shiftEndH,
    },
    {
      curfew_zones: zones.zones.map((z) => ({
        id: z.id, name: z.name, polygon: z.polygon,
        start_hour: z.start_hour, end_hour: z.end_hour,
      })),
    },
  );
  return { result, vehicle, orderRows };
}

export async function solveRoutes(orderIds: string[], vehicleId: string): Promise<SolveResponse> {
  const { result } = await solveCore(orderIds, vehicleId);
  return result;
}

export async function acceptRoute(req: AcceptRouteRequest): Promise<AcceptRouteResponse> {
  const { result, vehicle, orderRows } = await solveCore(req.order_ids, req.vehicle_id);
  if (result.infeasible) {
    const e = new Error(`cannot accept: ${result.infeasible.reason}`) as any; e.statusCode = 400; throw e;
  }
  const chosen = req.mode === 'optimized' ? result.optimized : result.manual;
  const byId = new Map(orderRows.map((o) => [o.id, o]));

  const plan = await repo.createRoutePlanWithStops({
    date: startOfTodayUTC(),
    vehicleId: req.vehicle_id,
    driverId: req.driver_id,
    plannedKm: chosen.total_km, plannedMin: chosen.total_min,
    startLat: Number(vehicle.startLat), startLng: Number(vehicle.startLng),
    baselineKm: result.manual.total_km,
    stops: chosen.stops.map((s) => {
      const o = byId.get(s.order_id)!;
      return {
        orderId: s.order_id, seq: s.seq,
        distributorId: o.distributorId, distributorName: o.distributorName,
        lat: s.lat, lng: s.lng, plannedEta: new Date(s.eta),
        quantityOrdered: (o as any).totalQuantity || 10,
      };
    }),
  });

  return { route_id: plan.id, planned_km: chosen.total_km, planned_min: chosen.total_min };
}

export async function getPickList(routeId: string): Promise<PickListResponse> {
  const route = await repo.findRouteWithStops(routeId);
  if (!route) { const e = new Error('route not found') as any; e.statusCode = 404; throw e; }
  const slot = await repo.findSlotForRoute(routeId);
  const stops: PickListStop[] = route.stops.map((s) => ({
    stop_id: s.id, seq: s.seq,
    distributor_name: s.distributorName,
    quantity_ordered: s.quantityOrdered,
    picked_at: s.pickedAt ? s.pickedAt.toISOString() : null,
  }));
  const pickedCount = stops.filter((s) => s.picked_at !== null).length;
  const totalCount = stops.length;
  const gate = canConfirmLoading({
    slotStatus: (slot?.status ?? 'AVAILABLE') as any,
    pickedCount, totalCount,
  });
  return {
    route_id: route.id, vehicle_id: route.vehicleId, driver_id: route.driverId,
    slot_id: slot?.id ?? null,
    slot_status: (slot?.status as any) ?? null,
    stops, picked_count: pickedCount, total_count: totalCount,
    can_confirm_loading: gate.allowed,
  };
}

export async function markStopPicked(routeId: string, stopId: string): Promise<MarkPickedResponse> {
  const stop = await repo.findStopById(stopId);
  if (!stop) { const e = new Error('stop not found') as any; e.statusCode = 404; throw e; }
  if (stop.routePlanId !== routeId) { const e = new Error('stop does not belong to this route') as any; e.statusCode = 400; throw e; }
  const slot = await repo.findSlotForRoute(routeId);
  const gate = canMarkPicked({
    slotStatus: (slot?.status as any) ?? null,
    currentPickedAt: stop.pickedAt ? stop.pickedAt.toISOString() : null,
  });
  if (!gate.allowed) { const e = new Error(gate.reason!) as any; e.statusCode = 400; throw e; }
  let pickedAt = gate.already_picked_at;
  if (pickedAt === null) {
    const updated = await repo.markStopPicked(stopId);
    pickedAt = updated.pickedAt!.toISOString();
  }
  const pickedCount = await repo.countPickedStopsForRoute(routeId);
  const totalCount = await repo.countStopsForRoute(routeId);
  const confirmGate = canConfirmLoading({
    slotStatus: (slot?.status as any) ?? 'AVAILABLE',
    pickedCount, totalCount,
  });
  return {
    stop_id: stopId, picked_at: pickedAt,
    picked_count: pickedCount, total_count: totalCount,
    can_confirm_loading: confirmGate.allowed,
  };
}
EOF

W services/api/src/modules/routing/schemas.ts <<'EOF'
export {
  RoutePlanSchema, RouteStopSchema, TodayRoutesResponseSchema, RouteStatusEnum, StopStatusEnum,
  SolveRequestSchema, SolveResponseSchema, AcceptRouteRequestSchema, AcceptRouteResponseSchema,
  VehiclesResponseSchema,
  AsyncSolveRequestSchema, AsyncSolveSubmitResponseSchema, AsyncSolveJobResponseSchema, AsyncSolveStatusEnum,
  PickListResponseSchema, PickListStopSchema, MarkPickedResponseSchema,
} from '@tera/contracts';
EOF

# ── routing: async queue + jobs ────────────────────────────
W services/api/src/modules/routing/queue.ts <<'EOF'
import { Queue } from 'bullmq';
import IORedis from 'ioredis';

const QUEUE_NAME = 'route-solve';
let redis: IORedis | null = null;
let queue: Queue | null = null;

function getRedis(): IORedis {
  if (!redis) {
    redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
      maxRetriesPerRequest: null, enableReadyCheck: false,
    });
    redis.on('error', (e) => console.error('[solve-queue]', e.message));
  }
  return redis;
}

export function getSolveQueue(): Queue {
  if (!queue) queue = new Queue(QUEUE_NAME, { connection: getRedis() });
  return queue;
}

export async function enqueueSolve(dbJobId: string): Promise<void> {
  await getSolveQueue().add('solve', { dbJobId }, {
    jobId: dbJobId, attempts: 1,
    removeOnComplete: { age: 3600, count: 500 },
    removeOnFail: { age: 3600, count: 500 },
  });
}

export async function isQueueHealthy(): Promise<boolean> {
  try { const client = await getSolveQueue().client; await client.ping(); return true; }
  catch { return false; }
}
EOF

W services/api/src/modules/routing/jobs-repository.ts <<'EOF'
import { db } from '@tera/db';

export function createSolveJob(input: { orderIds: string[]; vehicleId: string; status: string }) {
  return db().solveJob.create({
    data: { orderIdsJson: input.orderIds as any, vehicleId: input.vehicleId, status: input.status },
  });
}

export function findSolveJobById(id: string) { return db().solveJob.findUnique({ where: { id } }); }

export function markSolveJobFailed(id: string, error: string) {
  return db().solveJob.update({ where: { id }, data: { status: 'FAILED', error, finishedAt: new Date() } });
}
EOF

W services/api/src/modules/routing/jobs-service.ts <<'EOF'
import type { AsyncSolveRequest, AsyncSolveSubmitResponse, AsyncSolveJobResponse, AsyncSolveStatus, SolveResponse } from '@tera/contracts';
import * as jobsRepo from './jobs-repository.js';
import { enqueueSolve, isQueueHealthy } from './queue.js';

const MAX_ORDERS = 500;

export async function submitAsyncSolve(input: AsyncSolveRequest): Promise<AsyncSolveSubmitResponse> {
  if (input.order_ids.length > MAX_ORDERS) {
    const e = new Error(`Too many orders (${input.order_ids.length}); max ${MAX_ORDERS}`) as any;
    e.statusCode = 400; throw e;
  }
  const job = await jobsRepo.createSolveJob({
    orderIds: input.order_ids, vehicleId: input.vehicle_id, status: 'QUEUED',
  });
  const healthy = await isQueueHealthy();
  if (!healthy) {
    await jobsRepo.markSolveJobFailed(job.id, 'Optimizer queue unreachable');
    const e = new Error('Solve queue unavailable — is the optimizer running?') as any;
    e.statusCode = 503; throw e;
  }
  try { await enqueueSolve(job.id); }
  catch (err) {
    await jobsRepo.markSolveJobFailed(job.id, err instanceof Error ? err.message : String(err));
    const e = new Error('Failed to enqueue solve job') as any; e.statusCode = 503; throw e;
  }
  return { job_id: job.id, status: job.status as AsyncSolveStatus };
}

export async function getAsyncSolveJob(jobId: string): Promise<AsyncSolveJobResponse> {
  const job = await jobsRepo.findSolveJobById(jobId);
  if (!job) { const e = new Error('solve job not found') as any; e.statusCode = 404; throw e; }
  return {
    job_id: job.id, status: job.status as AsyncSolveStatus,
    submitted_at: job.createdAt.toISOString(),
    started_at: job.startedAt ? job.startedAt.toISOString() : null,
    finished_at: job.finishedAt ? job.finishedAt.toISOString() : null,
    duration_ms: job.durationMs,
    result: job.resultJson as unknown as SolveResponse | null,
    error: job.error,
  };
}
EOF

W services/api/src/modules/routing/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import {
  TodayRoutesResponseSchema, VehiclesResponseSchema,
  SolveRequestSchema, SolveResponseSchema, AcceptRouteRequestSchema, AcceptRouteResponseSchema,
  AsyncSolveRequestSchema, AsyncSolveSubmitResponseSchema, AsyncSolveJobResponseSchema,
  PickListResponseSchema, MarkPickedResponseSchema,
} from './schemas.js';
import * as service from './service.js';
import * as jobsService from './jobs-service.js';

export const routingRoutes: FastifyPluginAsync = async (app) => {
  app.get('/routes/today', {
    schema: { response: { 200: TodayRoutesResponseSchema as any } },
  }, async () => service.getTodayRoutes());

  app.get('/vehicles', {
    schema: { response: { 200: VehiclesResponseSchema as any } },
  }, async () => service.getVehicles());

  app.post('/solve', {
    schema: { body: SolveRequestSchema as any, response: { 200: SolveResponseSchema as any } },
  }, async (req: any) => service.solveRoutes(req.body.order_ids, req.body.vehicle_id));

  app.post('/routes', {
    schema: { body: AcceptRouteRequestSchema as any, response: { 200: AcceptRouteResponseSchema as any } },
  }, async (req: any) => service.acceptRoute(req.body));

  app.post('/solve/async', {
    schema: { body: AsyncSolveRequestSchema as any, response: { 200: AsyncSolveSubmitResponseSchema as any } },
  }, async (req: any) => jobsService.submitAsyncSolve(req.body));

  app.get('/solve/jobs/:id', {
    schema: { response: { 200: AsyncSolveJobResponseSchema as any } },
  }, async (req: any) => jobsService.getAsyncSolveJob(req.params.id));

  app.get('/routes/:id/pick-list', {
    schema: { response: { 200: PickListResponseSchema as any } },
  }, async (req: any) => service.getPickList(req.params.id));

  app.post('/routes/:id/stops/:stopId/picked', {
    schema: { response: { 200: MarkPickedResponseSchema as any } },
  }, async (req: any) => service.markStopPicked(req.params.id, req.params.stopId));
};
EOF

W services/api/src/modules/routing/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { routingRoutes } from './routes.js';
export const routingPlugin: FastifyPluginAsync = async (app) => { await app.register(routingRoutes); };
export default routingPlugin;
EOF

W services/api/src/modules/routing/__tests__/jobs-service.test.ts <<'EOF'
import { describe, it, expect, vi, beforeEach } from 'vitest';
vi.mock('../jobs-repository.js', () => ({
  createSolveJob: vi.fn(), findSolveJobById: vi.fn(), markSolveJobFailed: vi.fn(),
}));
vi.mock('../queue.js', () => ({ enqueueSolve: vi.fn(), isQueueHealthy: vi.fn() }));

import * as repo from '../jobs-repository.js';
import { enqueueSolve, isQueueHealthy } from '../queue.js';
import { submitAsyncSolve, getAsyncSolveJob } from '../jobs-service.js';

const mockedRepo = vi.mocked(repo);
const mockedHealthy = vi.mocked(isQueueHealthy);
const mockedEnqueue = vi.mocked(enqueueSolve);

beforeEach(() => vi.clearAllMocks());

describe('submitAsyncSolve', () => {
  it('rejects >500 orders', async () => {
    const ids = Array.from({ length: 501 }, (_, i) => `o-${i}`);
    await expect(submitAsyncSolve({ order_ids: ids, vehicle_id: 'v1' })).rejects.toMatchObject({ statusCode: 400 });
    expect(mockedRepo.createSolveJob).not.toHaveBeenCalled();
  });
  it('creates QUEUED job + enqueues when healthy', async () => {
    mockedRepo.createSolveJob.mockResolvedValue({ id: 'j1', status: 'QUEUED', orderIdsJson: ['a','b'], vehicleId: 'v1', resultJson: null, error: null, startedAt: null, finishedAt: null, durationMs: null, createdAt: new Date() } as any);
    mockedHealthy.mockResolvedValue(true);
    mockedEnqueue.mockResolvedValue(undefined);
    const r = await submitAsyncSolve({ order_ids: ['a','b'], vehicle_id: 'v1' });
    expect(r.job_id).toBe('j1');
    expect(mockedEnqueue).toHaveBeenCalledWith('j1');
  });
  it('marks FAILED + throws 503 when queue unreachable', async () => {
    mockedRepo.createSolveJob.mockResolvedValue({ id: 'j2', status: 'QUEUED', orderIdsJson: ['a','b'], vehicleId: 'v1', resultJson: null, error: null, startedAt: null, finishedAt: null, durationMs: null, createdAt: new Date() } as any);
    mockedHealthy.mockResolvedValue(false);
    mockedRepo.markSolveJobFailed.mockResolvedValue({} as any);
    await expect(submitAsyncSolve({ order_ids: ['a','b'], vehicle_id: 'v1' })).rejects.toMatchObject({ statusCode: 503 });
    expect(mockedRepo.markSolveJobFailed).toHaveBeenCalledWith('j2', expect.any(String));
  });
});

describe('getAsyncSolveJob', () => {
  it('returns the job', async () => {
    mockedRepo.findSolveJobById.mockResolvedValue({ id: 'j', status: 'DONE', orderIdsJson: [], vehicleId: 'v', resultJson: { savings_km_pct: 20 } as any, error: null, startedAt: new Date(), finishedAt: new Date(), durationMs: 120, createdAt: new Date() } as any);
    const r = await getAsyncSolveJob('j');
    expect(r.status).toBe('DONE');
    expect(r.duration_ms).toBe(120);
  });
  it('404 when missing', async () => {
    mockedRepo.findSolveJobById.mockResolvedValue(null);
    await expect(getAsyncSolveJob('missing')).rejects.toMatchObject({ statusCode: 404 });
  });
});
EOF

# ── app.ts (Phase 1-2 modules only) ───────────────────────
W services/api/src/app.ts <<'EOF'
import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { errorHandler } from './plugins/errorHandler.js';
import { authPlugin } from './plugins/auth.js';

import credit from './modules/credit/index.js';
import configMod from './modules/config/index.js';
import geo from './modules/geo/index.js';
import routing from './modules/routing/index.js';
import orders from './modules/orders/index.js';

export async function buildApp() {
  const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
  await app.register(cors, { origin: true });
  await app.register(sensible);
  await app.register(swagger, {
    openapi: {
      info: { title: 'Tera OMS API', version: '0.1.0' },
      components: { securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } } },
    },
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });
  app.setErrorHandler(errorHandler);
  await app.register(authPlugin);

  await app.register(configMod, { prefix: '/config/v1' });
  await app.register(credit,    { prefix: '/credit/v1' });
  await app.register(geo,       { prefix: '/geo/v1' });
  await app.register(routing,   { prefix: '/routing/v1' });
  await app.register(orders,    { prefix: '/orders/v1' });

  app.get('/health', async () => ({ ok: true }));
  return app;
}
EOF

W services/api/src/server.ts <<'EOF'
import { buildApp } from './app.js';
const PORT = Number(process.env.PORT ?? 8000);
const app = await buildApp();
await app.listen({ port: PORT, host: '0.0.0.0' });
console.log(`API listening on :${PORT}`);
EOF

# ── SEED (complete, final) ────────────────────────────────
W packages/db/prisma/seed.ts <<'EOF'
import { PrismaClient } from '../generated/client';

const prisma = new PrismaClient();
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);
const today = new Date();
const tw = (h: number) => { const x = new Date(today); x.setHours(h, 0, 0, 0); return x; };
const dateOnly = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));

async function main() {
  // ── Distributors + credit accounts ─────────────────────
  const dists = [
    { id: 'seed-dist-1', name: 'Abebe Distribution', region: 'Addis', lat: 9.0200, lng: 38.7800, limit: 100_000, exposure: 25_000,  oldestDays: 5,  grace: 14 },
    { id: 'seed-dist-2', name: 'Bole Wholesale Co.',  region: 'Addis', lat: null, lng: null,       limit: 200_000, exposure: 250_000, oldestDays: 65, grace: 14 },
    { id: 'seed-dist-3', name: 'Kazanchis Distributors', region: 'Addis', lat: null, lng: null,    limit: 100_000, exposure: 90_000,  oldestDays: 5,  grace: 14 },
    { id: 'seed-dist-4', name: 'Sarbet Traders',      region: 'Addis', lat: null, lng: null,       limit: 100_000, exposure: 20_000,  oldestDays: 3,  grace: 14 },
    { id: 'seed-dist-5', name: 'CMC Retailers',       region: 'Addis', lat: null, lng: null,       limit: 200_000, exposure: 180_000, oldestDays: 25, grace: 14 },
  ];
  for (const d of dists) {
    await prisma.distributor.upsert({
      where: { id: d.id },
      create: { id: d.id, name: d.name, region: d.region, lat: d.lat, lng: d.lng },
      update: {},
    });
    await prisma.creditAccount.upsert({
      where: { distributorId: d.id },
      create: { distributorId: d.id, limitEtb: d.limit, exposureEtb: d.exposure, oldestUnpaidAt: daysAgo(d.oldestDays), graceDays: d.grace },
      update: {},
    });
  }

  // ── Vehicles ───────────────────────────────────────────
  const vehicles = [
    { id: 'V-101', plate: 'AA-3-B-101', capacityKg: 1500, capacityM3: 8, shiftStartH: 7, shiftEndH: 18, startLat: 9.0108, startLng: 38.7613, baselineLPer100Km: 12 },
    { id: 'V-102', plate: 'AA-3-B-102', capacityKg: 1500, capacityM3: 8, shiftStartH: 7, shiftEndH: 18, startLat: 9.0108, startLng: 38.7613, baselineLPer100Km: 12 },
    { id: 'V-103', plate: 'AA-3-B-103', capacityKg: 1000, capacityM3: 5, shiftStartH: 7, shiftEndH: 17, startLat: 9.0108, startLng: 38.7613, baselineLPer100Km: 10 },
  ];
  for (const v of vehicles) {
    await prisma.vehicle.upsert({ where: { id: v.id }, create: v, update: {} });
  }

  // ── SKUs ───────────────────────────────────────────────
  const skus = [
    { code: 'SKU-COKE-500',  name: 'Coca-Cola 500ml',  unit: 'each', weightKg: 0.6, volumeM3: 0.0008, unitPriceEtb: 30, stockOnHand: 500, reorderPoint: 50, safetyStock: 20, leadTimeDays: 3 },
    { code: 'SKU-PEPSI-500', name: 'Pepsi 500ml',      unit: 'each', weightKg: 0.6, volumeM3: 0.0008, unitPriceEtb: 28, stockOnHand: 300, reorderPoint: 40, safetyStock: 15, leadTimeDays: 3 },
    { code: 'SKU-WATER-1L',  name: 'Ambo Water 1L',    unit: 'each', weightKg: 1.1, volumeM3: 0.0012, unitPriceEtb: 18, stockOnHand: 200, reorderPoint: 30, safetyStock: 10, leadTimeDays: 2 },
    { code: 'SKU-BREAD',     name: 'White Bread Loaf', unit: 'each', weightKg: 0.4, volumeM3: 0.003,  unitPriceEtb: 15, stockOnHand: 60,  reorderPoint: 20, safetyStock: 10, leadTimeDays: 1 },
    { code: 'SKU-MILK-1L',   name: 'Family Milk 1L',   unit: 'each', weightKg: 1.0, volumeM3: 0.0011, unitPriceEtb: 45, stockOnHand: 100, reorderPoint: 25, safetyStock: 12, leadTimeDays: 2 },
  ];
  for (const s of skus) {
    await prisma.sku.upsert({ where: { code: s.code }, create: s, update: {} });
  }

  // ── Curfew zones ───────────────────────────────────────
  const zones = [
    { id: 'zone-merkato', name: 'Merkato Heavy Truck Ban',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7400,9.0300],[38.7550,9.0300],[38.7550,9.0400],[38.7400,9.0400],[38.7400,9.0300]]] },
      startHour: 7, endHour: 10, reason: 'Morning peak truck restriction', active: true },
    { id: 'zone-piassa', name: 'Piassa Central Ban',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7450,9.0280],[38.7600,9.0280],[38.7600,9.0380],[38.7450,9.0380],[38.7450,9.0280]]] },
      startHour: 17, endHour: 20, reason: 'Evening pedestrian zone', active: true },
    { id: 'zone-bole-overnight', name: 'Bole Overnight Restriction',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7800,8.9900],[38.8000,8.9900],[38.8000,9.0100],[38.7800,9.0100],[38.7800,8.9900]]] },
      startHour: 22, endHour: 6, reason: 'Overnight residential noise ban', active: true },
    { id: 'zone-old-airport', name: 'Old Airport (decommissioned)',
      polygonJson: { type: 'Polygon', coordinates: [[[38.7500,8.9800],[38.7700,8.9800],[38.7700,9.0000],[38.7500,9.0000],[38.7500,8.9800]]] },
      startHour: 12, endHour: 14, reason: 'Lifted', active: false },
  ];
  for (const z of zones) {
    await prisma.curfewZone.upsert({ where: { id: z.id }, create: z as any, update: {} });
  }

  // ── Fuel stations ──────────────────────────────────────
  const stations = [
    { id: 'fuel-1', name: 'Bole Total',  lat: 8.9948, lng: 38.7923, status: 'operational' },
    { id: 'fuel-2', name: 'Mexico Nile', lat: 9.0100, lng: 38.7500, status: 'queued' },
    { id: 'fuel-3', name: 'CMC NOC',     lat: 9.0200, lng: 38.8300, status: 'operational' },
    { id: 'fuel-4', name: 'Sarbet Shell', lat: 8.9950, lng: 38.7600, status: 'dry' },
  ];
  for (const s of stations) {
    await prisma.fuelStation.upsert({ where: { id: s.id }, create: s as any, update: {} });
  }

  // ── Docks + slots ──────────────────────────────────────
  const docks = [{ id: 'dock-a', name: 'Dock A' }, { id: 'dock-b', name: 'Dock B' }, { id: 'dock-c', name: 'Dock C' }];
  for (const dock of docks) {
    await prisma.dispatchDock.upsert({ where: { id: dock.id }, create: dock, update: {} });
  }
  const slotWindows = [{ s: 6, e: 7 }, { s: 7, e: 8 }, { s: 8, e: 9 }, { s: 9, e: 10 }];
  for (const dock of docks) {
    for (let i = 0; i < slotWindows.length; i++) {
      const w = slotWindows[i]!;
      const id = `${dock.id}-slot-${i}`;
      await prisma.dispatchDockSlot.upsert({
        where: { id },
        create: {
          id, dockId: dock.id, date: dateOnly,
          startAt: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), w.s, 0, 0)),
          endAt:   new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), w.e, 0, 0)),
          status: 'AVAILABLE',
        },
        update: {},
      });
    }
  }

  // ── Pending orders (8) ────────────────────────────────
  const orders = [
    { id: 'seed-order-1', name: 'Bole Retail',       lat: 8.9948, lng: 38.7923, w: 80,  v: 0.4, pri: 8, ws: 8,  we: 12 },
    { id: 'seed-order-2', name: 'Kazanchis Mart',    lat: 9.0167, lng: 38.7667, w: 120, v: 0.6, pri: 6, ws: 9,  we: 13 },
    { id: 'seed-order-3', name: 'Piassa Traders',    lat: 9.0333, lng: 38.7500, w: 95,  v: 0.5, pri: 5, ws: 10, we: 14 },
    { id: 'seed-order-4', name: 'Merkato Wholesale', lat: 9.0348, lng: 38.7466, w: 200, v: 1.2, pri: 9, ws: 11, we: 15 },
    { id: 'seed-order-5', name: 'Saris Corner',      lat: 8.9900, lng: 38.7400, w: 60,  v: 0.3, pri: 4, ws: 10, we: 16 },
    { id: 'seed-order-6', name: 'CMC Store',         lat: 9.0200, lng: 38.8300, w: 150, v: 0.8, pri: 7, ws: 8,  we: 12 },
    { id: 'seed-order-7', name: 'Bole Medhanialem',  lat: 9.0050, lng: 38.7850, w: 70,  v: 0.35, pri: 6, ws: 9, we: 14 },
    { id: 'seed-order-8', name: 'Megenagna Shop',    lat: 9.0200, lng: 38.8000, w: 110, v: 0.6, pri: 5, ws: 10, we: 15 },
  ];
  for (const o of orders) {
    await prisma.order.upsert({
      where: { id: o.id },
      create: {
        id: o.id, distributorId: `seed-dist-${o.id.split('-').pop()}`, distributorName: o.name,
        lat: o.lat, lng: o.lng, weightKg: o.w, volumeM3: o.v, priority: o.pri,
        timeWindowStart: tw(o.ws), timeWindowEnd: tw(o.we), status: 'PENDING', totalQuantity: 10,
      },
      update: {},
    });
  }

  // ── Route 1: DISPATCHED (driver demo) ─────────────────
  const routeId = 'route-today-d201';
  const route = await prisma.routePlan.upsert({
    where: { id: routeId },
    create: {
      id: routeId, date: dateOnly, vehicleId: 'V-101', driverId: 'D-201',
      status: 'DISPATCHED', version: 1, plannedKm: 42.5, plannedMin: 240,
      startLat: 9.0108, startLng: 38.7613,
    },
    update: {},
  });
  const seedStops = [
    { seq: 1, name: 'Bole Retail',       lat: 8.9948, lng: 38.7923, qty: 10 },
    { seq: 2, name: 'Kazanchis Mart',    lat: 9.0167, lng: 38.7667, qty: 15 },
    { seq: 3, name: 'Piassa Traders',    lat: 9.0333, lng: 38.7500, qty: 12 },
    { seq: 4, name: 'Merkato Wholesale', lat: 9.0348, lng: 38.7466, qty: 25 },
    { seq: 5, name: 'Saris Corner',      lat: 8.9900, lng: 38.7400, qty: 8 },
  ];
  for (const s of seedStops) {
    const id = `${routeId}-stop-${s.seq}`;
    await prisma.routeStop.upsert({
      where: { id },
      create: {
        id, routePlanId: route.id, seq: s.seq,
        distributorId: `seed-dist-${s.seq}`, distributorName: s.name,
        lat: s.lat, lng: s.lng,
        plannedEta: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 8 + s.seq, 0, 0)),
        status: 'PENDING', quantityOrdered: s.qty, pickedAt: new Date(),
      },
      update: {},
    });
  }

  // ── Route 2: PLANNED, slot allocated (warehouse demo) ─
  const routeId2 = 'route-today-v102';
  const route2 = await prisma.routePlan.upsert({
    where: { id: routeId2 },
    create: {
      id: routeId2, date: dateOnly, vehicleId: 'V-102', driverId: 'D-202',
      status: 'PLANNED', version: 1, plannedKm: 38.2, plannedMin: 220,
      startLat: 9.0108, startLng: 38.7613,
    },
    update: {},
  });
  const stops2 = [
    { seq: 1, name: 'CMC Store',        lat: 9.0200, lng: 38.8300, qty: 12 },
    { seq: 2, name: 'Bole Medhanialem', lat: 9.0050, lng: 38.7850, qty: 8 },
    { seq: 3, name: 'Megenagna Shop',   lat: 9.0200, lng: 38.8000, qty: 15 },
    { seq: 4, name: 'Sarbet Retail',    lat: 8.9950, lng: 38.7600, qty: 10 },
  ];
  for (const s of stops2) {
    const id = `${routeId2}-stop-${s.seq}`;
    await prisma.routeStop.upsert({
      where: { id },
      create: {
        id, routePlanId: route2.id, seq: s.seq,
        distributorId: `seed-dist-v102-${s.seq}`, distributorName: s.name,
        lat: s.lat, lng: s.lng,
        plannedEta: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 8 + s.seq, 0, 0)),
        status: 'PENDING', quantityOrdered: s.qty,
      },
      update: {},
    });
  }
  await prisma.dispatchDockSlot.upsert({
    where: { id: 'dock-a-slot-0' },
    create: {
      id: 'dock-a-slot-0', dockId: 'dock-a', date: dateOnly,
      startAt: new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 6, 0, 0)),
      endAt:   new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 7, 0, 0)),
      status: 'ALLOCATED', routePlanId: routeId2,
    },
    update: {},
  });

  // ── Route 3: yesterday, COMPLETED (finance demo) ──────
  const yesterday = dateOnly;
  const yId = 'route-yesterday-v103';
  const yRoute = await prisma.routePlan.upsert({
    where: { id: yId },
    create: {
      id: yId, date: new Date(yesterday.getTime() - 86_400_000),
      vehicleId: 'V-103', driverId: 'D-203',
      status: 'COMPLETED', version: 1, plannedKm: 30, plannedMin: 180,
      startLat: 9.0108, startLng: 38.7613,
    },
    update: {},
  });
  const yStops = [
    { seq: 1, name: 'Sarbet Retail',       qty: 10, amount: 500, method: 'CASH' as const, ref: null as string | null },
    { seq: 2, name: 'Old Airport Grocer',  qty: 15, amount: 750, method: 'CASH' as const, ref: null },
    { seq: 3, name: 'Haya Hulet Shop',     qty: 18, amount: 900, method: 'TELEBIRR' as const, ref: 'TB-SEED-DEMO-1' },
  ];
  for (const s of yStops) {
    const stopId = `${yId}-stop-${s.seq}`;
    await prisma.routeStop.upsert({
      where: { id: stopId },
      create: {
        id: stopId, routePlanId: yRoute.id, seq: s.seq,
        distributorId: `seed-dist-${s.seq}`, distributorName: s.name,
        lat: 9.0108, lng: 38.7613,
        plannedEta: new Date(yesterday.getTime() - 86_400_000 + (8 + s.seq) * 3600_000),
        status: 'DELIVERED', quantityOrdered: s.qty, pickedAt: daysAgo(2),
      },
      update: {},
    });
    await prisma.proofOfDelivery.upsert({
      where: { id: `proof-y-${s.seq}` },
      create: {
        id: `proof-y-${s.seq}`, routeStopId: stopId, outcome: 'DELIVERED',
        qtyConfirmed: s.qty, qtyOrdered: s.qty,
        signatureBase64: 'data:image/png;base64,seed',
        clientOpId: `seed-op-y-${s.seq}`, capturedAt: daysAgo(1),
      },
      update: {},
    });
    await prisma.payment.upsert({
      where: { id: `payment-y-${s.seq}` },
      create: {
        id: `payment-y-${s.seq}`, routeStopId: stopId,
        method: s.method, amountEtb: s.amount, telebirrRef: s.ref,
        clientOpId: `seed-pay-y-${s.seq}`, capturedAt: daysAgo(1),
      },
      update: {},
    });
  }

  // ── Demo fuel history ──────────────────────────────────
  const demoFills = [
    { id: 'seed-fuel-v101-1', vehicleId: 'V-101', liters: 60, amount: 620, odo: 44800, capturedDaysAgo: 4, flag: 'NO_BASELINE', ratio: null },
    { id: 'seed-fuel-v101-2', vehicleId: 'V-101', liters: 60, amount: 620, odo: 45300, capturedDaysAgo: 2, flag: 'OK', ratio: 1.0 },
    { id: 'seed-fuel-v102-1', vehicleId: 'V-102', liters: 55, amount: 570, odo: 32100, capturedDaysAgo: 4, flag: 'NO_BASELINE', ratio: null },
    { id: 'seed-fuel-v102-2', vehicleId: 'V-102', liters: 54, amount: 560, odo: 32550, capturedDaysAgo: 2, flag: 'OK', ratio: 1.0 },
    { id: 'seed-fuel-v103-1', vehicleId: 'V-103', liters: 50, amount: 520, odo: 51200, capturedDaysAgo: 3, flag: 'OK', ratio: 1.0 },
  ];
  for (const f of demoFills) {
    await prisma.fuelLog.upsert({
      where: { id: f.id },
      create: {
        id: f.id, driverId: 'D-201', vehicleId: f.vehicleId,
        liters: f.liters, amountEtb: f.amount, odometerKm: f.odo,
        stationName: 'Bole Total', varianceFlag: f.flag, varianceRatio: f.ratio,
        clientOpId: `seed-${f.id}`, capturedAt: daysAgo(f.capturedDaysAgo),
      },
      update: {},
    });
  }

  // ── Portal demo orders (2 pending + 1 delivered) ───────
  const skuByCode = new Map((await prisma.sku.findMany()).map((s) => [s.code, s]));
  const portalOrders = [
    { id: 'portal-order-1', daysAgo: 0, status: 'PENDING', lines: [{ code: 'SKU-COKE-500', qty: 50 }, { code: 'SKU-PEPSI-500', qty: 30 }] },
    { id: 'portal-order-2', daysAgo: 1, status: 'PENDING', lines: [{ code: 'SKU-WATER-1L', qty: 100 }, { code: 'SKU-BREAD', qty: 40 }] },
    { id: 'portal-order-3', daysAgo: 3, status: 'DELIVERED', lines: [{ code: 'SKU-MILK-1L', qty: 25 }] },
  ];
  for (const po of portalOrders) {
    const createdAt = daysAgo(po.daysAgo);
    const lines = po.lines.map((l) => {
      const sku = skuByCode.get(l.code)!;
      return {
        skuId: sku.id, skuCode: sku.code, skuName: sku.name,
        quantity: l.qty, unitPrice: Number(sku.unitPriceEtb), lineTotal: l.qty * Number(sku.unitPriceEtb),
        weightKg: l.qty * Number(sku.weightKg), volumeM3: l.qty * Number(sku.volumeM3),
      };
    });
    const totalQty = lines.reduce((s, l) => s + l.quantity, 0);
    const totalWeight = lines.reduce((s, l) => s + l.weightKg, 0);
    const totalVolume = lines.reduce((s, l) => s + l.volumeM3, 0);
    await prisma.order.upsert({
      where: { id: po.id },
      create: {
        id: po.id, distributorId: 'seed-dist-1', distributorName: 'Abebe Distribution',
        lat: 9.0200, lng: 38.7800, weightKg: totalWeight, volumeM3: totalVolume, priority: 5,
        timeWindowStart: new Date(createdAt.getTime() + 3600_000),
        timeWindowEnd: new Date(createdAt.getTime() + 86_400_000),
        status: po.status, totalQuantity: totalQty, createdAt,
        lines: { create: lines.map((l) => ({ skuId: l.skuId, skuCode: l.skuCode, skuName: l.skuName, quantity: l.quantity, unitPrice: l.unitPrice, lineTotal: l.lineTotal })) },
      },
      update: {},
    });
  }

  // ── Settings ───────────────────────────────────────────
  await prisma.setting.upsert({
    where: { key: 'credit.hardGate' }, create: { key: 'credit.hardGate', value: 'false' }, update: {},
  });
  await prisma.setting.upsert({
    where: { key: 'analytics.demoMode' }, create: { key: 'analytics.demoMode', value: 'true' }, update: {},
  });

  console.log('seed: ok');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
EOF

# Update bootstrap to include migrate+seed
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

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Part 1b complete — Phases 1 (credit) + 2 (geo/routing/orders)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Backend is now RUNNABLE:"
echo ""
echo "  cp .env.example .env"
echo "  pnpm install"
echo "  docker compose up -d mysql redis"
echo "  pnpm db:generate && pnpm db:migrate && pnpm db:seed"
echo "  pnpm --filter @tera/api dev"
echo ""
echo "Test with curl:"
echo "  curl http://localhost:8000/health                          → {ok:true}"
echo "  curl http://localhost:8000/credit/v1/stop-list            → 5 warnings"
echo "  curl http://localhost:8000/credit/v1/exposure             → aging buckets"
echo "  curl http://localhost:8000/geo/v1/curfew-zones?includeInactive=1  → 4 zones"
echo "  curl http://localhost:8000/orders/v1/pending              → 8 + 2 pending"
echo "  curl http://localhost:8000/routing/v1/vehicles            → 3 vehicles"
echo "  curl http://localhost:8000/routing/v1/routes/today        → 2 routes"
echo "  curl http://localhost:8000/routing/v1/routes/route-today-v102/pick-list  → 4 stops"
echo ""
echo "Tests:"
echo "  pnpm --filter @tera/api test    # 10 credit rules + finance + 9 geo + 4 routing = 23 tests"
echo "  pnpm --filter @tera/solver test # 13 solver tests"
echo ""
echo "Docs:"
echo "  http://localhost:8000/docs      → Swagger UI"
echo ""
echo "📌 Next: Part 1c (Phase 2 frontend — dispatcher app + 3 modules)"
echo ""
echo "════════════════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════
# PHASE 2 FRONTEND — DISPATCHER WEB (4 modules)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 2 frontend — dispatcher-web (4 modules)"

# ── app shell ──────────────────────────────────────────────
W apps/dispatcher-web/package.json <<'EOF'
{
  "name": "dispatcher-web",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "test": "vitest run",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.24.0",
    "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*",
    "@tera/i18n": "workspace:*",
    "@tera/contracts": "workspace:*",
    "leaflet": "^1.9.4",
    "react-leaflet": "^4.2.1"
  },
  "devDependencies": {
    "vite": "^5.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.4.0",
    "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.4.0",
    "jsdom": "^24.1.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@types/leaflet": "^1.9.12"
  }
}
EOF

W apps/dispatcher-web/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "composite": true, "outDir": "dist", "noEmit": true, "types": ["vite/client"] }, "include": ["src"] }
EOF
W apps/dispatcher-web/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], server: { port: 5173 } });
EOF
W apps/dispatcher-web/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [react()],
  test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], globals: true, css: false },
});
EOF
W apps/dispatcher-web/tailwind.config.ts <<'EOF'
import type { Config } from 'tailwindcss';
import preset from '@tera/ui/tailwind-preset';
export default {
  presets: [preset],
  content: ['./index.html', './src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'],
} satisfies Config;
EOF
W apps/dispatcher-web/postcss.config.cjs <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF
W apps/dispatcher-web/index.html <<'EOF'
<!doctype html>
<html lang="am">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Ethiopic:wght@400;500;600;700&display=swap" rel="stylesheet" />
    <title>ተራ OMS · ዲስፓቸር</title>
  </head>
  <body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body>
</html>
EOF
W apps/dispatcher-web/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base {
  html, body, #root { height: 100%; }
  body { background-color: theme('colors.bg'); color: theme('colors.text'); font-family: theme('fontFamily.sans'); -webkit-font-smoothing: antialiased; }
}
EOF
W apps/dispatcher-web/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_BASE_URL: string; readonly VITE_DEFAULT_LOCALE: string; }
interface ImportMeta { readonly env: ImportMetaEnv; }
EOF
W apps/dispatcher-web/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
W apps/dispatcher-web/src/api/client.ts <<'EOF'
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
EOF
W apps/dispatcher-web/src/api/queryClient.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15_000,
      retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2),
    },
  },
});
EOF
W apps/dispatcher-web/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { AppRouter } from './app/routes';
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppProviders><AppRouter /></AppProviders>
  </React.StrictMode>,
);
EOF
W apps/dispatcher-web/src/app/AppProviders.tsx <<'EOF'
import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';
const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';
export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <I18nProvider initialLocale={locale}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </I18nProvider>
  );
}
EOF
W apps/dispatcher-web/src/app/AppLayout.tsx <<'EOF'
import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';

const NAV = [
  { to: '/routes',  key: 'nav.routes' },
  { to: '/builder', key: 'nav.route_builder' },
  { to: '/board',   key: 'nav.dispatch_board' },
  { to: '/credit',  key: 'nav.credit' },
];

export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="min-h-full flex">
      <aside className="w-56 shrink-0 border-r border-border bg-surface flex flex-col">
        <div className="px-5 py-4 border-b border-border">
          <p className="text-sm text-muted">{t('app.name')}</p>
          <p className="text-base font-semibold">{t('nav.dispatch')}</p>
        </div>
        <nav className="flex-1 p-2">
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to}
              className={({ isActive }) =>
                `block px-3 py-2 rounded-md text-sm ${
                  isActive ? 'bg-bg text-text font-medium' : 'text-muted hover:bg-bg'
                }`
              }>
              {t(n.key)}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="flex-1 min-w-0 p-6"><Outlet /></main>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { MorningMapPage } from '../modules/morning-map';
import { RouteBuilderPage } from '../modules/route-builder';
import { DispatchBoardPage } from '../modules/dispatch-board';
import { CreditStopListPage } from '../modules/credit-stop-list';

const router = createBrowserRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <Navigate to="/routes" replace /> },
      { path: 'routes',  element: <MorningMapPage /> },
      { path: 'builder', element: <RouteBuilderPage /> },
      { path: 'board',   element: <DispatchBoardPage /> },
      { path: 'credit',  element: <CreditStopListPage /> },
    ],
  },
]);

export function AppRouter() { return <RouterProvider router={router} />; }
EOF

# ═══════════════════════════════════════════════════════════════════
# MODULE 1 — credit-stop-list
# ═══════════════════════════════════════════════════════════════════
W apps/dispatcher-web/src/modules/credit-stop-list/types.ts <<'EOF'
export type {
  CreditDecision, CreditReason, CreditStopRow, CreditStopListResponse, OverrideRequest,
} from '@tera/contracts';
export type CreditFilter = 'ALL' | 'OVERDUE_30' | 'OVER_LIMIT';
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/api.ts <<'EOF'
import { api } from '../../api/client';
import type { CreditStopListResponse, OverrideRequest } from './types';

export const creditKeys = {
  all: ['credit'] as const,
  stopList: () => [...creditKeys.all, 'stop-list', 'today'] as const,
};
export function fetchCreditStopList(signal?: AbortSignal) {
  return api<CreditStopListResponse>({ path: '/credit/v1/stop-list', signal });
}
export function overrideCredit(req: OverrideRequest) {
  return api<{ ok: true; expires_at: string }>({ method: 'POST', path: '/credit/v1/overrides', body: req });
}
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { creditKeys, fetchCreditStopList, overrideCredit } from './api';
import type { OverrideRequest } from './types';

export function useCreditStopList() {
  return useQuery({
    queryKey: creditKeys.stopList(),
    queryFn: ({ signal }) => fetchCreditStopList(signal),
    refetchInterval: 60_000,
  });
}
export function useOverrideCredit() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: OverrideRequest) => overrideCredit(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: creditKeys.all }),
  });
}
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/components/StatusBadge.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { CreditDecision, CreditReason } from '../types';

const TONE = { BLOCKED: 'danger', WARNED: 'warn', CLEARED: 'success' } as const;
const DECISION_KEY: Record<CreditDecision, string> = {
  BLOCKED: 'credit.status.blocked', WARNED: 'credit.status.warned', CLEARED: 'credit.status.cleared',
};
const REASON_KEY: Record<CreditReason, string> = {
  OVER_LIMIT: 'credit.reason.over_limit', PAST_GRACE: 'credit.reason.past_grace',
  BOTH: 'credit.reason.both', NONE: 'credit.status.cleared',
};
export function StatusBadge({ decision }: { decision: CreditDecision }) {
  const { t } = useI18n();
  return <StatusPill tone={TONE[decision]}>{t(DECISION_KEY[decision])}</StatusPill>;
}
export function ReasonText({ reason }: { reason: CreditReason }) {
  const { t } = useI18n();
  if (reason === 'NONE') return null;
  return <span className="text-muted text-xs">{t(REASON_KEY[reason])}</span>;
}
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/components/FilterTabs.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import type { CreditFilter } from '../types';

const FILTERS: { id: CreditFilter; key: string }[] = [
  { id: 'ALL', key: 'credit.filter.all' },
  { id: 'OVERDUE_30', key: 'credit.filter.overdue_30' },
  { id: 'OVER_LIMIT', key: 'credit.filter.over_limit' },
];
export function FilterTabs({ value, onChange }: { value: CreditFilter; onChange: (f: CreditFilter) => void }) {
  const { t } = useI18n();
  return (
    <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
      {FILTERS.map((f) => (
        <button key={f.id} onClick={() => onChange(f.id)}
          className={`px-3 py-1.5 text-sm rounded ${value === f.id ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>
          {t(f.key)}
        </button>
      ))}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/components/OverrideDialog.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreditStopRow, OverrideRequest } from '../types';

interface Props {
  row: CreditStopRow;
  onSubmit: (req: OverrideRequest) => void;
  onCancel: () => void;
  isPending: boolean;
  errorMessage?: string;
}
function defaultExpiry(): string { return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(); }

export function OverrideDialog({ row, onSubmit, onCancel, isPending, errorMessage }: Props) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  const [expiresAt, setExpiresAt] = useState(defaultExpiry());
  const canSubmit = reason.trim().length >= 5 && !isPending;

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-lg p-6">
        <h2 className="text-lg font-semibold">{t('credit.override')}</h2>
        <p className="text-sm text-muted mt-1">{row.distributor_name} · {row.region}</p>
        <label className="block mt-4 text-sm">
          <span className="text-muted">{t('credit.override_reason')}</span>
          <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3}
            className="mt-1 w-full rounded-md border border-border bg-bg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary" />
        </label>
        <label className="block mt-4 text-sm">
          <span className="text-muted">{t('credit.override_expires')}</span>
          <input type="datetime-local" value={expiresAt.slice(0, 16)}
            onChange={(e) => setExpiresAt(new Date(e.target.value).toISOString())}
            className="mt-1 w-full rounded-md border border-border bg-bg px-3 py-2" />
        </label>
        {errorMessage && <p className="mt-3 text-sm text-danger">{errorMessage}</p>}
        <div className="mt-6 flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isPending}>{t('common.cancel')}</Button>
          <Button variant="danger" disabled={!canSubmit} loading={isPending}
            onClick={() => onSubmit({ distributor_id: row.distributor_id, reason: reason.trim(), expires_at: expiresAt })}>
            {t('credit.override_confirm')}
          </Button>
        </div>
      </div>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/CreditStopListPage.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, DataTable, EmptyState, Money, Spinner, type Column } from '@tera/ui';
import { FilterTabs } from './components/FilterTabs';
import { OverrideDialog } from './components/OverrideDialog';
import { ReasonText, StatusBadge } from './components/StatusBadge';
import { useCreditStopList, useOverrideCredit } from './hooks';
import type { CreditFilter, CreditStopRow, OverrideRequest } from './types';

export function CreditStopListPage() {
  const { t } = useI18n();
  const [filter, setFilter] = useState<CreditFilter>('ALL');
  const [overrideFor, setOverrideFor] = useState<CreditStopRow | null>(null);
  const { data, isLoading, isError, refetch } = useCreditStopList();
  const override = useOverrideCredit();

  const rows = useMemo(() => {
    const all = data?.rows ?? [];
    switch (filter) {
      case 'OVERDUE_30': return all.filter((r) => r.days_overdue >= 30);
      case 'OVER_LIMIT': return all.filter((r) => r.exposure_etb > r.credit_limit_etb);
      default: return all;
    }
  }, [data, filter]);

  const columns: Column<CreditStopRow>[] = [
    { key: 'distributor', header: t('credit.table.distributor'), render: (r) => (
      <div><div className="font-medium">{r.distributor_name}</div><ReasonText reason={r.reason} /></div>
    )},
    { key: 'region', header: t('credit.table.region'), render: (r) => r.region },
    { key: 'status', header: t('credit.table.status'), render: (r) => <StatusBadge decision={r.decision} /> },
    { key: 'owed', header: t('credit.amount_owed'), align: 'right', render: (r) => <Money value={r.amount_owed_etb} bold /> },
    { key: 'limit', header: t('credit.limit'), align: 'right', render: (r) => <Money value={r.credit_limit_etb} /> },
    { key: 'overdue', header: t('credit.days_overdue'), align: 'right', render: (r) => r.days_overdue },
    { key: 'actions', header: t('credit.table.actions'), align: 'right', render: (r) => (
      <Button size="sm" variant="secondary" onClick={() => setOverrideFor(r)}>{t('credit.override')}</Button>
    )},
  ];

  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">{t('credit.title')}</h1>
        <p className="text-sm text-muted mt-1">{t('credit.subtitle')}</p>
        {data && !data.hard_gate && (
          <p className="text-xs text-warn bg-warnBg border border-warn/30 rounded px-2 py-1 mt-2 inline-block">
            {t('common.optional')}: soft mode — blocks are warnings, not hard stops
          </p>
        )}
      </header>
      <div className="flex items-center justify-between mb-4">
        <FilterTabs value={filter} onChange={setFilter} />
        <Button variant="ghost" size="sm" onClick={() => refetch()}>{t('common.retry')}</Button>
      </div>
      {isLoading && <Spinner label={t('common.loading')} />}
      {isError && (
        <div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
          {t('common.error')}{' '}<button onClick={() => refetch()} className="underline">{t('common.retry')}</button>
        </div>
      )}
      {!isLoading && !isError && (
        rows.length === 0
          ? <EmptyState title={t('credit.no_blocked')} />
          : <DataTable columns={columns} rows={rows} rowKey={(r) => r.distributor_id} emptyMessage={t('common.empty')} />
      )}
      {overrideFor && (
        <OverrideDialog row={overrideFor} isPending={override.isPending}
          errorMessage={override.isError ? t('common.error') : undefined}
          onCancel={() => { setOverrideFor(null); override.reset(); }}
          onSubmit={(req: OverrideRequest) => override.mutate(req, { onSuccess: () => setOverrideFor(null) })} />
      )}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/index.ts <<'EOF'
export { CreditStopListPage } from './CreditStopListPage';
export type { CreditStopRow, CreditDecision, CreditReason } from './types';
EOF
W apps/dispatcher-web/src/modules/credit-stop-list/__tests__/CreditStopListPage.test.tsx <<'EOF'
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { CreditStopListPage } from '../CreditStopListPage';

vi.mock('../api', () => ({
  creditKeys: { all: ['credit'], stopList: () => ['credit', 'stop-list', 'today'] },
  fetchCreditStopList: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(), hard_gate: false,
    rows: [{ distributor_id: 'd1', distributor_name: 'Abebe Distribution', region: 'Addis',
      decision: 'WARNED', reason: 'OVER_LIMIT', amount_owed_etb: 120_000, credit_limit_etb: 100_000,
      exposure_etb: 120_000, days_overdue: 42, grace_days: 14,
      blocked_at: new Date().toISOString(), active_override_until: null }],
  }),
  overrideCredit: vi.fn(),
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('CreditStopListPage', () => {
  it('renders title, soft banner, and distributor row', async () => {
    wrap(<CreditStopListPage />);
    expect(screen.getByText('Credit Stop List')).toBeInTheDocument();
    expect(await screen.findByText('Abebe Distribution')).toBeInTheDocument();
    expect(screen.getByText(/soft mode/i)).toBeInTheDocument();
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# MODULE 2 — morning-map
# ═══════════════════════════════════════════════════════════════════
W apps/dispatcher-web/src/modules/morning-map/types.ts <<'EOF'
import type { RoutePlan, CurfewZone, FuelStation } from '@tera/contracts';
export type { RoutePlan, CurfewZone, FuelStation };
export type LiveRouteStatus = 'on-track' | 'late' | 'off-route';
export interface LiveVehicle {
  route: RoutePlan; current_stop_index: number;
  status: LiveRouteStatus; minutes_behind: number;
}
EOF
W apps/dispatcher-web/src/modules/morning-map/api.ts <<'EOF'
import { api } from '../../api/client';
import type { RoutePlan, CurfewZone, FuelStation } from '@tera/contracts';

export const morningMapKeys = {
  all: ['morning-map'] as const,
  routes: () => [...morningMapKeys.all, 'routes'] as const,
  zones: () => [...morningMapKeys.all, 'zones'] as const,
  stations: () => [...morningMapKeys.all, 'stations'] as const,
};
export function fetchTodayRoutes(signal?: AbortSignal) {
  return api<{ as_of: string; routes: RoutePlan[] }>({ path: '/routing/v1/routes/today', signal });
}
export function fetchCurfewZones(signal?: AbortSignal) {
  return api<{ zones: CurfewZone[] }>({ path: '/geo/v1/curfew-zones', signal });
}
export function fetchFuelStations(signal?: AbortSignal) {
  return api<{ stations: FuelStation[] }>({ path: '/geo/v1/fuel-stations', signal });
}
EOF
W apps/dispatcher-web/src/modules/morning-map/hooks.ts <<'EOF'
import { useQuery } from '@tanstack/react-query';
import { morningMapKeys, fetchTodayRoutes, fetchCurfewZones, fetchFuelStations } from './api';
import type { RoutePlan } from './types';

export function useTodayRoutes() {
  return useQuery({ queryKey: morningMapKeys.routes(), queryFn: ({ signal }) => fetchTodayRoutes(signal), refetchInterval: 30_000 });
}
export function useCurfewZones() {
  return useQuery({ queryKey: morningMapKeys.zones(), queryFn: ({ signal }) => fetchCurfewZones(signal), refetchInterval: 300_000 });
}
export function useFuelStations() {
  return useQuery({ queryKey: morningMapKeys.stations(), queryFn: ({ signal }) => fetchFuelStations(signal), refetchInterval: 300_000 });
}

export function deriveLiveVehicles(routes: RoutePlan[]): LiveVehicleDerived[] {
  const now = Date.now();
  return routes.map((route) => {
    const currentIndex = route.stops.findIndex((s) => s.status === 'PENDING');
    const idx = currentIndex < 0 ? route.stops.length - 1 : currentIndex;
    const current = route.stops[idx];
    const etaMs = current ? new Date(current.planned_eta).getTime() : now;
    const minutesBehind = Math.max(0, Math.round((now - etaMs) / 60_000));
    const status = minutesBehind > 20 ? 'late' : 'on-track';
    return { route, current_stop_index: idx, status, minutes_behind: minutesBehind };
  });
}
interface LiveVehicleDerived {
  route: RoutePlan; current_stop_index: number;
  status: 'on-track' | 'late'; minutes_behind: number;
}
EOF
W apps/dispatcher-web/src/modules/morning-map/components/MapCanvas.tsx <<'EOF'
import { useEffect } from 'react';
import { MapContainer, TileLayer, Polyline, CircleMarker, Polygon, Popup, Marker } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { RoutePlan, CurfewZone, FuelStation } from '../types';

delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

const ROUTE_COLORS = ['#0f766e', '#b45309', '#7c3aed', '#0891b2', '#be123c'];
const FALLBACK_CENTER: [number, number] = [9.0108, 38.7613];

function geoJsonToLatLngs(geojson: CurfewZone['polygon']): [number, number][] {
  return geojson.coordinates[0]!.map(([lng, lat]) => [lat, lng] as [number, number]);
}
interface Props {
  routes: RoutePlan[]; curfewZones: CurfewZone[]; fuelStations: FuelStation[];
  selectedRouteId: string | null;
  onSelectRoute: (id: string) => void;
}
export function MapCanvas({ routes, curfewZones, fuelStations, selectedRouteId, onSelectRoute }: Props) {
  useEffect(() => {
    const t = setTimeout(() => window.dispatchEvent(new Event('resize')), 200);
    return () => clearTimeout(t);
  }, []);
  return (
    <div className="w-full h-full min-h-[500px] rounded-md overflow-hidden border border-border">
      <MapContainer center={FALLBACK_CENTER} zoom={12} style={{ width: '100%', height: '100%' }}>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {curfewZones.map((z) => (
          <Polygon key={z.id} positions={geoJsonToLatLngs(z.polygon)}
            pathOptions={{ color: '#b91c1c', fillOpacity: 0.12, weight: 1.5, dashArray: '4 4' }}>
            <Popup><strong>{z.name}</strong><br />{String(z.start_hour).padStart(2, '0')}:00 – {String(z.end_hour).padStart(2, '0')}:00<br /><em>{z.reason}</em></Popup>
          </Polygon>
        ))}
        {routes.map((route, i) => {
          const color = ROUTE_COLORS[i % ROUTE_COLORS.length]!;
          const positions: [number, number][] = [
            [route.start_lat, route.start_lng],
            ...route.stops.map((s) => [s.lat, s.lng] as [number, number]),
          ];
          const isSelected = route.id === selectedRouteId;
          return (
            <div key={route.id}>
              <Polyline positions={positions}
                pathOptions={{ color, weight: isSelected ? 5 : 3, opacity: isSelected ? 1 : 0.65 }}
                eventHandlers={{ click: () => onSelectRoute(route.id) }} />
              <CircleMarker center={[route.start_lat, route.start_lng]} radius={8}
                pathOptions={{ color, fillColor: color, fillOpacity: 1 }}>
                <Popup>Vehicle {route.vehicle_id} · start</Popup>
              </CircleMarker>
              {route.stops.map((s) => (
                <CircleMarker key={s.id} center={[s.lat, s.lng]}
                  radius={s.status === 'DELIVERED' ? 5 : 7}
                  pathOptions={{
                    color: s.status === 'DELIVERED' ? '#6b6b6b' : color,
                    fillColor: s.status === 'DELIVERED' ? '#a3a3a3' : '#ffffff',
                    fillOpacity: 1, weight: 2,
                  }}>
                  <Popup><strong>{s.distributor_name}</strong><br />Seq {s.seq} · {s.status}</Popup>
                </CircleMarker>
              ))}
            </div>
          );
        })}
        {fuelStations.map((f) => (
          <Marker key={f.id} position={[f.lat, f.lng]}>
            <Popup><strong>{f.name}</strong><br />{f.status}</Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/morning-map/components/VehicleList.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { RoutePlan } from '../types';

interface Props {
  routes: RoutePlan[];
  liveByRouteId: Map<string, { current_stop_index: number; status: 'on-track' | 'late'; minutes_behind: number }>;
  selectedRouteId: string | null;
  onSelectRoute: (id: string) => void;
}
export function VehicleList({ routes, liveByRouteId, selectedRouteId, onSelectRoute }: Props) {
  const { t } = useI18n();
  if (routes.length === 0) {
    return <div className="text-muted text-sm p-4 border border-border rounded-md bg-surface">{t('morning_map.no_routes')}</div>;
  }
  return (
    <div className="flex flex-col gap-2">
      {routes.map((r) => {
        const live = liveByRouteId.get(r.id);
        const isSelected = r.id === selectedRouteId;
        const delivered = r.stops.filter((s) => s.status === 'DELIVERED').length;
        return (
          <button key={r.id} onClick={() => onSelectRoute(r.id)}
            className={`text-left p-3 rounded-md border transition ${isSelected ? 'border-primary bg-surface' : 'border-border bg-surface hover:bg-bg'}`}>
            <div className="flex items-center justify-between">
              <span className="font-medium text-sm">{r.vehicle_id}</span>
              {live && (
                <StatusPill tone={live.status === 'late' ? 'danger' : 'success'}>
                  {live.status === 'late' ? t('morning_map.status.late') : t('morning_map.status.on_track')}
                </StatusPill>
              )}
            </div>
            <div className="text-xs text-muted mt-1">{r.driver_id} · {delivered}/{r.stops.length} {t('morning_map.stops_delivered')}</div>
            {live && live.minutes_behind > 0 && (
              <div className="text-xs text-danger mt-1">{live.minutes_behind} {t('time.minutes_short')}</div>
            )}
          </button>
        );
      })}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/morning-map/components/MapLegend.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
export function MapLegend() {
  const { t } = useI18n();
  return (
    <div className="flex flex-wrap gap-4 text-xs text-muted bg-surface border border-border rounded-md px-3 py-2">
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-full bg-primary" />{t('morning_map.legend.route')}</span>
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-full bg-gray-400" />{t('morning_map.legend.delivered')}</span>
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-sm bg-red-100 border border-red-400 border-dashed" />{t('morning_map.legend.curfew')}</span>
      <span className="flex items-center gap-1.5"><span className="inline-block w-3 h-3 rounded-full bg-amber-500" />{t('morning_map.legend.fuel')}</span>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/morning-map/components/FallbackTable.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { DataTable, type Column } from '@tera/ui';
import type { RoutePlan } from '../types';

export function FallbackTable({ routes }: { routes: RoutePlan[] }) {
  const { t } = useI18n();
  const flat = routes.flatMap((r) => r.stops.map((s) => ({
    route_id: r.id, vehicle_id: r.vehicle_id, seq: s.seq,
    distributor_name: s.distributor_name, status: s.status, planned_eta: s.planned_eta,
  })));
  const columns: Column<(typeof flat)[number]>[] = [
    { key: 'vehicle', header: t('morning_map.table.vehicle'), render: (r) => r.vehicle_id },
    { key: 'seq', header: '#', render: (r) => r.seq, align: 'right' },
    { key: 'distributor', header: t('credit.table.distributor'), render: (r) => r.distributor_name },
    { key: 'status', header: t('credit.table.status'), render: (r) => r.status },
    { key: 'eta', header: t('time.eta'), align: 'right',
      render: (r) => new Date(r.planned_eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) },
  ];
  return <DataTable columns={columns} rows={flat} rowKey={(r) => `${r.route_id}-${r.seq}`} emptyMessage={t('common.empty')} />;
}
EOF
W apps/dispatcher-web/src/modules/morning-map/MorningMapPage.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, Spinner } from '@tera/ui';
import { MapCanvas } from './components/MapCanvas';
import { VehicleList } from './components/VehicleList';
import { MapLegend } from './components/MapLegend';
import { FallbackTable } from './components/FallbackTable';
import { useTodayRoutes, useCurfewZones, useFuelStations, deriveLiveVehicles } from './hooks';

export function MorningMapPage() {
  const { t } = useI18n();
  const [selectedRouteId, setSelectedRouteId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<'map' | 'table'>('map');
  const routesQ = useTodayRoutes();
  const zonesQ = useCurfewZones();
  const stationsQ = useFuelStations();
  const isLoading = routesQ.isLoading || zonesQ.isLoading || stationsQ.isLoading;
  const isError = routesQ.isError || zonesQ.isError || stationsQ.isError;
  const routes = routesQ.data?.routes ?? [];
  const zones = zonesQ.data?.zones ?? [];
  const stations = stationsQ.data?.stations ?? [];

  const liveByRouteId = useMemo(() => {
    const map = new Map<string, { current_stop_index: number; status: 'on-track' | 'late'; minutes_behind: number }>();
    for (const v of deriveLiveVehicles(routes)) {
      map.set(v.route.id, { current_stop_index: v.current_stop_index, status: v.status, minutes_behind: v.minutes_behind });
    }
    return map;
  }, [routes]);

  const refetchAll = () => { void routesQ.refetch(); void zonesQ.refetch(); void stationsQ.refetch(); };

  if (isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (isError) {
    return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
      {t('common.error')}{' '}<button onClick={refetchAll} className="underline">{t('common.retry')}</button>
    </div></div>;
  }

  return (
    <div className="max-w-[1400px] mx-auto">
      <header className="mb-4 flex items-end justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{t('morning_map.title')}</h1>
          <p className="text-sm text-muted mt-1">{t('morning_map.subtitle')}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" onClick={() => setViewMode(viewMode === 'map' ? 'table' : 'map')}>
            {viewMode === 'map' ? t('morning_map.view_table') : t('morning_map.view_map')}
          </Button>
          <Button variant="secondary" size="sm" onClick={refetchAll}>{t('common.retry')}</Button>
        </div>
      </header>
      <div className="grid grid-cols-1 lg:grid-cols-[320px_1fr] gap-4">
        <aside className="flex flex-col gap-3">
          <VehicleList routes={routes} liveByRouteId={liveByRouteId} selectedRouteId={selectedRouteId} onSelectRoute={setSelectedRouteId} />
          <MapLegend />
        </aside>
        <section className="min-h-[500px]">
          {viewMode === 'map'
            ? <MapCanvas routes={routes} curfewZones={zones} fuelStations={stations} selectedRouteId={selectedRouteId} onSelectRoute={setSelectedRouteId} />
            : <FallbackTable routes={routes} />}
        </section>
      </div>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/morning-map/index.ts <<'EOF'
export { MorningMapPage } from './MorningMapPage';
export type { RoutePlan, CurfewZone, FuelStation, LiveVehicle } from './types';
EOF
W apps/dispatcher-web/src/modules/morning-map/__tests__/MorningMapPage.test.tsx <<'EOF'
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { MorningMapPage } from '../MorningMapPage';

vi.mock('../api', () => ({
  morningMapKeys: { all: ['mm'], routes: () => ['mm', 'routes'], zones: () => ['mm', 'zones'], stations: () => ['mm', 'stations'] },
  fetchTodayRoutes: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(),
    routes: [{ id: 'r1', vehicle_id: 'V-101', driver_id: 'D-201', status: 'DISPATCHED',
      planned_km: 42.5, planned_min: 240, start_lat: 9.0108, start_lng: 38.7613,
      stops: [
        { id: 's1', seq: 1, distributor_id: 'd1', distributor_name: 'Bole Retail',
          lat: 8.9948, lng: 38.7923, planned_eta: new Date().toISOString(), actual_arrival: new Date().toISOString(), status: 'DELIVERED' },
        { id: 's2', seq: 2, distributor_id: 'd2', distributor_name: 'Piassa Traders',
          lat: 9.0333, lng: 38.75, planned_eta: new Date(Date.now() + 3600_000).toISOString(), actual_arrival: null, status: 'PENDING' },
      ] }],
  }),
  fetchCurfewZones: vi.fn().mockResolvedValue({ zones: [] }),
  fetchFuelStations: vi.fn().mockResolvedValue({ stations: [] }),
}));

vi.mock('react-leaflet', () => ({
  MapContainer: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  TileLayer: () => null, Polyline: () => null, CircleMarker: () => null, Polygon: () => null, Marker: () => null,
  Popup: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
}));
vi.mock('leaflet', () => ({ default: { Icon: { Default: { prototype: {}, mergeOptions: () => {} } } } }));
vi.mock('leaflet/dist/leaflet.css', () => ({}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('MorningMapPage', () => {
  it('renders title and vehicle sidebar', async () => {
    wrap(<MorningMapPage />);
    expect(screen.getByText('Morning Map')).toBeInTheDocument();
    expect(await screen.findByText('V-101')).toBeInTheDocument();
    expect(screen.getByText(/1\/2/)).toBeInTheDocument();
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# MODULE 3 — route-builder
# ═══════════════════════════════════════════════════════════════════
W apps/dispatcher-web/src/modules/route-builder/types.ts <<'EOF'
export type {
  Order, Vehicle, SolveRequest, SolveResponse, SolveSequence,
  AcceptRouteRequest, AcceptRouteResponse,
  AsyncSolveStatus, AsyncSolveSubmitResponse, AsyncSolveJobResponse,
} from '@tera/contracts';
EOF
W apps/dispatcher-web/src/modules/route-builder/api.ts <<'EOF'
import { api } from '../../api/client';
import type {
  Order, Vehicle, SolveResponse, AcceptRouteRequest, AcceptRouteResponse,
  AsyncSolveSubmitResponse, AsyncSolveJobResponse,
} from './types';

export const routeBuilderKeys = {
  all: ['route-builder'] as const,
  pending: () => [...routeBuilderKeys.all, 'pending'] as const,
  vehicles: () => [...routeBuilderKeys.all, 'vehicles'] as const,
  solveJob: (id: string) => [...routeBuilderKeys.all, 'solve-job', id] as const,
};
export function fetchPendingOrders(signal?: AbortSignal) {
  return api<{ orders: Order[] }>({ path: '/orders/v1/pending', signal });
}
export function fetchVehicles(signal?: AbortSignal) {
  return api<{ vehicles: Vehicle[] }>({ path: '/routing/v1/vehicles', signal });
}
export function solveRoutes(body: { order_ids: string[]; vehicle_id: string }) {
  return api<SolveResponse>({ method: 'POST', path: '/routing/v1/solve', body });
}
export function submitAsyncSolve(body: { order_ids: string[]; vehicle_id: string }) {
  return api<AsyncSolveSubmitResponse>({ method: 'POST', path: '/routing/v1/solve/async', body });
}
export function getAsyncSolveJob(jobId: string, signal?: AbortSignal) {
  return api<AsyncSolveJobResponse>({ path: `/routing/v1/solve/jobs/${jobId}`, signal });
}
export function acceptRoute(body: AcceptRouteRequest) {
  return api<AcceptRouteResponse>({ method: 'POST', path: '/routing/v1/routes', body });
}
EOF
W apps/dispatcher-web/src/modules/route-builder/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { routeBuilderKeys, fetchPendingOrders, fetchVehicles, solveRoutes, submitAsyncSolve, getAsyncSolveJob, acceptRoute } from './api';
import type { AcceptRouteRequest } from './types';

export function usePendingOrders() {
  return useQuery({ queryKey: routeBuilderKeys.pending(), queryFn: ({ signal }) => fetchPendingOrders(signal) });
}
export function useVehicles() {
  return useQuery({ queryKey: routeBuilderKeys.vehicles(), queryFn: ({ signal }) => fetchVehicles(signal) });
}
export function useSolveRoutesSync() {
  return useMutation({ mutationFn: (input: { order_ids: string[]; vehicle_id: string }) => solveRoutes(input) });
}
export function useSubmitAsyncSolve() {
  return useMutation({ mutationFn: (input: { order_ids: string[]; vehicle_id: string }) => submitAsyncSolve(input) });
}
export function useAsyncSolveJob(jobId: string | null) {
  return useQuery({
    queryKey: jobId ? routeBuilderKeys.solveJob(jobId) : ['solve-job', 'none'],
    queryFn: ({ signal }) => getAsyncSolveJob(jobId!, signal),
    enabled: jobId !== null,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      if (status === 'DONE' || status === 'FAILED' || status === 'TIMEOUT') return false;
      return 500;
    },
  });
}
export function useAcceptRoute() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: AcceptRouteRequest) => acceptRoute(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: routeBuilderKeys.all }),
  });
}
EOF
W apps/dispatcher-web/src/modules/route-builder/components/OrderQueue.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import type { Order } from '../types';

interface Props {
  orders: Order[]; selected: Set<string>;
  onToggle: (id: string) => void;
  onSelectAll: () => void;
  onClearAll: () => void;
}
export function OrderQueue({ orders, selected, onToggle, onSelectAll, onClearAll }: Props) {
  const { t } = useI18n();
  if (orders.length === 0) {
    return <div className="text-muted text-sm p-4 border border-border rounded-md bg-surface">{t('route_builder.no_pending')}</div>;
  }
  return (
    <div className="border border-border rounded-md bg-surface">
      <div className="flex items-center justify-between px-3 py-2 border-b border-border">
        <span className="text-sm font-medium">{t('route_builder.pending_orders')} ({orders.length})</span>
        <div className="flex gap-1">
          <button className="text-xs text-muted hover:underline" onClick={onSelectAll}>{t('route_builder.select_all')}</button>
          <button className="text-xs text-muted hover:underline" onClick={onClearAll}>{t('route_builder.clear')}</button>
        </div>
      </div>
      <ul className="max-h-[420px] overflow-y-auto">
        {orders.map((o) => {
          const isSel = selected.has(o.id);
          return (
            <li key={o.id} className={`flex items-start gap-2 p-2 border-b border-border last:border-0 ${isSel ? 'bg-bg' : ''}`}>
              <input type="checkbox" checked={isSel} onChange={() => onToggle(o.id)} className="mt-1 accent-primary" />
              <button className="text-left flex-1 text-sm" onClick={() => onToggle(o.id)}>
                <div className="font-medium">{o.distributor_name}</div>
                <div className="text-xs text-muted">{o.weight_kg} kg · {o.volume_m3} m³ · {t('route_builder.priority')} {o.priority}</div>
                <div className="text-xs text-muted">
                  {new Date(o.time_window_start).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} –{' '}
                  {new Date(o.time_window_end).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/route-builder/components/VehicleSelector.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import type { Vehicle } from '../types';
export function VehicleSelector({ vehicles, selected, onSelect }: { vehicles: Vehicle[]; selected: string | null; onSelect: (id: string) => void }) {
  const { t } = useI18n();
  return (
    <div className="border border-border rounded-md bg-surface">
      <div className="px-3 py-2 border-b border-border text-sm font-medium">{t('route_builder.vehicle')}</div>
      <ul>
        {vehicles.map((v) => (
          <li key={v.id}>
            <button onClick={() => onSelect(v.id)}
              className={`w-full text-left px-3 py-2 text-sm border-b border-border last:border-0 ${selected === v.id ? 'bg-bg font-medium' : 'hover:bg-bg'}`}>
              <div>{v.plate}</div>
              <div className="text-xs text-muted">{v.capacity_kg} kg · {v.capacity_m3} m³ · shift {v.shift_start_h}:00–{v.shift_end_h}:00</div>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/route-builder/components/ComparisonView.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import type { SolveResponse, SolveSequence } from '../types';

function SequenceColumn({ title, seq, tone }: { title: string; seq: SolveSequence; tone: 'neutral' | 'primary' }) {
  return (
    <div className={`border rounded-md bg-surface ${tone === 'primary' ? 'border-primary' : 'border-border'}`}>
      <div className={`px-3 py-2 border-b ${tone === 'primary' ? 'border-primary bg-primary/5' : 'border-border'}`}>
        <div className="font-medium text-sm">{title}</div>
        <div className="text-xs text-muted mt-0.5">{seq.total_km.toFixed(1)} km · {seq.total_min} min</div>
      </div>
      <ol className="divide-y divide-border">
        {seq.stops.map((s) => (
          <li key={s.order_id} className="px-3 py-2 flex items-center gap-2 text-sm">
            <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-bg border border-border text-xs font-medium">{s.seq}</span>
            <div className="flex-1 min-w-0">
              <div className="font-medium truncate">{s.distributor_name}</div>
              <div className="text-xs text-muted">ETA {new Date(s.eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
}
export function ComparisonView({ solution }: { solution: SolveResponse }) {
  const { t } = useI18n();
  return (
    <div>
      {solution.infeasible && (
        <div className="mb-3 border border-danger/30 bg-dangerBg rounded-md p-3 text-sm text-danger">
          <strong>{t('route_builder.infeasible')}:</strong> {solution.infeasible.reason}
        </div>
      )}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SequenceColumn title={t('route_builder.manual')} seq={solution.manual} tone="neutral" />
        <SequenceColumn title={t('route_builder.optimized')} seq={solution.optimized} tone="primary" />
      </div>
      <div className="mt-4 flex items-center justify-center gap-3">
        <StatusPill tone={solution.savings_km_pct > 0 ? 'success' : 'neutral'}>{solution.savings_km_pct.toFixed(1)}% {t('route_builder.km_saved')}</StatusPill>
        <StatusPill tone={solution.savings_time_pct > 0 ? 'success' : 'neutral'}>{solution.savings_time_pct.toFixed(1)}% {t('route_builder.time_saved')}</StatusPill>
      </div>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/route-builder/components/RouteMap.tsx <<'EOF'
import { useEffect } from 'react';
import { MapContainer, TileLayer, Polyline, CircleMarker } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { SolveResponse } from '../types';

delete (L.Icon.Default.prototype as any)._getIconUrl;
interface Props { solution: SolveResponse; start: { lat: number; lng: number } }
export function RouteMap({ solution, start }: Props) {
  useEffect(() => {
    const t = setTimeout(() => window.dispatchEvent(new Event('resize')), 150);
    return () => clearTimeout(t);
  }, []);
  const buildLine = (seq: typeof solution.manual) => [
    [start.lat, start.lng] as [number, number],
    ...seq.stops.map((s) => [s.lat, s.lng] as [number, number]),
  ];
  return (
    <div className="w-full h-[340px] rounded-md overflow-hidden border border-border">
      <MapContainer center={[start.lat, start.lng]} zoom={12} style={{ width: '100%', height: '100%' }}>
        <TileLayer attribution='&copy; OpenStreetMap' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        <Polyline positions={buildLine(solution.manual)} pathOptions={{ color: '#6b6b6b', weight: 3, dashArray: '6 6', opacity: 0.7 }} />
        <Polyline positions={buildLine(solution.optimized)} pathOptions={{ color: '#0f766e', weight: 4, opacity: 1 }} />
        <CircleMarker center={[start.lat, start.lng]} radius={9} pathOptions={{ color: '#0f766e', fillColor: '#0f766e', fillOpacity: 1 }} />
        {solution.optimized.stops.map((s) => (
          <CircleMarker key={s.order_id} center={[s.lat, s.lng]} radius={6}
            pathOptions={{ color: '#0f766e', fillColor: '#fff', fillOpacity: 1, weight: 2 }} />
        ))}
      </MapContainer>
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/route-builder/RouteBuilderPage.tsx <<'EOF'
import { useEffect, useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import { OrderQueue } from './components/OrderQueue';
import { VehicleSelector } from './components/VehicleSelector';
import { ComparisonView } from './components/ComparisonView';
import { RouteMap } from './components/RouteMap';
import { usePendingOrders, useVehicles, useAcceptRoute, useSubmitAsyncSolve, useAsyncSolveJob, useSolveRoutesSync } from './hooks';
import type { SolveResponse } from './types';

const DEFAULT_DRIVER_ID = 'D-201';
const STALL_MS = 15_000;

export function RouteBuilderPage() {
  const { t } = useI18n();
  const ordersQ = usePendingOrders();
  const vehiclesQ = useVehicles();
  const submitMut = useSubmitAsyncSolve();
  const acceptMut = useAcceptRoute();
  const syncMut = useSolveRoutesSync();

  const [selectedOrderIds, setSelectedOrderIds] = useState<Set<string>>(new Set());
  const [selectedVehicleId, setSelectedVehicleId] = useState<string | null>(null);
  const [jobId, setJobId] = useState<string | null>(null);
  const [solution, setSolution] = useState<SolveResponse | null>(null);
  const [usedSyncFallback, setUsedSyncFallback] = useState(false);
  const jobQ = useAsyncSolveJob(jobId);

  const orders = ordersQ.data?.orders ?? [];
  const vehicles = vehiclesQ.data?.vehicles ?? [];
  const selectedVehicle = useMemo(() => vehicles.find((v) => v.id === selectedVehicleId) ?? null, [vehicles, selectedVehicleId]);

  useEffect(() => {
    if (jobQ.data?.status === 'DONE' && jobQ.data.result) setSolution(jobQ.data.result);
  }, [jobQ.data]);

  const stalledMs = useMemo(() => {
    if (!jobQ.data) return 0;
    if (jobQ.data.status !== 'QUEUED' && jobQ.data.status !== 'RUNNING') return 0;
    return Date.now() - new Date(jobQ.data.submitted_at).getTime();
  }, [jobQ.data]);
  const isStalled = stalledMs > STALL_MS;

  const reset = () => { setJobId(null); setSolution(null); setUsedSyncFallback(false); submitMut.reset(); syncMut.reset(); };
  const toggle = (id: string) => {
    const next = new Set(selectedOrderIds);
    if (next.has(id)) next.delete(id); else next.add(id);
    setSelectedOrderIds(next); reset();
  };
  const selectAll = () => { setSelectedOrderIds(new Set(orders.map((o) => o.id))); reset(); };
  const clearAll = () => { setSelectedOrderIds(new Set()); reset(); };

  const canSolve = selectedOrderIds.size >= 2 && selectedVehicleId !== null && !submitMut.isPending && !syncMut.isPending && jobId === null;
  const handleSolve = () => {
    if (!canSolve) return;
    setSolution(null); setUsedSyncFallback(false);
    submitMut.mutate({ order_ids: Array.from(selectedOrderIds), vehicle_id: selectedVehicleId! },
      { onSuccess: (r) => setJobId(r.job_id) });
  };
  const handleSyncFallback = () => {
    if (selectedOrderIds.size < 2 || !selectedVehicleId) return;
    setUsedSyncFallback(true);
    syncMut.mutate({ order_ids: Array.from(selectedOrderIds), vehicle_id: selectedVehicleId! },
      { onSuccess: (r) => setSolution(r) });
  };
  const handleAccept = () => {
    if (!selectedVehicleId) return;
    acceptMut.mutate({
      order_ids: Array.from(selectedOrderIds), vehicle_id: selectedVehicleId,
      driver_id: DEFAULT_DRIVER_ID, mode: 'optimized',
    }, { onSuccess: () => { reset(); setSelectedOrderIds(new Set()); void ordersQ.refetch(); } });
  };

  const isLoading = ordersQ.isLoading || vehiclesQ.isLoading;
  const jobRunning = jobQ.data?.status === 'QUEUED' || jobQ.data?.status === 'RUNNING';
  const jobFailed = jobQ.data?.status === 'FAILED' || jobQ.data?.status === 'TIMEOUT';

  return (
    <div className="max-w-[1400px] mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">{t('route_builder.title')}</h1>
        <p className="text-sm text-muted mt-1">{t('route_builder.subtitle')}</p>
      </header>
      {isLoading ? <Spinner label={t('common.loading')} /> : (
        <div className="grid grid-cols-1 lg:grid-cols-[360px_1fr] gap-4">
          <aside className="flex flex-col gap-3">
            <OrderQueue orders={orders} selected={selectedOrderIds} onToggle={toggle} onSelectAll={selectAll} onClearAll={clearAll} />
            <VehicleSelector vehicles={vehicles} selected={selectedVehicleId} onSelect={(id) => { setSelectedVehicleId(id); reset(); }} />
            <Button onClick={handleSolve} disabled={!canSolve} loading={submitMut.isPending}>
              {t('route_builder.solve')} ({selectedOrderIds.size})
            </Button>
            {(submitMut.isError || jobFailed) && (
              <div className="text-sm text-danger">{(submitMut.error as Error)?.message ?? jobQ.data?.error ?? t('common.error')}</div>
            )}
          </aside>
          <section className="min-w-0">
            {!solution && !jobRunning && !jobFailed && (
              <EmptyState title={t('route_builder.no_solution')} hint={t('route_builder.no_solution_hint')} />
            )}
            {jobRunning && !solution && (
              <div className="border border-border rounded-md bg-surface p-6">
                <div className="flex items-center gap-3 mb-2">
                  <span className="inline-block w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                  <p className="text-sm font-medium">
                    {jobQ.data?.status === 'QUEUED' ? t('route_builder.async.queued') : t('route_builder.async.running')}
                  </p>
                </div>
                <p className="text-xs text-muted">{t('route_builder.async.elapsed', { s: Math.floor(stalledMs / 1000) })}</p>
                {isStalled && (
                  <div className="mt-4 border border-warn/40 bg-warnBg rounded-md p-3 text-sm">
                    <p className="font-medium text-warn mb-1">{t('route_builder.async.stalled_title')}</p>
                    <p className="text-muted mb-3">{t('route_builder.async.stalled_body')}</p>
                    <div className="flex gap-2">
                      <Button size="sm" onClick={handleSyncFallback} loading={syncMut.isPending}>{t('route_builder.async.try_sync')}</Button>
                      <Button size="sm" variant="ghost" onClick={reset}>{t('common.cancel')}</Button>
                    </div>
                  </div>
                )}
              </div>
            )}
            {syncMut.isPending && (
              <div className="border border-border rounded-md bg-surface p-6">
                <div className="flex items-center gap-3">
                  <span className="inline-block w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                  <p className="text-sm font-medium">{t('route_builder.async.running')}</p>
                </div>
              </div>
            )}
            {jobFailed && !solution && (
              <div className="border border-danger/40 bg-dangerBg rounded-md p-4">
                <p className="font-medium text-danger mb-1">{t('route_builder.async.failed_title')}</p>
                <p className="text-sm text-muted mb-3">{jobQ.data?.error ?? t('common.error')}</p>
                <div className="flex gap-2">
                  <Button size="sm" onClick={handleSyncFallback} loading={syncMut.isPending}>{t('route_builder.async.try_sync')}</Button>
                  <Button size="sm" variant="ghost" onClick={reset}>{t('common.cancel')}</Button>
                </div>
              </div>
            )}
            {solution && selectedVehicle && (
              <>
                {usedSyncFallback && (
                  <div className="mb-3 text-xs text-warn border border-warn/30 bg-warnBg rounded px-3 py-2">{t('route_builder.async.used_sync')}</div>
                )}
                <ComparisonView solution={solution} />
                <div className="mt-4">
                  <RouteMap solution={solution} start={{ lat: selectedVehicle.start_lat, lng: selectedVehicle.start_lng }} />
                </div>
                <div className="mt-4 flex justify-end gap-2">
                  <Button variant="secondary" onClick={reset} disabled={acceptMut.isPending}>{t('route_builder.reject')}</Button>
                  <Button onClick={handleAccept} loading={acceptMut.isPending} disabled={solution.infeasible !== null}>
                    {t('route_builder.accept_optimized')}
                  </Button>
                </div>
              </>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/route-builder/index.ts <<'EOF'
export { RouteBuilderPage } from './RouteBuilderPage';
export type { Order, Vehicle, SolveResponse } from './types';
EOF
W apps/dispatcher-web/src/modules/route-builder/__tests__/RouteBuilderPage.test.tsx <<'EOF'
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { RouteBuilderPage } from '../RouteBuilderPage';

const mockResult = {
  manual: { stops: [
    { order_id: 'o1', distributor_name: 'Bole Retail', seq: 1, eta: new Date().toISOString(), lat: 8.9948, lng: 38.7923 },
    { order_id: 'o2', distributor_name: 'Piassa Traders', seq: 2, eta: new Date().toISOString(), lat: 9.0333, lng: 38.75 },
  ], total_km: 20, total_min: 48 },
  optimized: { stops: [
    { order_id: 'o2', distributor_name: 'Piassa Traders', seq: 1, eta: new Date().toISOString(), lat: 9.0333, lng: 38.75 },
    { order_id: 'o1', distributor_name: 'Bole Retail', seq: 2, eta: new Date().toISOString(), lat: 8.9948, lng: 38.7923 },
  ], total_km: 16, total_min: 38 },
  savings_km_pct: 20, savings_time_pct: 20.8, infeasible: null,
};

vi.mock('../api', async () => {
  const today = new Date();
  const startH = (h: number) => { const d = new Date(today); d.setHours(h, 0, 0, 0); return d.toISOString(); };
  return {
    routeBuilderKeys: { all: ['rb'], pending: () => ['rb', 'pending'], vehicles: () => ['rb', 'vehicles'], solveJob: (id: string) => ['rb', 'job', id] },
    fetchPendingOrders: vi.fn().mockResolvedValue({
      orders: [
        { id: 'o1', distributor_id: 'd1', distributor_name: 'Bole Retail', lat: 8.9948, lng: 38.7923, weight_kg: 80, volume_m3: 0.4, priority: 8, time_window_start: startH(8), time_window_end: startH(12), status: 'PENDING', created_at: new Date().toISOString() },
        { id: 'o2', distributor_id: 'd2', distributor_name: 'Piassa Traders', lat: 9.0333, lng: 38.75, weight_kg: 95, volume_m3: 0.5, priority: 5, time_window_start: startH(10), time_window_end: startH(14), status: 'PENDING', created_at: new Date().toISOString() },
      ],
    }),
    fetchVehicles: vi.fn().mockResolvedValue({
      vehicles: [{ id: 'V-101', plate: 'AA-3-B-101', capacity_kg: 1500, capacity_m3: 8, shift_start_h: 7, shift_end_h: 18, start_lat: 9.0108, start_lng: 38.7613 }],
    }),
    solveRoutes: vi.fn(),
    submitAsyncSolve: vi.fn().mockResolvedValue({ job_id: 'job-1', status: 'QUEUED' }),
    getAsyncSolveJob: vi.fn().mockResolvedValue({ job_id: 'job-1', status: 'DONE', submitted_at: new Date().toISOString(), started_at: new Date().toISOString(), finished_at: new Date().toISOString(), duration_ms: 120, result: mockResult, error: null }),
    acceptRoute: vi.fn().mockResolvedValue({ route_id: 'r1', planned_km: 16, planned_min: 38 }),
  };
});
vi.mock('react-leaflet', () => ({
  MapContainer: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  TileLayer: () => null, Polyline: () => null, CircleMarker: () => null,
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('RouteBuilderPage', () => {
  it('renders pending orders', async () => {
    wrap(<RouteBuilderPage />);
    expect(await screen.findByText('Bole Retail')).toBeInTheDocument();
    expect(screen.getByText('AA-3-B-101')).toBeInTheDocument();
  });
  it('solves async and shows comparison', async () => {
    wrap(<RouteBuilderPage />);
    const checks = await screen.findAllByRole('checkbox');
    fireEvent.click(checks[0]!); fireEvent.click(checks[1]!);
    fireEvent.click(screen.getByText('AA-3-B-101'));
    fireEvent.click(screen.getByRole('button', { name: /Solve/ }));
    await waitFor(() => {
      expect(screen.getByText(/20\.0% fewer km/)).toBeInTheDocument();
      expect(screen.getByText(/20\.8% faster/)).toBeInTheDocument();
    });
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# MODULE 4 — dispatch-board
# ═══════════════════════════════════════════════════════════════════
W apps/dispatcher-web/src/modules/dispatch-board/types.ts <<'EOF'
export type { BoardResponse, Dock, DockSlot, RouteSummary } from '@tera/contracts';
EOF
W apps/dispatcher-web/src/modules/dispatch-board/api.ts <<'EOF'
import { api } from '../../api/client';
import type { BoardResponse } from './types';

export const dispatchKeys = { all: ['dispatch-board'] as const, board: () => [...dispatchKeys.all, 'board'] as const };
export function fetchBoard(signal?: AbortSignal) { return api<BoardResponse>({ path: '/dispatch/v1/board', signal }); }
export function allocateAll() { return api<{ allocated: number; skipped_unallocatable: number }>({ method: 'POST', path: '/dispatch/v1/slots/allocate' }); }
export function confirmSlot(slotId: string) { return api<{ slot_id: string; status: string; confirmed_at: string }>({ method: 'POST', path: `/dispatch/v1/slots/${slotId}/confirm` }); }
export function dispatchRoute(routeId: string) { return api<{ route_id: string; status: string; slot_status: string }>({ method: 'POST', path: `/dispatch/v1/routes/${routeId}/dispatch` }); }
EOF
W apps/dispatcher-web/src/modules/dispatch-board/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { dispatchKeys, fetchBoard, allocateAll, confirmSlot, dispatchRoute } from './api';

export function useBoard() {
  return useQuery({ queryKey: dispatchKeys.board(), queryFn: ({ signal }) => fetchBoard(signal), refetchInterval: 10_000 });
}
export function useAllocateAll() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: () => allocateAll(), onSuccess: () => qc.invalidateQueries({ queryKey: dispatchKeys.all }) });
}
export function useConfirmSlot() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (slotId: string) => confirmSlot(slotId), onSuccess: () => qc.invalidateQueries({ queryKey: dispatchKeys.all }) });
}
export function useDispatchRoute() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (routeId: string) => dispatchRoute(routeId), onSuccess: () => qc.invalidateQueries({ queryKey: dispatchKeys.all }) });
}
EOF
W apps/dispatcher-web/src/modules/dispatch-board/components/SlotCard.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { Button, StatusPill } from '@tera/ui';
import type { DockSlot } from '../types';

interface Props {
  slot: DockSlot;
  onConfirm: (slotId: string) => void;
  onDispatch: (routeId: string) => void;
  pendingAction: 'confirm' | 'dispatch' | null;
  disabled?: boolean;
}
function slotTone(status: DockSlot['status']): 'neutral' | 'warn' | 'success' {
  if (status === 'AVAILABLE') return 'neutral';
  if (status === 'ALLOCATED') return 'warn';
  return 'success';
}
export function SlotCard({ slot, onConfirm, onDispatch, pendingAction, disabled }: Props) {
  const { t } = useI18n();
  const time = (iso: string) => new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const statusLabel: Record<DockSlot['status'], string> = {
    AVAILABLE: t('dispatch.slot.available'), ALLOCATED: t('dispatch.slot.allocated'),
    CONFIRMED: t('dispatch.slot.confirmed'), COMPLETED: t('dispatch.slot.completed'),
  };
  const allPicked = slot.route ? slot.route.picked_count === slot.route.stop_count : false;
  return (
    <div className={`border rounded-md p-3 bg-surface ${slot.status === 'COMPLETED' ? 'opacity-70' : ''}`}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-medium tabular-nums">{time(slot.start_at)} – {time(slot.end_at)}</span>
        <StatusPill tone={slotTone(slot.status)}>{statusLabel[slot.status]}</StatusPill>
      </div>
      {slot.route ? (
        <>
          <div className="text-sm font-medium">{slot.route.vehicle_id}</div>
          <div className="text-xs text-muted">{slot.route.driver_id} · {slot.route.stop_count} {t('dispatch.stops')} · {slot.route.planned_km.toFixed(1)} km</div>
          <div className={`text-xs mt-1 ${allPicked ? 'text-success' : 'text-warn'}`}>
            {slot.route.picked_count} / {slot.route.stop_count} picked
          </div>
          <div className="mt-3 flex flex-col gap-1.5">
            {slot.status === 'ALLOCATED' && (
              <Button size="sm" disabled={disabled || pendingAction !== null || !allPicked} loading={pendingAction === 'confirm'} onClick={() => onConfirm(slot.id)}>
                {allPicked ? t('dispatch.confirm_loading') : t('dispatch.pick_first')}
              </Button>
            )}
            {(slot.status === 'CONFIRMED' || slot.status === 'COMPLETED') && slot.route.status === 'PLANNED' && (
              <Button size="sm" disabled={disabled || pendingAction !== null} loading={pendingAction === 'dispatch'} onClick={() => onDispatch(slot.route!.id)}>
                {t('dispatch.dispatch_route')}
              </Button>
            )}
            {slot.route.status === 'DISPATCHED' && (
              <div className="text-xs text-success font-medium">{t('dispatch.on_road')}</div>
            )}
          </div>
        </>
      ) : (
        <div className="text-xs text-muted">{t('dispatch.empty_slot')}</div>
      )}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/dispatch-board/components/BoardSummary.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import type { BoardResponse } from '../types';
export function BoardSummary({ summary }: { summary: BoardResponse['summary'] }) {
  const { t } = useI18n();
  const stat = (label: string, value: number, tone?: 'warn' | 'danger') => (
    <div className="flex-1 min-w-[110px] border border-border rounded-md px-3 py-2 bg-surface">
      <div className="text-xs text-muted">{label}</div>
      <div className={`text-xl font-semibold tabular-nums ${tone === 'danger' ? 'text-danger' : tone === 'warn' ? 'text-warn' : ''}`}>{value}</div>
    </div>
  );
  return (
    <div className="flex flex-wrap gap-2">
      {stat(t('dispatch.summary.routes_planned'), summary.routes_planned)}
      {stat(t('dispatch.summary.routes_dispatched'), summary.routes_dispatched)}
      {stat(t('dispatch.summary.slots_available'), summary.slots_available)}
      {stat(t('dispatch.summary.slots_allocated'), summary.slots_allocated, summary.slots_allocated > 0 ? 'warn' : undefined)}
      {stat(t('dispatch.summary.unallocated_routes'), summary.unallocated_routes, summary.unallocated_routes > 0 ? 'danger' : undefined)}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/dispatch-board/components/DockColumn.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { SlotCard } from './SlotCard';
import type { Dock } from '../types';
interface Props {
  dock: Dock;
  onConfirm: (slotId: string) => void;
  onDispatch: (routeId: string) => void;
  pendingAction: { slotId?: string; routeId?: string; kind: 'confirm' | 'dispatch' } | null;
  disabled?: boolean;
}
export function DockColumn({ dock, onConfirm, onDispatch, pendingAction, disabled }: Props) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-2">
      <div className="text-sm font-semibold px-1 pb-1 border-b border-border">{dock.name}</div>
      {dock.slots.length === 0 ? (
        <div className="text-xs text-muted px-1">{t('dispatch.no_slots')}</div>
      ) : (
        dock.slots.map((slot) => (
          <SlotCard key={slot.id} slot={slot} onConfirm={onConfirm} onDispatch={onDispatch}
            pendingAction={pendingAction?.kind === 'confirm' && pendingAction.slotId === slot.id ? 'confirm'
              : pendingAction?.kind === 'dispatch' && pendingAction.routeId === slot.route?.id ? 'dispatch'
              : null}
            disabled={disabled} />
        ))
      )}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/dispatch-board/DispatchBoardPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import { BoardSummary } from './components/BoardSummary';
import { DockColumn } from './components/DockColumn';
import { useBoard, useAllocateAll, useConfirmSlot, useDispatchRoute } from './hooks';

export function DispatchBoardPage() {
  const { t } = useI18n();
  const [wallMode, setWallMode] = useState(false);
  const boardQ = useBoard();
  const allocateMut = useAllocateAll();
  const confirmMut = useConfirmSlot();
  const dispatchMut = useDispatchRoute();

  if (boardQ.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (boardQ.isError || !boardQ.data) {
    return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">
      {t('common.error')}{' '}<button onClick={() => boardQ.refetch()} className="underline">{t('common.retry')}</button>
    </div></div>;
  }

  const { summary, docks } = boardQ.data;
  const pendingAction =
    confirmMut.isPending && confirmMut.variables ? { kind: 'confirm' as const, slotId: confirmMut.variables }
    : dispatchMut.isPending && dispatchMut.variables ? { kind: 'dispatch' as const, routeId: dispatchMut.variables }
    : null;
  const anyPending = confirmMut.isPending || dispatchMut.isPending || allocateMut.isPending;

  return (
    <div className={`mx-auto ${wallMode ? 'max-w-none px-2' : 'max-w-[1400px]'}`}>
      <header className="mb-4 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className={`font-semibold ${wallMode ? 'text-3xl' : 'text-2xl'}`}>{t('dispatch.title')}</h1>
          <p className={`text-muted mt-1 ${wallMode ? 'text-base' : 'text-sm'}`}>{t('dispatch.subtitle')}</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Button variant="ghost" size="sm" onClick={() => setWallMode((v) => !v)}>
            {wallMode ? t('dispatch.mode.normal') : t('dispatch.mode.wall')}
          </Button>
          <Button onClick={() => allocateMut.mutate()} disabled={anyPending} loading={allocateMut.isPending}>
            {t('dispatch.allocate_all')}
          </Button>
          <Button variant="secondary" size="sm" onClick={() => boardQ.refetch()}>{t('common.retry')}</Button>
        </div>
      </header>

      {(confirmMut.isError || dispatchMut.isError || allocateMut.isError) && (
        <div className="mb-3 text-sm text-danger border border-danger/30 bg-dangerBg rounded px-3 py-2">
          {((confirmMut.error ?? dispatchMut.error ?? allocateMut.error) as Error)?.message ?? t('common.error')}
        </div>
      )}
      <div className="mb-4"><BoardSummary summary={summary} /></div>
      {docks.length === 0 ? <EmptyState title={t('dispatch.no_docks')} /> : (
        <div className={`grid gap-4 ${wallMode ? 'grid-cols-1 md:grid-cols-3' : 'grid-cols-1 md:grid-cols-3'}`}>
          {docks.map((dock) => (
            <DockColumn key={dock.id} dock={dock}
              onConfirm={(slotId) => confirmMut.mutate(slotId)}
              onDispatch={(routeId) => dispatchMut.mutate(routeId)}
              pendingAction={pendingAction} disabled={anyPending} />
          ))}
        </div>
      )}
      {summary.unallocated_routes > 0 && (
        <div className="mt-4 text-xs text-warn bg-warnBg border border-warn/30 rounded px-3 py-2 inline-block">
          {summary.unallocated_routes} {t('dispatch.unallocated_hint')}
        </div>
      )}
    </div>
  );
}
EOF
W apps/dispatcher-web/src/modules/dispatch-board/index.ts <<'EOF'
export { DispatchBoardPage } from './DispatchBoardPage';
export type { BoardResponse, Dock, DockSlot, RouteSummary } from './types';
EOF
W apps/dispatcher-web/src/modules/dispatch-board/__tests__/DispatchBoardPage.test.tsx <<'EOF'
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { DispatchBoardPage } from '../DispatchBoardPage';

vi.mock('../api', () => ({
  dispatchKeys: { all: ['db'], board: () => ['db', 'board'] },
  fetchBoard: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(),
    summary: { routes_planned: 1, routes_dispatched: 0, slots_available: 10, slots_allocated: 1, slots_confirmed: 0, unallocated_routes: 0 },
    docks: [{ id: 'dock-a', name: 'Dock A', slots: [
      { id: 'slot-1', start_at: new Date().toISOString(), end_at: new Date(Date.now() + 3600_000).toISOString(),
        status: 'ALLOCATED', confirmed_at: null, confirmed_by: null,
        route: { id: 'r1', vehicle_id: 'V-102', driver_id: 'D-202', status: 'PLANNED', planned_km: 38, planned_min: 220, stop_count: 4, picked_count: 4 } },
    ] }, { id: 'dock-b', name: 'Dock B', slots: [] }],
  }),
  allocateAll: vi.fn(),
  confirmSlot: vi.fn(),
  dispatchRoute: vi.fn(),
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}

describe('DispatchBoardPage', () => {
  it('renders board with V-102 and Confirm loading (all picked)', async () => {
    wrap(<DispatchBoardPage />);
    expect(await screen.findByText('Dispatch Board')).toBeInTheDocument();
    expect(await screen.findByText('V-102')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Confirm loading/ })).toBeInTheDocument();
  });
});
EOF

# ═══════════════════════════════════════════════════════════════════
# i18n — dispatcher keys (all 4 modules)
# ═══════════════════════════════════════════════════════════════════
node <<'NODE'
const fs = require('fs');
const en = JSON.parse(fs.readFileSync('packages/i18n/src/locales/en.json', 'utf8'));
const am = JSON.parse(fs.readFileSync('packages/i18n/src/locales/am.json', 'utf8'));

Object.assign(en, {
  'common.loading': 'Loading…', 'common.retry': 'Retry', 'common.cancel': 'Cancel',
  'common.confirm': 'Confirm', 'common.search': 'Search', 'common.empty': 'No data',
  'common.today': 'Today', 'common.error': 'Something went wrong', 'common.optional': 'Note',
  'nav.dashboard': 'Dashboard', 'nav.dispatch': 'Dispatch', 'nav.routes': 'Routes',
  'nav.route_builder': 'Route Builder', 'nav.dispatch_board': 'Dispatch Board',
  'nav.credit': 'Credit', 'nav.warehouse': 'Warehouse',
  'credit.title': 'Credit Stop List',
  'credit.subtitle': 'Distributors blocked today due to credit',
  'credit.amount_owed': 'Amount owed', 'credit.days_overdue': 'Days overdue',
  'credit.limit': 'Credit limit', 'credit.exposure': 'Outstanding exposure',
  'credit.override': 'Override', 'credit.override_reason': 'Override reason',
  'credit.override_confirm': 'Confirm override', 'credit.override_expires': 'Expires at',
  'credit.no_blocked': 'No distributors blocked today',
  'credit.filter.all': 'All', 'credit.filter.overdue_30': 'Over 30 days', 'credit.filter.over_limit': 'Over limit',
  'credit.table.distributor': 'Distributor', 'credit.table.region': 'Region',
  'credit.table.status': 'Status', 'credit.table.actions': 'Actions',
  'credit.status.blocked': 'Blocked', 'credit.status.warned': 'Warned', 'credit.status.cleared': 'Cleared',
  'credit.reason.over_limit': 'Over credit limit', 'credit.reason.past_grace': 'Past grace period',
  'credit.reason.both': 'Both over limit and past grace',
  'morning_map.title': 'Morning Map',
  'morning_map.subtitle': "Today's routes, curfews, and fuel stations",
  'morning_map.no_routes': 'No routes scheduled for today',
  'morning_map.stops_delivered': 'stops delivered',
  'morning_map.status.on_track': 'On track', 'morning_map.status.late': 'Late',
  'morning_map.view_table': 'Table view', 'morning_map.view_map': 'Map view',
  'morning_map.legend.route': 'Route', 'morning_map.legend.delivered': 'Delivered',
  'morning_map.legend.curfew': 'Curfew zone', 'morning_map.legend.fuel': 'Fuel station',
  'morning_map.table.vehicle': 'Vehicle',
  'route_builder.title': 'Route Builder',
  'route_builder.subtitle': 'Prove it to yourself: optimized vs. manual, side by side',
  'route_builder.pending_orders': 'Pending orders',
  'route_builder.no_pending': 'No pending orders',
  'route_builder.select_all': 'Select all', 'route_builder.clear': 'Clear',
  'route_builder.priority': 'P', 'route_builder.vehicle': 'Vehicle',
  'route_builder.solve': 'Solve routes', 'route_builder.no_solution': 'No solution yet',
  'route_builder.no_solution_hint': 'Select at least 2 orders and a vehicle, then press Solve.',
  'route_builder.manual': 'Manual (arrival order)', 'route_builder.optimized': 'Optimized (VRP)',
  'route_builder.km_saved': 'fewer km', 'route_builder.time_saved': 'faster',
  'route_builder.infeasible': 'Cannot fulfill',
  'route_builder.accept_optimized': 'Accept optimized', 'route_builder.reject': 'Cancel',
  'route_builder.async.queued': 'Waiting for solver…', 'route_builder.async.running': 'Solving route…',
  'route_builder.async.elapsed': '{s}s elapsed',
  'route_builder.async.stalled_title': 'Taking longer than expected',
  'route_builder.async.stalled_body': 'The solver is queued. If the optimizer is not running, use sync solve.',
  'route_builder.async.try_sync': 'Try sync solve',
  'route_builder.async.failed_title': 'Solve failed',
  'route_builder.async.used_sync': 'Result computed by sync solve (async was unavailable or timed out)',
  'dispatch.title': 'Dispatch Board',
  'dispatch.subtitle': 'A route cannot leave the yard until loading is confirmed',
  'dispatch.allocate_all': 'Allocate slots', 'dispatch.mode.wall': 'Wall mode', 'dispatch.mode.normal': 'Normal mode',
  'dispatch.stops': 'stops', 'dispatch.confirm_loading': 'Confirm loading',
  'dispatch.pick_first': 'Pick all stops first',
  'dispatch.dispatch_route': 'Dispatch route', 'dispatch.on_road': 'On the road',
  'dispatch.empty_slot': 'Empty slot', 'dispatch.no_slots': 'No slots today', 'dispatch.no_docks': 'No docks',
  'dispatch.unallocated_hint': 'route(s) without a dock slot',
  'dispatch.slot.available': 'Available', 'dispatch.slot.allocated': 'Allocated',
  'dispatch.slot.confirmed': 'Confirmed', 'dispatch.slot.completed': 'Completed',
  'dispatch.summary.routes_planned': 'Routes planned', 'dispatch.summary.routes_dispatched': 'Dispatched',
  'dispatch.summary.slots_available': 'Free slots', 'dispatch.summary.slots_allocated': 'Awaiting confirm',
  'dispatch.summary.unallocated_routes': 'Unallocated',
  'currency.etb': 'ETB', 'time.eta': 'ETA', 'time.minutes_short': 'min',
});

Object.assign(am, {
  'common.loading': 'በመጫን ላይ…', 'common.retry': 'እንደገና ሞክር', 'common.cancel': 'ሰርዝ',
  'common.confirm': 'አረጋግጥ', 'common.search': 'ፈልግ', 'common.empty': 'መረጃ የለም',
  'common.today': 'ዛሬ', 'common.error': 'ስህተት ተፈጥሯል', 'common.optional': 'ማስታወሻ',
  'nav.dashboard': 'ዳሽቦርድ', 'nav.dispatch': 'ማመላለሻ', 'nav.routes': 'መንገዶች',
  'nav.route_builder': 'የመንገድ ገንቢ', 'nav.dispatch_board': 'የማመላለሻ ሰሌዳ',
  'nav.credit': 'ክሬዲት', 'nav.warehouse': 'መጋዘን',
  'credit.title': 'የክሬዲት ማቆሚያ ዝርዝር',
  'credit.subtitle': 'ዛሬ በክሬዲት ምክንያት የተከለከሉ አከፋፋዮች',
  'credit.amount_owed': 'የሚፈለግ መጠን', 'credit.days_overdue': 'የተዘገዩ ቀናት',
  'credit.limit': 'የክሬዲት ጣሪያ', 'credit.exposure': 'ያለ ክፍያ ቀሪ',
  'credit.override': 'ማለፍ ፍቀድ', 'credit.override_reason': 'የማለፍ ምክንያት',
  'credit.override_confirm': 'ማለፍን አረጋግጥ', 'credit.override_expires': 'የሚያበቃበት ጊዜ',
  'credit.no_blocked': 'ዛሬ የታገደ አከፋፋይ የለም',
  'credit.filter.all': 'ሁሉም', 'credit.filter.overdue_30': 'ከ30 ቀን በላይ', 'credit.filter.over_limit': 'ከጣሪያ በላይ',
  'credit.table.distributor': 'አከፋፋይ', 'credit.table.region': 'ክልል',
  'credit.table.status': 'ሁኔታ', 'credit.table.actions': 'ተግባራት',
  'credit.status.blocked': 'ታግዷል', 'credit.status.warned': 'ማስጠንቀቂያ', 'credit.status.cleared': 'ጸድቋል',
  'credit.reason.over_limit': 'ከክሬዲት ጣሪያ በላይ', 'credit.reason.past_grace': 'ከጸጋ ጊዜ በላይ',
  'credit.reason.both': 'ሁለቱም ምክንያቶች',
  'morning_map.title': 'የጠዋት ካርታ',
  'morning_map.subtitle': 'የዛሬ መንገዶች፣ እገዳዎች፣ እና የነዳጅ ጣቢያዎች',
  'morning_map.no_routes': 'ዛሬ የተያዘ መንገድ የለም',
  'morning_map.stops_delivered': 'የደረሱ ጣቢያዎች',
  'morning_map.status.on_track': 'በመንገድ ላይ', 'morning_map.status.late': 'ዘግይቷል',
  'morning_map.view_table': 'የሠንጠረዥ እይታ', 'morning_map.view_map': 'የካርታ እይታ',
  'morning_map.legend.route': 'መንገድ', 'morning_map.legend.delivered': 'የደረሰ',
  'morning_map.legend.curfew': 'የእገዳ አካባቢ', 'morning_map.legend.fuel': 'የነዳጅ ጣቢያ',
  'morning_map.table.vehicle': 'ተሽከርካሪ',
  'route_builder.title': 'የመንገድ ገንቢ',
  'route_builder.subtitle': 'ራስዎን ያረጋግጡ፦ የተመቻቸ እና ቀላል መንገድ ጎን ለጎን',
  'route_builder.pending_orders': 'በመጠባበቅ ላይ ያሉ ትዕዛዞች',
  'route_builder.no_pending': 'በመጠባበቅ ላይ ያለ ትዕዛዝ የለም',
  'route_builder.select_all': 'ሁሉንም ምረጥ', 'route_builder.clear': 'አጽዳ',
  'route_builder.priority': 'ቅድሚያ', 'route_builder.vehicle': 'ተሽከርካሪ',
  'route_builder.solve': 'መንገዶችን ፍታ', 'route_builder.no_solution': 'እስካሁን መፍትሔ የለም',
  'route_builder.no_solution_hint': 'ቢያንስ 2 ትዕዛዞችን እና ተሽከርካሪ ይምረጡ፣ ከዚያ ፍታ ይጫኑ።',
  'route_builder.manual': 'ቀላል (የመድረሻ ቅደም ተከተል)', 'route_builder.optimized': 'የተመቻቸ (VRP)',
  'route_builder.km_saved': 'ኪሜ ቅነሳ', 'route_builder.time_saved': 'ፈጣን',
  'route_builder.infeasible': 'ማሟላት አይቻልም',
  'route_builder.accept_optimized': 'የተመቻቸውን ተቀበል', 'route_builder.reject': 'ሰርዝ',
  'route_builder.async.queued': 'መፍትሔ በመጠባበቅ ላይ…', 'route_builder.async.running': 'መንገድ በመፍታት ላይ…',
  'route_builder.async.elapsed': '{s} ሰከንድ አልፏል',
  'route_builder.async.stalled_title': 'ከተጠበቀው በላይ እየቆየ ነው',
  'route_builder.async.stalled_body': 'መፍትሔው በተራ ላይ ቆይቷል። የማሻሻያ ሂደቱ እየሠራ ካልሆነ፣ በምትኩ የማመሳሰያ መፍትሔ ይጠቀሙ።',
  'route_builder.async.try_sync': 'የማመሳሰያ መፍትሔ ሞክር',
  'route_builder.async.failed_title': 'መፍትሔው አልተሳካም',
  'route_builder.async.used_sync': 'ውጤቱ በማመሳሰያ መፍትሔ ተቆጥሯል (async አልተገኘም ወይም ጊዜው አልፏል)',
  'dispatch.title': 'የማመላለሻ ሰሌዳ',
  'dispatch.subtitle': 'ጭነት እስኪረጋገጥ ድረስ መንገድ ከግቢው መውጣት አይችልም',
  'dispatch.allocate_all': 'ማስያዣዎችን መድብ', 'dispatch.mode.wall': 'የግድግዳ ሁነታ', 'dispatch.mode.normal': 'መደበኛ ሁነታ',
  'dispatch.stops': 'ጣቢያዎች', 'dispatch.confirm_loading': 'ጭነት አረጋግጥ',
  'dispatch.pick_first': 'መጀመሪያ ሁሉንም ጣቢያዎች ይምረጡ',
  'dispatch.dispatch_route': 'መንገድ ላክ', 'dispatch.on_road': 'በመንገድ ላይ',
  'dispatch.empty_slot': 'ባዶ ማስያዣ', 'dispatch.no_slots': 'ዛሬ ማስያዣ የለም', 'dispatch.no_docks': 'የተዋቀረ መጫኛ የለም',
  'dispatch.unallocated_hint': 'መንገዶች የመጫኛ ማስያዣ የላቸውም',
  'dispatch.slot.available': 'ነጻ', 'dispatch.slot.allocated': 'ተመድቧል',
  'dispatch.slot.confirmed': 'ተረጋግጧል', 'dispatch.slot.completed': 'ተጠናቅቋል',
  'dispatch.summary.routes_planned': 'የተያዙ መንገዶች', 'dispatch.summary.routes_dispatched': 'የተላኩ',
  'dispatch.summary.slots_available': 'ነጻ ማስያዣዎች', 'dispatch.summary.slots_allocated': 'ማረጋገጫ የሚጠብቁ',
  'dispatch.summary.unallocated_routes': 'ያልተመደቡ',
  'currency.etb': 'ብር', 'time.eta': 'የመድረሻ ጊዜ', 'time.minutes_short': 'ደቂቃ',
});

fs.writeFileSync('packages/i18n/src/locales/en.json', JSON.stringify(en, null, 2) + '\n');
fs.writeFileSync('packages/i18n/src/locales/am.json', JSON.stringify(am, null, 2) + '\n');
console.log('  i18n keys updated (dispatcher)');
NODE

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Part 1c complete — dispatcher-web (4 modules)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 The dispatcher app is now FULLY RUNNABLE and BROWSER-TESTABLE."
echo ""
echo "Start it:"
echo "  pnpm install   (from repo root, first time)"
echo "  pnpm --filter @tera/api dev       # terminal 1 (backend)"
echo "  pnpm --filter dispatcher-web dev  # terminal 2 (frontend)"
echo ""
echo "Open http://localhost:5173/ — you'll see:"
echo ""
echo "  /routes    → Morning Map"
echo "               • Leaflet map centered on Addis"
echo "               • 2 route polylines (V-101, V-102)"
echo "               • 4 curfew polygons (Merkato, Piassa, Bole, Old Airport)"
echo "               • 4 fuel station markers (colored by status)"
echo "               • Sidebar: V-101, V-102 with delivery progress"
echo "               • Table view toggle for low-bandwidth fallback"
echo ""
echo "  /builder   → Route Builder (async solve)"
echo "               • 10 pending orders (8 seeded + 2 portal)"
echo "               • 3 vehicles (V-101/102/103)"
echo "               • Select 2+ orders, pick vehicle, click Solve"
echo "               • Shows 'Waiting for solver…' → 'Solving route…'"
echo "               • If optimizer is NOT running (default here), after 15s shows:"
echo "                 'Taking longer than expected' + [Try sync solve]"
echo "               • Click Try sync solve → instant result (sync endpoint)"
echo "               • Comparison view: Manual vs Optimized side by side"
echo "               • Green pills: '12.5% fewer km' / '12.5% faster'"
echo "               • Inline map: dashed grey = manual, solid teal = optimized"
echo "               • Click 'Accept optimized' → route created, orders routed"
echo ""
echo "  /board     → Dispatch Board"
echo "               • V-102 slot is ALLOCATED (from seed)"
echo "               • Shows 0/4 or 4/4 picked state"
echo "               • If picked_count < total: button disabled ('Pick all stops first')"
echo "               • Click 'Allocate slots' to allocate remaining PLANNED routes"
echo "               • Wall mode toggle for warehouse wall screens"
echo ""
echo "  /credit    → Credit Stop List"
echo "               • 5 distributors shown (3 blocked, 2 warned)"
echo "               • Soft-mode banner (hard gate is false by default)"
echo "               • Filter: All / Overdue 30 / Over limit"
echo "               • Click 'Override' on a row → modal"
echo "               • Enter reason (5+ chars), pick expiry, Confirm → override created"
echo "               • Audit entry appears in audit_log table"
echo ""
echo "Tests:"
echo "  pnpm --filter dispatcher-web test   # 6 page tests"
echo "  pnpm --filter @tera/api test        # 23 backend tests"
echo "  pnpm --filter @tera/solver test     # 13 solver tests"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📌 Build progress:"
echo "  ✓ Part 1a — Phase 0: Foundation (models, contracts, packages)"
echo "  ✓ Part 1b — Phases 1-2: Backend (credit, geo, orders, routing)"
echo "  ✓ Part 1c — Phase 2 FE: Dispatcher app (4 modules) ← YOU ARE HERE"
echo ""
echo "📌 Next: Part 2 (Phases 3-5)"
echo "  • Phase 3: Driver mobile (offline engine + manifest + e-POD + payment + fuel)"
echo "  • Phase 4: Warehouse console (dock queue + pick stage)"
echo "  • Phase 5: Admin console (masterdata + bulk import + constraints)"
echo ""
echo "  After Part 2, you can run the FULL WAREHOUSE→DISPATCH→DRIVER loop."
echo ""
echo "Reply 'yes' to continue with Part 2."
echo "════════════════════════════════════════════════════════════════"


# ═══════════════════════════════════════════════════════════════════
# PHASE 3 — @TERA/OFFLINE-SYNC + DRIVER MOBILE
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 3 — offline sync engine + driver app"

# ── Backend patch: propagate totalQuantity to RouteStop ─────
node <<'NODE'
const fs = require('fs');
const repoPath = 'services/api/src/modules/routing/repository.ts';
let repo = fs.readFileSync(repoPath, 'utf8');
if (!repo.includes('quantityOrdered?: number')) {
  repo = repo.replace(
    `plannedEta: Date;
  }[];`,
    `plannedEta: Date;
    quantityOrdered?: number;
  }[];`
  );
  repo = repo.replace(
    `plannedEta: s.plannedEta,
          status: 'PENDING',`,
    `plannedEta: s.plannedEta,
          status: 'PENDING',
          quantityOrdered: s.quantityOrdered ?? 0,`
  );
  fs.writeFileSync(repoPath, repo);
  console.log('  patched routing/repository.ts (+quantityOrdered)');
}
const svcPath = 'services/api/src/modules/routing/service.ts';
let svc = fs.readFileSync(svcPath, 'utf8');
if (!svc.includes('quantityOrdered: (o as any).totalQuantity')) {
  svc = svc.replace(
    `plannedEta: new Date(s.eta),
      };`,
    `plannedEta: new Date(s.eta),
        quantityOrdered: (o as any).totalQuantity || 10,
      };`
  );
  fs.writeFileSync(svcPath, svc);
  console.log('  patched routing/service.ts (+totalQuantity propagation)');
}
NODE

# ═══════════════════════════════════════════════════════════════════
# @tera/offline-sync — pure SQLite engine
# ═══════════════════════════════════════════════════════════════════
W packages/offline-sync/package.json <<'EOF'
{
  "name": "@tera/offline-sync",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": { "lint": "tsc --noEmit" },
  "dependencies": { "@tera/contracts": "workspace:*" },
  "devDependencies": { "typescript": "^5.4.0" }
}
EOF

W packages/offline-sync/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true }, "include": ["src"] }
EOF

W packages/offline-sync/src/types.ts <<'EOF'
import type { SyncChange, ClientOp, OpResult } from '@tera/contracts';
export type { SyncChange, ClientOp, OpResult };

export interface SqliteAdapter {
  run(sql: string, params?: unknown[]): Promise<void>;
  all<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T[]>;
  get<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T | null>;
  transaction<T>(fn: () => Promise<T>): Promise<T>;
}

export interface OutboxOp {
  client_op_id: string;
  op_type: ClientOp['op_type'];
  entity_id: string;
  payload: Record<string, unknown>;
  queued_at: string;
  synced_at: string | null;
  result: OpResult | null;
}

export interface SyncEngineConfig {
  api_base_url: string;
  device_id: string;
  driver_id: string;
  get_auth_token?: () => Promise<string | null>;
  pull_limit?: number;
}

export interface SyncEngineState {
  client_id: string | null;
  last_cursor: string;
  last_synced_at: string | null;
}
EOF

W packages/offline-sync/src/schema.ts <<'EOF'
import type { SqliteAdapter } from './types.js';

export async function createSchema(adapter: SqliteAdapter): Promise<void> {
  await adapter.run(`CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS outbox (
      client_op_id TEXT PRIMARY KEY, op_type TEXT NOT NULL, entity_id TEXT NOT NULL,
      payload_json TEXT NOT NULL, queued_at TEXT NOT NULL, synced_at TEXT, result_json TEXT
    )
  `);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_outbox_unsynced ON outbox(synced_at)`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS route_plan (
      id TEXT PRIMARY KEY, driver_id TEXT NOT NULL, vehicle_id TEXT NOT NULL,
      status TEXT NOT NULL, planned_km REAL NOT NULL, planned_min INTEGER NOT NULL,
      start_lat REAL NOT NULL, start_lng REAL NOT NULL, updated_at TEXT NOT NULL
    )
  `);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS route_stop (
      id TEXT PRIMARY KEY, route_plan_id TEXT NOT NULL, seq INTEGER NOT NULL,
      distributor_id TEXT NOT NULL, distributor_name TEXT NOT NULL,
      lat REAL NOT NULL, lng REAL NOT NULL, planned_eta TEXT NOT NULL,
      status TEXT NOT NULL, status_updated_at TEXT NOT NULL,
      quantity_ordered INTEGER NOT NULL DEFAULT 0
    )
  `);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_route_stop_plan ON route_stop(route_plan_id, seq)`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS proof_of_delivery (
      id TEXT PRIMARY KEY, stop_id TEXT NOT NULL, outcome TEXT NOT NULL,
      qty_confirmed INTEGER, qty_ordered INTEGER, reason TEXT,
      signature_base64 TEXT, photo_base64 TEXT,
      captured_at TEXT NOT NULL, client_op_id TEXT NOT NULL, synced_at TEXT
    )
  `);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS payment (
      id TEXT PRIMARY KEY, stop_id TEXT NOT NULL, method TEXT NOT NULL,
      amount_etb REAL NOT NULL, telebirr_ref TEXT,
      client_op_id TEXT NOT NULL, captured_at TEXT NOT NULL
    )
  `);
  await adapter.run(`CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_telebirr_unique
                     ON payment(telebirr_ref) WHERE telebirr_ref IS NOT NULL`);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS vehicle (
      id TEXT PRIMARY KEY, plate TEXT NOT NULL, capacity_kg REAL NOT NULL,
      baseline_l_per_100km REAL
    )
  `);
  await adapter.run(`
    CREATE TABLE IF NOT EXISTS fuel_log (
      id TEXT PRIMARY KEY, vehicle_id TEXT NOT NULL, driver_id TEXT NOT NULL,
      liters REAL NOT NULL, amount_etb REAL NOT NULL, odometer_km REAL NOT NULL,
      station_name TEXT NOT NULL, station_id TEXT,
      variance_flag TEXT, variance_ratio REAL,
      client_op_id TEXT, captured_at TEXT NOT NULL, synced_at TEXT
    )
  `);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_fuel_log_vehicle ON fuel_log(vehicle_id, odometer_km DESC)`);
  await adapter.run(`CREATE INDEX IF NOT EXISTS idx_fuel_log_captured ON fuel_log(captured_at DESC)`);
}
EOF

W packages/offline-sync/src/state.ts <<'EOF'
import type { SqliteAdapter } from './types.js';
export async function getState(adapter: SqliteAdapter, key: string): Promise<string | null> {
  const row = await adapter.get<{ value: string }>(`SELECT value FROM state WHERE key = ?`, [key]);
  return row?.value ?? null;
}
export async function setState(adapter: SqliteAdapter, key: string, value: string): Promise<void> {
  await adapter.run(
    `INSERT INTO state(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
    [key, value],
  );
}
EOF

W packages/offline-sync/src/outbox.ts <<'EOF'
import type { SqliteAdapter, OutboxOp, ClientOp, OpResult } from './types.js';

export async function queueOp(adapter: SqliteAdapter, op: ClientOp): Promise<void> {
  await adapter.run(
    `INSERT INTO outbox(client_op_id, op_type, entity_id, payload_json, queued_at, synced_at, result_json)
     VALUES(?, ?, ?, ?, ?, NULL, NULL)`,
    [op.client_op_id, op.op_type, op.entity_id, JSON.stringify(op.payload), new Date().toISOString()],
  );
}

export async function pendingOps(adapter: SqliteAdapter, limit = 50): Promise<OutboxOp[]> {
  const rows = await adapter.all<any>(
    `SELECT * FROM outbox WHERE synced_at IS NULL ORDER BY queued_at ASC LIMIT ?`, [limit],
  );
  return rows.map((r) => ({
    client_op_id: r.client_op_id, op_type: r.op_type, entity_id: r.entity_id,
    payload: JSON.parse(r.payload_json), queued_at: r.queued_at,
    synced_at: r.synced_at, result: r.result_json ? JSON.parse(r.result_json) : null,
  }));
}

export async function countPending(adapter: SqliteAdapter): Promise<number> {
  const row = await adapter.get<{ n: number }>(`SELECT COUNT(*) AS n FROM outbox WHERE synced_at IS NULL`);
  return row?.n ?? 0;
}

export async function markOpSynced(adapter: SqliteAdapter, client_op_id: string, result: OpResult): Promise<void> {
  await adapter.run(
    `UPDATE outbox SET synced_at = ?, result_json = ? WHERE client_op_id = ?`,
    [new Date().toISOString(), JSON.stringify(result), client_op_id],
  );
}
EOF

W packages/offline-sync/src/apply.ts <<'EOF'
import type { SqliteAdapter, SyncChange } from './types.js';

export async function applyChange(adapter: SqliteAdapter, change: SyncChange): Promise<void> {
  if (change.entity_type === 'route_plan') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM route_plan WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO route_plan(id, driver_id, vehicle_id, status, planned_km, planned_min, start_lat, start_lng, updated_at)
       VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET status = excluded.status, updated_at = excluded.updated_at`,
      [change.entity_id, p.driver_id, p.vehicle_id, p.status, p.planned_km, p.planned_min, p.start_lat, p.start_lng, change.created_at],
    );
    return;
  }
  if (change.entity_type === 'route_stop') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM route_stop WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO route_stop(id, route_plan_id, seq, distributor_id, distributor_name, lat, lng, planned_eta, status, status_updated_at, quantity_ordered)
       VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET status = excluded.status, status_updated_at = excluded.status_updated_at`,
      [change.entity_id, p.route_plan_id, p.seq, p.distributor_id, p.distributor_name, p.lat, p.lng, p.planned_eta, p.status, p.status_updated_at, p.quantity_ordered ?? 0],
    );
    return;
  }
  if (change.entity_type === 'vehicle') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM vehicle WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO vehicle(id, plate, capacity_kg, baseline_l_per_100km)
       VALUES(?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET plate = excluded.plate, baseline_l_per_100km = excluded.baseline_l_per_100km`,
      [change.entity_id, p.plate, p.capacity_kg, p.baseline_l_per_100km ?? null],
    );
    return;
  }
  if (change.entity_type === 'fuel_log') {
    const p = change.payload as Record<string, any>;
    if (change.op === 'delete') await adapter.run(`DELETE FROM fuel_log WHERE id = ?`, [change.entity_id]);
    else await adapter.run(
      `INSERT INTO fuel_log(id, vehicle_id, driver_id, liters, amount_etb, odometer_km, station_name, station_id, variance_flag, variance_ratio, client_op_id, captured_at, synced_at)
       VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?) ON CONFLICT(id) DO NOTHING`,
      [change.entity_id, p.vehicle_id, p.driver_id, p.liters, p.amount_etb, p.odometer_km,
       p.station_name, p.station_id ?? null, p.variance_flag ?? 'NO_BASELINE',
       p.variance_ratio ?? null, p.captured_at, new Date().toISOString()],
    );
  }
}
EOF

W packages/offline-sync/src/driver-ops.ts <<'EOF'
import type { SqliteAdapter, ClientOp } from './types.js';
import { queueOp } from './outbox.js';

export type StopAction = 'ARRIVED' | 'DELIVERED' | 'FAILED';
export type ProofOutcome = 'DELIVERED' | 'PARTIAL' | 'NOT_AVAILABLE' | 'RETURNED';
export type PaymentMethod = 'CASH' | 'TELEBIRR';

export async function applyStopAction(
  adapter: SqliteAdapter,
  input: { stopId: string; action: StopAction; capturedAt: string; clientOpId?: string },
): Promise<ClientOp> {
  const clientOpId = input.clientOpId ?? generateClientOpId();
  const op: ClientOp = {
    client_op_id: clientOpId,
    op_type: 'route_stop.status_update',
    entity_id: input.stopId,
    payload: { status: input.action, captured_at: input.capturedAt },
  };
  await adapter.transaction(async () => {
    const row = await adapter.get<{ id: string }>(`SELECT id FROM route_stop WHERE id = ?`, [input.stopId]);
    if (!row) throw new Error(`stop ${input.stopId} not found locally`);
    await adapter.run(`UPDATE route_stop SET status = ?, status_updated_at = ? WHERE id = ?`,
      [input.action, input.capturedAt, input.stopId]);
    await queueOp(adapter, op);
  });
  return op;
}

export interface PaymentInput { method: PaymentMethod; amountEtb: number; telebirrRef: string | null; }

export interface ApplyProofInput {
  stopId: string; outcome: ProofOutcome;
  qtyConfirmed: number | null; qtyOrdered: number | null;
  reason: string | null; signatureBase64: string | null; photoBase64: string | null;
  capturedAt: string; payment?: PaymentInput | null;
  clientOpId?: string; proofId?: string; paymentId?: string;
}

export interface ApplyProofResult {
  clientOpId: string; proofId: string; resultingStatus: StopAction;
  payment: { id: string } | null;
}

export async function applyProofCapture(
  adapter: SqliteAdapter, input: ApplyProofInput,
): Promise<ApplyProofResult> {
  const clientOpId = input.clientOpId ?? generateClientOpId();
  const proofId = input.proofId ?? generateId('proof');
  const paymentId = input.payment ? (input.paymentId ?? generateId('pay')) : null;
  const resultingStatus = statusForOutcome(input.outcome);
  const op: ClientOp = {
    client_op_id: clientOpId, op_type: 'route_stop.proof', entity_id: input.stopId,
    payload: {
      outcome: input.outcome, qty_confirmed: input.qtyConfirmed, qty_ordered: input.qtyOrdered,
      reason: input.reason, signature_base64: input.signatureBase64, photo_base64: input.photoBase64,
      captured_at: input.capturedAt,
      payment: input.payment ? { method: input.payment.method, amount_etb: input.payment.amountEtb, telebirr_ref: input.payment.telebirrRef } : null,
    },
  };
  await adapter.transaction(async () => {
    const row = await adapter.get<{ id: string }>(`SELECT id FROM route_stop WHERE id = ?`, [input.stopId]);
    if (!row) throw new Error(`stop ${input.stopId} not found locally`);
    await adapter.run(
      `INSERT INTO proof_of_delivery (id, stop_id, outcome, qty_confirmed, qty_ordered, reason,
        signature_base64, photo_base64, captured_at, client_op_id, synced_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
      [proofId, input.stopId, input.outcome, input.qtyConfirmed, input.qtyOrdered, input.reason,
       input.signatureBase64, input.photoBase64, input.capturedAt, clientOpId],
    );
    if (input.payment && paymentId) {
      await adapter.run(
        `INSERT INTO payment (id, stop_id, method, amount_etb, telebirr_ref, client_op_id, captured_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [paymentId, input.stopId, input.payment.method, input.payment.amountEtb,
         input.payment.telebirrRef, clientOpId, input.capturedAt],
      );
    }
    await adapter.run(`UPDATE route_stop SET status = ?, status_updated_at = ? WHERE id = ?`,
      [resultingStatus, input.capturedAt, input.stopId]);
    await queueOp(adapter, op);
  });
  return { clientOpId, proofId, resultingStatus, payment: paymentId ? { id: paymentId } : null };
}

function statusForOutcome(outcome: ProofOutcome): StopAction {
  if (outcome === 'DELIVERED' || outcome === 'PARTIAL') return 'DELIVERED';
  return 'FAILED';
}
function generateClientOpId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}-${Math.random().toString(36).slice(2, 10)}`;
}
function generateId(prefix: string): string {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}
EOF

W packages/offline-sync/src/manifest-read.ts <<'EOF'
import type { SqliteAdapter } from './types.js';

export type PaymentStatus = 'NONE' | 'PENDING' | 'CONFIRMED';
export type PaymentMethodValue = 'CASH' | 'TELEBIRR';

export interface LocalStop {
  id: string; seq: number;
  distributor_id: string; distributor_name: string;
  lat: number; lng: number;
  planned_eta: string;
  status: 'PENDING' | 'ARRIVED' | 'DELIVERED' | 'FAILED';
  status_updated_at: string;
  quantity_ordered: number;
  payment_status: PaymentStatus;
  payment_method: PaymentMethodValue | null;
  payment_amount_etb: number | null;
}
export interface LocalPlan {
  id: string; vehicle_id: string; status: string;
  planned_km: number; planned_min: number;
  start_lat: number; start_lng: number;
}
export interface LocalManifest {
  plan: LocalPlan | null;
  stops: LocalStop[];
  counts: { total: number; pending: number; delivered: number; failed: number; paid: number; unpaid: number; };
}

interface RawStopRow {
  id: string; seq: number; distributor_id: string; distributor_name: string;
  lat: number; lng: number; planned_eta: string; status: string; status_updated_at: string;
  quantity_ordered: number;
  payment_id: string | null; payment_method: string | null;
  payment_amount_etb: number | null; payment_synced_at: string | null;
  payment_result_json: string | null;
}

export async function getLocalManifest(adapter: SqliteAdapter): Promise<LocalManifest> {
  const planRow = await adapter.get<LocalPlan>(
    `SELECT id, vehicle_id, status, planned_km, planned_min, start_lat, start_lng FROM route_plan LIMIT 1`,
  );
  const rows = await adapter.all<RawStopRow>(
    `SELECT s.id, s.seq, s.distributor_id, s.distributor_name, s.lat, s.lng,
            s.planned_eta, s.status, s.status_updated_at, s.quantity_ordered,
            p.id AS payment_id, p.method AS payment_method, p.amount_etb AS payment_amount_etb,
            o.synced_at AS payment_synced_at, o.result_json AS payment_result_json
     FROM route_stop s
     LEFT JOIN payment p ON p.stop_id = s.id
     LEFT JOIN outbox o ON o.client_op_id = p.client_op_id
     ORDER BY s.seq ASC`,
  );
  const stops: LocalStop[] = rows.map((r) => {
    let paymentStatus: PaymentStatus = 'NONE';
    if (r.payment_id) {
      if (!r.payment_synced_at) paymentStatus = 'PENDING';
      else {
        let rejected = false;
        if (r.payment_result_json) {
          try { rejected = JSON.parse(r.payment_result_json).status === 'rejected'; } catch { /* ignore */ }
        }
        paymentStatus = rejected ? 'PENDING' : 'CONFIRMED';
      }
    }
    return {
      id: r.id, seq: r.seq,
      distributor_id: r.distributor_id, distributor_name: r.distributor_name,
      lat: r.lat, lng: r.lng, planned_eta: r.planned_eta,
      status: r.status as LocalStop['status'],
      status_updated_at: r.status_updated_at,
      quantity_ordered: r.quantity_ordered,
      payment_status: paymentStatus,
      payment_method: (r.payment_method as PaymentMethodValue | null) ?? null,
      payment_amount_etb: r.payment_amount_etb,
    };
  });
  const counts = {
    total: stops.length,
    pending: stops.filter((s) => s.status === 'PENDING').length,
    delivered: stops.filter((s) => s.status === 'DELIVERED').length,
    failed: stops.filter((s) => s.status === 'FAILED').length,
    paid: stops.filter((s) => s.payment_status === 'CONFIRMED').length,
    unpaid: stops.filter((s) => s.status === 'DELIVERED' && s.payment_status !== 'CONFIRMED').length,
  };
  return { plan: planRow, stops, counts };
}
EOF

W packages/offline-sync/src/fuel.ts <<'EOF'
import type { SqliteAdapter, ClientOp } from './types.js';
import { queueOp } from './outbox.js';

export type FuelHintLevel = 'ok' | 'high' | 'low' | 'unknown';
export interface FuelHint { level: FuelHintLevel; l_per_100km: number | null; ratio: number | null; }

export interface LocalVehicle {
  id: string; plate: string; capacity_kg: number; baseline_l_per_100km: number | null;
}
export interface LocalFuelFill {
  id: string; vehicle_id: string; liters: number; amount_etb: number;
  odometer_km: number; station_name: string;
  variance_flag: string | null; variance_ratio: number | null;
  captured_at: string; synced_at: string | null;
}
export interface FuelContext {
  vehicle: LocalVehicle | null; last_fill: LocalFuelFill | null;
  recent_fills: LocalFuelFill[];
}

export async function getFuelContext(adapter: SqliteAdapter): Promise<FuelContext> {
  const vehicle = await adapter.get<LocalVehicle>(`SELECT * FROM vehicle LIMIT 1`);
  const recent = await adapter.all<LocalFuelFill>(
    `SELECT id, vehicle_id, liters, amount_etb, odometer_km, station_name,
            variance_flag, variance_ratio, captured_at, synced_at
     FROM fuel_log ORDER BY captured_at DESC LIMIT 10`,
  );
  return { vehicle: vehicle ?? null, last_fill: recent[0] ?? null, recent_fills: recent };
}

export function computeFuelHint(input: {
  liters: number; odometer_km: number;
  prev_odometer_km: number | null; baseline_l_per_100km: number | null;
}): FuelHint {
  if (!input.baseline_l_per_100km || input.baseline_l_per_100km <= 0) return { level: 'unknown', l_per_100km: null, ratio: null };
  if (input.prev_odometer_km === null) return { level: 'unknown', l_per_100km: null, ratio: null };
  const distance = input.odometer_km - input.prev_odometer_km;
  if (distance <= 0) return { level: 'unknown', l_per_100km: null, ratio: null };
  const l_per_100km = (input.liters / distance) * 100;
  const ratio = l_per_100km / input.baseline_l_per_100km;
  let level: FuelHintLevel = 'ok';
  if (ratio > 1.5) level = 'high';
  else if (ratio < 0.7) level = 'low';
  return { level, l_per_100km: Math.round(l_per_100km * 100) / 100, ratio: Math.round(ratio * 100) / 100 };
}

export interface ApplyFuelInput {
  vehicleId: string; driverId: string;
  liters: number; amountEtb: number; odometerKm: number;
  stationName: string; stationId: string | null; capturedAt: string;
  clientOpId?: string; logId?: string;
}
export interface ApplyFuelResult { clientOpId: string; logId: string; hint: FuelHint; }

export async function applyFuelLog(adapter: SqliteAdapter, input: ApplyFuelInput): Promise<ApplyFuelResult> {
  if (!Number.isFinite(input.liters) || input.liters <= 0) throw new Error('liters must be > 0');
  if (!Number.isFinite(input.amountEtb) || input.amountEtb <= 0) throw new Error('amount must be > 0');
  if (!Number.isFinite(input.odometerKm) || input.odometerKm <= 0) throw new Error('odometer must be > 0');
  if (!input.stationName || input.stationName.trim().length === 0) throw new Error('station name required');
  const last = await adapter.get<{ odometer_km: number }>(
    `SELECT odometer_km FROM fuel_log WHERE vehicle_id = ? ORDER BY odometer_km DESC LIMIT 1`, [input.vehicleId],
  );
  if (last && input.odometerKm <= last.odometer_km) {
    throw new Error(`odometer must be greater than last reading (${last.odometer_km})`);
  }
  const vehicle = await adapter.get<LocalVehicle>(`SELECT * FROM vehicle WHERE id = ?`, [input.vehicleId]);
  const hint = computeFuelHint({
    liters: input.liters, odometer_km: input.odometerKm,
    prev_odometer_km: last?.odometer_km ?? null,
    baseline_l_per_100km: vehicle?.baseline_l_per_100km ?? null,
  });
  const clientOpId = input.clientOpId ?? generateId('fuel-op');
  const logId = input.logId ?? generateId('fuel');
  const op: ClientOp = {
    client_op_id: clientOpId, op_type: 'driver.fuel_log', entity_id: logId,
    payload: {
      vehicle_id: input.vehicleId, liters: input.liters, amount_etb: input.amountEtb,
      odometer_km: input.odometerKm, station_name: input.stationName.trim(),
      station_id: input.stationId, captured_at: input.capturedAt,
    },
  };
  await adapter.transaction(async () => {
    await adapter.run(
      `INSERT INTO fuel_log
         (id, vehicle_id, driver_id, liters, amount_etb, odometer_km, station_name, station_id,
          variance_flag, variance_ratio, client_op_id, captured_at, synced_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
      [logId, input.vehicleId, input.driverId, input.liters, input.amountEtb, input.odometerKm,
       input.stationName.trim(), input.stationId,
       hint.level === 'unknown' ? 'NO_BASELINE' : hint.level.toUpperCase(),
       hint.ratio, clientOpId, input.capturedAt],
    );
    await queueOp(adapter, op);
  });
  return { clientOpId, logId, hint };
}
function generateId(prefix: string): string {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}
EOF

W packages/offline-sync/src/sync-engine.ts <<'EOF'
import type { PullResponse, PushResponse, OpResult } from '@tera/contracts';
import type { SqliteAdapter, SyncEngineConfig, SyncEngineState } from './types.js';
import { createSchema } from './schema.js';
import { getState, setState } from './state.js';
import { pendingOps, markOpSynced, countPending } from './outbox.js';
import { applyChange } from './apply.js';

const KEY_CLIENT_ID = 'client_id';
const KEY_CURSOR = 'last_cursor';
const KEY_LAST_SYNC = 'last_synced_at';

export class SyncEngine {
  private adapter: SqliteAdapter;
  private config: SyncEngineConfig;
  private initialized = false;

  constructor(adapter: SqliteAdapter, config: SyncEngineConfig) {
    this.adapter = adapter;
    this.config = config;
  }

  async init(): Promise<void> {
    if (this.initialized) return;
    await createSchema(this.adapter);
    this.initialized = true;
  }

  async getState(): Promise<SyncEngineState> {
    const [clientId, cursor, lastSync] = await Promise.all([
      getState(this.adapter, KEY_CLIENT_ID),
      getState(this.adapter, KEY_CURSOR),
      getState(this.adapter, KEY_LAST_SYNC),
    ]);
    return { client_id: clientId, last_cursor: cursor ?? '0', last_synced_at: lastSync };
  }

  async pendingCount(): Promise<number> { return countPending(this.adapter); }

  async sync(): Promise<{ pulled: number; pushed: number; errors: string[] }> {
    await this.init();
    const errors: string[] = [];
    let pulled = 0;
    let pushed = 0;
    try {
      const clientId = await this.ensureClient();
      const pullRes = await this.pull(clientId);
      pulled = pullRes.changes.length;
      await setState(this.adapter, KEY_CURSOR, pullRes.next_cursor);
      await setState(this.adapter, KEY_LAST_SYNC, new Date().toISOString());
      const pushRes = await this.push(clientId);
      pushed = pushRes.results.filter((r) => r.status === 'accepted').length;
    } catch (e) {
      errors.push(e instanceof Error ? e.message : String(e));
    }
    return { pulled, pushed, errors };
  }

  private async ensureClient(): Promise<string> {
    const existing = await getState(this.adapter, KEY_CLIENT_ID);
    if (existing) return existing;
    const res = await this.fetch<{ client_id: string }>('/sync/v1/clients', {
      method: 'POST', body: { device_id: this.config.device_id, driver_id: this.config.driver_id },
    });
    await setState(this.adapter, KEY_CLIENT_ID, res.client_id);
    return res.client_id;
  }

  private async pull(clientId: string): Promise<PullResponse> {
    const cursor = (await getState(this.adapter, KEY_CURSOR)) ?? '0';
    const limit = this.config.pull_limit ?? 200;
    const res = await this.fetch<PullResponse>(
      `/sync/v1/pull?client_id=${encodeURIComponent(clientId)}&cursor=${encodeURIComponent(cursor)}&limit=${limit}`,
      { method: 'GET' },
    );
    await this.adapter.transaction(async () => {
      for (const change of res.changes) await applyChange(this.adapter, change);
    });
    return res;
  }

  private async push(clientId: string): Promise<PushResponse> {
    const ops = await pendingOps(this.adapter, 50);
    if (ops.length === 0) return { results: [], server_time: new Date().toISOString() };
    const body = {
      client_id: clientId,
      ops: ops.map((o) => ({ client_op_id: o.client_op_id, op_type: o.op_type, entity_id: o.entity_id, payload: o.payload })),
    };
    const res = await this.fetch<PushResponse>('/sync/v1/push', { method: 'POST', body });
    for (const r of res.results) await markOpSynced(this.adapter, r.client_op_id, r as OpResult);
    return res;
  }

  private async fetch<T>(path: string, init: { method: string; body?: unknown }): Promise<T> {
    const url = `${this.config.api_base_url.replace(/\/$/, '')}${path}`;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.config.get_auth_token) {
      const token = await this.config.get_auth_token();
      if (token) headers.Authorization = `Bearer ${token}`;
    }
    const res = await fetch(url, {
      method: init.method, headers,
      body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`sync ${init.method} ${path} failed (${res.status}): ${text || res.statusText}`);
    }
    return res.json() as Promise<T>;
  }
}
EOF

W packages/offline-sync/src/conflict.ts <<'EOF'
export type Entity = 'route_stop' | 'credit' | 'payment' | 'inventory' | 'unknown';
export type Resolution =
  | { kind: 'accept_client'; reason: string }
  | { kind: 'server_wins'; reason: string }
  | { kind: 'reject_conflict'; reason: string };

export function resolveConflict(input: { entity: Entity; server_updated_at: string; client_captured_at: string }): Resolution {
  if (input.entity === 'credit' || input.entity === 'payment' || input.entity === 'inventory') {
    return { kind: 'server_wins', reason: `${input.entity} is server-authoritative` };
  }
  if (input.entity === 'route_stop') {
    const serverMs = Date.parse(input.server_updated_at);
    const clientMs = Date.parse(input.client_captured_at);
    if (!Number.isFinite(serverMs) || !Number.isFinite(clientMs)) return { kind: 'reject_conflict', reason: 'invalid timestamp' };
    if (clientMs > serverMs) return { kind: 'accept_client', reason: 'client acted after server last changed' };
    return { kind: 'reject_conflict', reason: 'server updated after client captured' };
  }
  return { kind: 'server_wins', reason: 'unknown entity — default to server' };
}
EOF

W packages/offline-sync/src/index.ts <<'EOF'
export { SyncEngine } from './sync-engine.js';
export { createSchema } from './schema.js';
export { queueOp, pendingOps, countPending, markOpSynced } from './outbox.js';
export { resolveConflict, type Resolution, type Entity } from './conflict.js';
export { getState, setState } from './state.js';
export {
  applyStopAction, applyProofCapture,
  type StopAction, type ProofOutcome, type PaymentMethod, type PaymentInput,
  type ApplyProofInput, type ApplyProofResult,
} from './driver-ops.js';
export {
  getLocalManifest,
  type LocalManifest, type LocalPlan, type LocalStop, type PaymentStatus, type PaymentMethodValue,
} from './manifest-read.js';
export {
  applyFuelLog, computeFuelHint, getFuelContext,
  type FuelHint, type FuelHintLevel, type LocalVehicle, type LocalFuelFill, type FuelContext,
  type ApplyFuelInput, type ApplyFuelResult,
} from './fuel.js';
export type * from './types.js';
EOF

# ═══════════════════════════════════════════════════════════════════
# DRIVER MOBILE APP (Expo)
# ═══════════════════════════════════════════════════════════════════
W apps/driver-mobile/package.json <<'EOF'
{
  "name": "driver-mobile",
  "private": true,
  "version": "0.1.0",
  "main": "index.ts",
  "scripts": { "start": "expo start", "android": "expo run:android", "ios": "expo run:ios", "lint": "tsc --noEmit" },
  "dependencies": {
    "expo": "^51.0.0",
    "expo-sqlite": "^14.0.0",
    "expo-secure-store": "^13.0.0",
    "expo-status-bar": "^1.12.0",
    "expo-constants": "^16.0.0",
    "expo-camera": "^15.0.0",
    "react": "^18.3.0",
    "react-native": "^0.74.0",
    "react-native-safe-area-context": "^4.10.0",
    "react-native-signature-canvas": "^4.7.0",
    "@tera/i18n": "workspace:*",
    "@tera/offline-sync": "workspace:*",
    "@tera/contracts": "workspace:*"
  },
  "devDependencies": { "typescript": "^5.4.0", "@types/react": "^18.3.0" }
}
EOF

W apps/driver-mobile/app.json <<'EOF'
{
  "expo": {
    "name": "Tera Driver",
    "slug": "tera-driver",
    "version": "0.1.0",
    "orientation": "portrait",
    "scheme": "teradriver",
    "ios": { "bundleIdentifier": "et.tera.driver" },
    "android": { "package": "et.tera.driver" },
    "extra": { "apiUrl": "http://10.0.2.2:8000", "driverId": "D-201" }
  }
}
EOF

W apps/driver-mobile/babel.config.js <<'EOF'
module.exports = function (api) { api.cache(true); return { presets: ['babel-preset-expo'] }; };
EOF

W apps/driver-mobile/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "jsx": "react-jsx", "types": ["react", "react-native"] }, "include": ["src", "App.tsx", "index.ts"] }
EOF

W apps/driver-mobile/index.ts <<'EOF'
import { registerRootComponent } from 'expo';
import App from './App';
registerRootComponent(App);
EOF

W apps/driver-mobile/src/offline/adapter.ts <<'EOF'
import * as SQLite from 'expo-sqlite';
import type { SqliteAdapter } from '@tera/offline-sync';

let cached: SqliteAdapter | null = null;

export async function createExpoAdapter(dbName = 'tera.db'): Promise<SqliteAdapter> {
  if (cached) return cached;
  const db = await SQLite.openDatabaseAsync(dbName);
  cached = {
    async run(sql, params = []) { await db.runAsync(sql, params as any[]); },
    async all<T>(sql: string, params: unknown[] = []) { return (await db.getAllAsync(sql, params as any[])) as T[]; },
    async get<T>(sql: string, params: unknown[] = []) { return ((await db.getFirstAsync(sql, params as any[])) as T) ?? null; },
    async transaction<T>(fn: () => Promise<T>): Promise<T> {
      let result!: T;
      await db.withTransactionAsync(async () => { result = await fn(); });
      return result;
    },
  };
  return cached;
}
EOF

W apps/driver-mobile/src/offline/engine.ts <<'EOF'
import * as SecureStore from 'expo-secure-store';
import Constants from 'expo-constants';
import { SyncEngine } from '@tera/offline-sync';
import { createExpoAdapter } from './adapter';

const KEY_DEVICE_ID = 'tera_device_id';
function getExtra(key: string, fallback: string): string {
  const extra = (Constants.expoConfig?.extra ?? {}) as Record<string, string>;
  return extra[key] ?? fallback;
}
function generateDeviceId(): string {
  return 'dev-' + Math.random().toString(36).slice(2) + Date.now().toString(36);
}
async function loadOrCreateDeviceId(): Promise<string> {
  const existing = await SecureStore.getItemAsync(KEY_DEVICE_ID);
  if (existing) return existing;
  const fresh = generateDeviceId();
  await SecureStore.setItemAsync(KEY_DEVICE_ID, fresh);
  return fresh;
}

let singleton: SyncEngine | null = null;
export async function getEngine(): Promise<SyncEngine> {
  if (singleton) return singleton;
  const adapter = await createExpoAdapter();
  const deviceId = await loadOrCreateDeviceId();
  singleton = new SyncEngine(adapter, {
    api_base_url: getExtra('apiUrl', 'http://10.0.2.2:8000'),
    device_id: deviceId,
    driver_id: getExtra('driverId', 'D-201'),
  });
  await singleton.init();
  return singleton;
}
EOF

W apps/driver-mobile/src/offline/local.ts <<'EOF'
import {
  applyStopAction, applyProofCapture, applyFuelLog,
  getLocalManifest, getFuelContext,
  type StopAction, type ProofOutcome, type PaymentMethod,
  type LocalManifest, type FuelContext, type FuelHint,
} from '@tera/offline-sync';
import { createExpoAdapter } from './adapter';

export async function readManifest(): Promise<LocalManifest> {
  const adapter = await createExpoAdapter();
  return getLocalManifest(adapter);
}
export async function readFuelContext(): Promise<FuelContext> {
  const adapter = await createExpoAdapter();
  return getFuelContext(adapter);
}
export async function recordStopAction(stopId: string, action: StopAction): Promise<void> {
  const adapter = await createExpoAdapter();
  await applyStopAction(adapter, { stopId, action, capturedAt: new Date().toISOString() });
}

export interface RecordProofInput {
  stopId: string; outcome: ProofOutcome;
  qtyConfirmed: number; qtyOrdered: number;
  reason: string | null; signatureBase64: string | null; photoBase64: string | null;
  payment: { method: PaymentMethod; amountEtb: number; telebirrRef: string | null } | null;
}
export async function recordProofOfDelivery(input: RecordProofInput): Promise<void> {
  const adapter = await createExpoAdapter();
  await applyProofCapture(adapter, {
    stopId: input.stopId, outcome: input.outcome,
    qtyConfirmed: input.qtyConfirmed, qtyOrdered: input.qtyOrdered,
    reason: input.reason, signatureBase64: input.signatureBase64, photoBase64: input.photoBase64,
    capturedAt: new Date().toISOString(), payment: input.payment,
  });
}

export interface RecordFuelInput {
  vehicleId: string; driverId: string;
  liters: number; amountEtb: number; odometerKm: number;
  stationName: string; stationId: string | null;
}
export async function recordFuelLog(input: RecordFuelInput): Promise<FuelHint> {
  const adapter = await createExpoAdapter();
  const result = await applyFuelLog(adapter, { ...input, capturedAt: new Date().toISOString() });
  return result.hint;
}
EOF

W apps/driver-mobile/src/screens/SyncDemoScreen.tsx <<'EOF'
import { useCallback, useEffect, useState } from 'react';
import { View, Text, ScrollView, Pressable, ActivityIndicator, StyleSheet, RefreshControl } from 'react-native';
import { useI18n } from '@tera/i18n';
import { getEngine } from '../offline/engine';
import { createExpoAdapter } from '../offline/adapter';

export function SyncDemoScreen() {
  const { t } = useI18n();
  const [status, setStatus] = useState({ clientId: null as string | null, cursor: '0', lastSyncedAt: null as string | null, pending: 0, syncing: false, error: null as string | null });
  const [stops, setStops] = useState<any[]>([]);
  const [plan, setPlan] = useState<any>(null);

  const refresh = useCallback(async () => {
    const engine = await getEngine();
    const state = await engine.getState();
    const pending = await engine.pendingCount();
    const adapter = await createExpoAdapter();
    const plans = await adapter.all(`SELECT id, vehicle_id, status FROM route_plan LIMIT 1`);
    const ss = await adapter.all(`SELECT id, seq, distributor_name, status, planned_eta FROM route_stop ORDER BY seq ASC`);
    setStatus((s) => ({ ...s, clientId: state.client_id, cursor: state.last_cursor, lastSyncedAt: state.last_synced_at, pending }));
    setPlan(plans[0] ?? null);
    setStops(ss);
  }, []);

  useEffect(() => { void refresh(); }, [refresh]);

  const runSync = async () => {
    setStatus((s) => ({ ...s, syncing: true, error: null }));
    try {
      const engine = await getEngine();
      const r = await engine.sync();
      await refresh();
      setStatus((s) => ({ ...s, syncing: false, error: r.errors.length > 0 ? r.errors.join(' · ') : null }));
    } catch (e) {
      setStatus((s) => ({ ...s, syncing: false, error: e instanceof Error ? e.message : String(e) }));
    }
  };

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={status.syncing} onRefresh={runSync} />}>
      <Text style={styles.title}>{t('driver.sync.title')}</Text>
      <Text style={styles.subtitle}>{t('driver.sync.subtitle')}</Text>
      <View style={styles.card}>
        <Row label={t('driver.sync.device')} value={status.clientId ?? '—'} mono />
        <Row label={t('driver.sync.cursor')} value={status.cursor} mono />
        <Row label={t('driver.sync.last_sync')} value={status.lastSyncedAt ? new Date(status.lastSyncedAt).toLocaleTimeString() : '—'} />
        <Row label={t('driver.sync.pending')} value={String(status.pending)} />
      </View>
      <Pressable onPress={runSync} disabled={status.syncing}
        style={({ pressed }) => [styles.button, (pressed || status.syncing) && { opacity: 0.7 }]}>
        {status.syncing ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>{t('driver.sync.now')}</Text>}
      </Pressable>
      {status.error && <View style={styles.errorBox}><Text style={styles.errorText}>{status.error}</Text></View>}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>{t('driver.sync.manifest')}</Text>
        {plan ? (
          <>
            <Text style={styles.muted}>{plan.vehicle_id} · {plan.status} · {stops.length} stops</Text>
            {stops.map((s) => (
              <View key={s.id} style={styles.stopRow}>
                <Text style={styles.stopSeq}>{s.seq}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.stopName}>{s.distributor_name}</Text>
                  <Text style={styles.muted}>{new Date(s.planned_eta).toLocaleTimeString()}</Text>
                </View>
                <Text style={styles.statusPill}>{s.status}</Text>
              </View>
            ))}
          </>
        ) : <Text style={styles.muted}>{t('driver.sync.empty')}</Text>}
      </View>
    </ScrollView>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={[styles.statValue, mono && { fontFamily: 'monospace' }]} numberOfLines={1}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  content: { padding: 16, paddingBottom: 48 },
  title: { fontSize: 24, fontWeight: '700', color: '#1a1a1a', marginTop: 8 },
  subtitle: { fontSize: 14, color: '#6b6b6b', marginTop: 4, marginBottom: 16 },
  card: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12, marginBottom: 12 },
  stat: { paddingVertical: 6, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#eee', flexDirection: 'row', justifyContent: 'space-between' },
  statLabel: { fontSize: 13, color: '#6b6b6b' },
  statValue: { fontSize: 13, color: '#1a1a1a', maxWidth: '60%' },
  button: { backgroundColor: '#0f766e', borderRadius: 10, paddingVertical: 14, alignItems: 'center', marginVertical: 8 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
  errorBox: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', borderWidth: 1, borderRadius: 8, padding: 10, marginTop: 8 },
  errorText: { color: '#b91c1c', fontSize: 13 },
  section: { marginTop: 16 },
  sectionTitle: { fontSize: 16, fontWeight: '600', color: '#1a1a1a', marginBottom: 8 },
  muted: { fontSize: 12, color: '#6b6b6b' },
  stopRow: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 8, padding: 10, marginTop: 6 },
  stopSeq: { width: 24, height: 24, textAlign: 'center', lineHeight: 24, borderRadius: 12, backgroundColor: '#f3f3f3', color: '#1a1a1a', fontWeight: '600', marginRight: 10, fontSize: 12 },
  stopName: { fontSize: 14, fontWeight: '500', color: '#1a1a1a' },
  statusPill: { fontSize: 11, fontWeight: '500', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 999, backgroundColor: '#f3f3f3', color: '#6b6b6b' },
});
EOF

W apps/driver-mobile/src/screens/StopActionSheet.tsx <<'EOF'
import { Modal, View, Text, Pressable, StyleSheet } from 'react-native';
import { useI18n } from '@tera/i18n';
import type { LocalStop, StopAction, ProofOutcome } from '@tera/offline-sync';

export type SheetChoice = { kind: 'status'; action: StopAction } | { kind: 'proof'; outcome: ProofOutcome };
interface Props { stop: LocalStop | null; onChoose: (c: SheetChoice) => void; onCancel: () => void; }

const CHOICES = [
  { id: 'arrived',     choice: { kind: 'status' as const, action: 'ARRIVED' as const },  labelKey: 'driver.manifest.action.arrived',     color: '#b45309', bg: '#fffbeb' },
  { id: 'delivered',   choice: { kind: 'proof' as const, outcome: 'DELIVERED' as const }, labelKey: 'driver.manifest.action.delivered',  color: '#166534', bg: '#f0fdf4' },
  { id: 'partial',     choice: { kind: 'proof' as const, outcome: 'PARTIAL' as const },   labelKey: 'driver.manifest.action.partial',    color: '#0f766e', bg: '#ecfdf5' },
  { id: 'not_available', choice: { kind: 'proof' as const, outcome: 'NOT_AVAILABLE' as const }, labelKey: 'driver.manifest.action.not_available', color: '#b91c1c', bg: '#fef2f2' },
];

export function StopActionSheet({ stop, onChoose, onCancel }: Props) {
  const { t } = useI18n();
  return (
    <Modal visible={stop !== null} transparent animationType="slide" onRequestClose={onCancel}>
      <Pressable style={styles.backdrop} onPress={onCancel}>
        <Pressable style={styles.sheet} onPress={() => {}}>
          {stop && (
            <>
              <View style={styles.header}>
                <Text style={styles.seq}>#{stop.seq}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.name}>{stop.distributor_name}</Text>
                  <Text style={styles.muted}>{t('time.eta')} {new Date(stop.planned_eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} · {t('driver.epod.ordered')}: {stop.quantity_ordered}</Text>
                </View>
              </View>
              {CHOICES.map((c) => (
                <Pressable key={c.id} onPress={() => onChoose(c.choice)}
                  style={({ pressed }) => [styles.actionBtn, { backgroundColor: c.bg }, pressed && { opacity: 0.7 }]}>
                  <Text style={[styles.actionText, { color: c.color }]}>{t(c.labelKey)}</Text>
                </Pressable>
              ))}
              <Pressable onPress={onCancel} style={({ pressed }) => [styles.cancelBtn, pressed && { opacity: 0.6 }]}>
                <Text style={styles.cancelText}>{t('common.cancel')}</Text>
              </Pressable>
            </>
          )}
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  sheet: { backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, paddingBottom: 36 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 16 },
  seq: { width: 32, height: 32, textAlign: 'center', lineHeight: 32, borderRadius: 16, backgroundColor: '#f3f3f3', fontWeight: '700', fontSize: 13, marginRight: 12, color: '#1a1a1a' },
  name: { fontSize: 17, fontWeight: '600', color: '#1a1a1a' },
  muted: { fontSize: 13, color: '#6b6b6b', marginTop: 2 },
  actionBtn: { paddingVertical: 16, borderRadius: 12, alignItems: 'center', marginBottom: 8 },
  actionText: { fontSize: 16, fontWeight: '600' },
  cancelBtn: { paddingVertical: 14, alignItems: 'center', marginTop: 4 },
  cancelText: { fontSize: 15, color: '#6b6b6b', fontWeight: '500' },
});
EOF

W apps/driver-mobile/src/screens/ManifestScreen.tsx <<'EOF'
import { useCallback, useEffect, useState } from 'react';
import { View, Text, ScrollView, Pressable, ActivityIndicator, StyleSheet, RefreshControl, Alert } from 'react-native';
import { useI18n } from '@tera/i18n';
import type { LocalManifest, LocalStop, ProofOutcome } from '@tera/offline-sync';
import { readManifest, recordStopAction } from '../offline/local';
import { getEngine } from '../offline/engine';
import { StopActionSheet, type SheetChoice } from './StopActionSheet';
import { EpodScreen } from './EpodScreen';

const EMPTY: LocalManifest = { plan: null, stops: [], counts: { total: 0, pending: 0, delivered: 0, failed: 0, paid: 0, unpaid: 0 } };

export function ManifestScreen() {
  const { t } = useI18n();
  const [manifest, setManifest] = useState<LocalManifest>(EMPTY);
  const [pendingOps, setPendingOps] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [banner, setBanner] = useState<{ kind: 'error' | 'info'; text: string } | null>(null);
  const [sheetStop, setSheetStop] = useState<LocalStop | null>(null);
  const [epodStop, setEpodStop] = useState<LocalStop | null>(null);
  const [epodOutcome, setEpodOutcome] = useState<ProofOutcome | null>(null);

  const refreshAll = useCallback(async () => {
    setManifest(await readManifest());
    const engine = await getEngine();
    setPendingOps(await engine.pendingCount());
  }, []);
  useEffect(() => { void refreshAll(); }, [refreshAll]);

  const doSync = useCallback(async (userTriggered = false) => {
    if (userTriggered) setBanner(null);
    setSyncing(true);
    try {
      const engine = await getEngine();
      const r = await engine.sync();
      await refreshAll();
      if (userTriggered) {
        if (r.errors.length > 0) setBanner({ kind: 'error', text: r.errors.join(' · ') });
        else setBanner({ kind: 'info', text: t('driver.manifest.sync_ok', { pulled: r.pulled, pushed: r.pushed }) });
      }
    } catch (e) {
      if (userTriggered) setBanner({ kind: 'error', text: e instanceof Error ? e.message : String(e) });
    } finally { setSyncing(false); }
  }, [refreshAll, t]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true); await doSync(true); setRefreshing(false);
  }, [doSync]);

  const onChoose = useCallback((choice: SheetChoice) => {
    const stop = sheetStop;
    setSheetStop(null);
    if (!stop) return;
    if (choice.kind === 'status') {
      void (async () => {
        try {
          await recordStopAction(stop.id, choice.action);
          await refreshAll(); void doSync(false);
        } catch (e) { setBanner({ kind: 'error', text: e instanceof Error ? e.message : String(e) }); }
      })();
    } else {
      setEpodStop(stop); setEpodOutcome(choice.outcome);
    }
  }, [sheetStop, refreshAll, doSync]);

  const onEpodSaved = useCallback(async () => {
    setEpodStop(null); setEpodOutcome(null);
    await refreshAll(); void doSync(false);
  }, [refreshAll, doSync]);

  const { plan, stops, counts } = manifest;
  return (
    <>
      <ScrollView style={styles.root} contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#0f766e" />}>
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            <Text style={styles.title}>{t('driver.manifest.title')}</Text>
            <Text style={styles.subtitle}>{plan ? `${plan.vehicle_id} · ${counts.total} ${t('dispatch.stops')}` : t('driver.manifest.not_synced')}</Text>
          </View>
          <Pressable onPress={() => doSync(true)} disabled={syncing}
            style={({ pressed }) => [styles.syncBtn, (pressed || syncing) && { opacity: 0.6 }]}>
            {syncing ? <ActivityIndicator color="#fff" size="small" />
              : <Text style={styles.syncBtnText}>{pendingOps > 0 ? `${pendingOps}` : t('driver.manifest.sync')}</Text>}
          </Pressable>
        </View>
        {banner && (
          <View style={banner.kind === 'error' ? styles.errorBox : styles.infoBox}>
            <Text style={banner.kind === 'error' ? styles.errorText : styles.infoText}>{banner.text}</Text>
          </View>
        )}
        {counts.total > 0 && (
          <View style={styles.progressRow}>
            <Stat label={t('driver.manifest.pending')} value={counts.pending} />
            <Stat label={t('driver.manifest.delivered')} value={counts.delivered} good />
            <Stat label={t('driver.manifest.failed')} value={counts.failed} bad={counts.failed > 0} />
            {counts.paid > 0 && <Stat label={t('driver.payment.paid')} value={counts.paid} good />}
          </View>
        )}
        {stops.length === 0 && (
          <View style={styles.emptyBox}>
            <Text style={styles.emptyText}>{plan ? t('driver.manifest.no_stops') : t('driver.manifest.empty')}</Text>
            <Text style={styles.muted}>{t('driver.manifest.empty_hint')}</Text>
          </View>
        )}
        {stops.map((s) => (
          <Pressable key={s.id} onPress={() => setSheetStop(s)}
            style={({ pressed }) => [styles.stopCard, pressed && { opacity: 0.7 }]}>
            <View style={[styles.seq, seqColor(s.status)]}><Text style={styles.seqText}>{s.seq}</Text></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.stopName}>{s.distributor_name}</Text>
              <Text style={styles.muted}>{t('time.eta')} {new Date(s.planned_eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</Text>
              {s.payment_status !== 'NONE' && (
                <Text style={[styles.payBadge, s.payment_status === 'CONFIRMED' ? styles.payConfirmed : styles.payPending]}>
                  {s.payment_status === 'CONFIRMED'
                    ? `✓ ${s.payment_method === 'TELEBIRR' ? 'Telebirr' : 'Cash'} ${s.payment_amount_etb ?? 0}`
                    : `⏳ ${t('driver.payment.pending')}`}
                </Text>
              )}
            </View>
            <Text style={[styles.statusPill, statusColor(s.status)]}>{t(`driver.manifest.status.${s.status.toLowerCase()}`)}</Text>
          </Pressable>
        ))}
      </ScrollView>
      <StopActionSheet stop={sheetStop} onChoose={onChoose} onCancel={() => setSheetStop(null)} />
      <EpodScreen key={epodStop?.id ?? 'none'} stop={epodStop} outcome={epodOutcome}
        onClose={() => { setEpodStop(null); setEpodOutcome(null); }} onSaved={onEpodSaved} />
    </>
  );
}

function Stat({ label, value, good, bad }: { label: string; value: number; good?: boolean; bad?: boolean }) {
  const color = bad ? '#b91c1c' : good ? '#166534' : '#1a1a1a';
  return (
    <View style={styles.progressStat}>
      <Text style={[styles.progressValue, { color }]}>{value}</Text>
      <Text style={styles.progressLabel}>{label}</Text>
    </View>
  );
}
function seqColor(s: string) {
  if (s === 'DELIVERED') return { backgroundColor: '#166534' };
  if (s === 'FAILED') return { backgroundColor: '#b91c1c' };
  if (s === 'ARRIVED') return { backgroundColor: '#b45309' };
  return { backgroundColor: '#6b6b6b' };
}
function statusColor(s: string) {
  if (s === 'DELIVERED') return { color: '#166534', backgroundColor: '#f0fdf4' };
  if (s === 'FAILED') return { color: '#b91c1c', backgroundColor: '#fef2f2' };
  if (s === 'ARRIVED') return { color: '#b45309', backgroundColor: '#fffbeb' };
  return { color: '#6b6b6b', backgroundColor: '#f3f3f3' };
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  content: { padding: 16, paddingBottom: 96 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  title: { fontSize: 22, fontWeight: '700', color: '#1a1a1a' },
  subtitle: { fontSize: 13, color: '#6b6b6b', marginTop: 2 },
  syncBtn: { backgroundColor: '#0f766e', paddingHorizontal: 14, paddingVertical: 10, borderRadius: 10, minWidth: 64, alignItems: 'center' },
  syncBtnText: { color: '#fff', fontWeight: '600', fontSize: 14 },
  infoBox: { backgroundColor: '#ecfdf5', borderColor: '#6ee7b7', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  infoText: { color: '#065f46', fontSize: 13 },
  errorBox: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  errorText: { color: '#b91c1c', fontSize: 13 },
  progressRow: { flexDirection: 'row', gap: 8, marginBottom: 12, backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12 },
  progressStat: { flex: 1, alignItems: 'center' },
  progressValue: { fontSize: 20, fontWeight: '700' },
  progressLabel: { fontSize: 10, color: '#6b6b6b', marginTop: 2 },
  emptyBox: { paddingVertical: 40, alignItems: 'center' },
  emptyText: { fontSize: 15, color: '#1a1a1a', fontWeight: '500' },
  muted: { fontSize: 12, color: '#6b6b6b', marginTop: 2 },
  stopCard: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12, marginBottom: 8 },
  seq: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
  seqText: { color: '#fff', fontWeight: '700', fontSize: 14 },
  stopName: { fontSize: 15, fontWeight: '500', color: '#1a1a1a' },
  statusPill: { fontSize: 11, fontWeight: '500', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 999, overflow: 'hidden' },
  payBadge: { fontSize: 11, fontWeight: '500', paddingHorizontal: 6, paddingVertical: 2, borderRadius: 6, marginTop: 4, overflow: 'hidden', alignSelf: 'flex-start' },
  payConfirmed: { backgroundColor: '#f0fdf4', color: '#166534' },
  payPending: { backgroundColor: '#fffbeb', color: '#b45309' },
});
EOF

W apps/driver-mobile/src/screens/EpodScreen.tsx <<'EOF'
import { useState, useRef, useCallback } from 'react';
import { Modal, View, Text, ScrollView, Pressable, TextInput, ActivityIndicator, StyleSheet, Alert, KeyboardAvoidingView, Platform } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import SignatureCanvas from 'react-native-signature-canvas';
import { useI18n } from '@tera/i18n';
import type { LocalStop, ProofOutcome, PaymentMethod } from '@tera/offline-sync';
import { recordProofOfDelivery } from '../offline/local';

interface Props { stop: LocalStop | null; outcome: ProofOutcome | null; onClose: () => void; onSaved: () => void; }

const OUTCOME_TITLE_KEY: Record<ProofOutcome, string> = {
  DELIVERED: 'driver.epod.title.delivered', PARTIAL: 'driver.epod.title.partial',
  NOT_AVAILABLE: 'driver.epod.title.not_available', RETURNED: 'driver.epod.title.returned',
};

export function EpodScreen({ stop, outcome, onClose, onSaved }: Props) {
  const { t } = useI18n();
  const [qty, setQty] = useState<string>('');
  const [reason, setReason] = useState('');
  const [signature, setSignature] = useState<string | null>(null);
  const [photo, setPhoto] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [cameraOpen, setCameraOpen] = useState(false);
  const [perm, requestPerm] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const sigRef = useRef<any>(null);
  const [paymentCollected, setPaymentCollected] = useState(true);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('CASH');
  const [amount, setAmount] = useState('');
  const [telebirrRef, setTelebirrRef] = useState('');

  const isOpen = stop !== null && outcome !== null;
  if (stop && qty === '' && stop.quantity_ordered > 0) setQty(String(stop.quantity_ordered));

  const requiresSignature = outcome === 'DELIVERED' || outcome === 'PARTIAL' || outcome === 'RETURNED';
  const requiresReason = outcome === 'NOT_AVAILABLE' || outcome === 'RETURNED';
  const showPaymentSection = (outcome === 'DELIVERED' || outcome === 'PARTIAL') && paymentCollected;
  const qtyNum = qty.trim() === '' ? null : parseInt(qty.trim(), 10);
  const qtyValid = qtyNum !== null && Number.isFinite(qtyNum) && qtyNum >= 0;
  const partialValid = outcome !== 'PARTIAL' || (qtyNum !== null && stop !== null && qtyNum < stop.quantity_ordered);
  const amountNum = amount.trim() === '' ? null : parseFloat(amount.trim());
  const amountValid = !showPaymentSection || (amountNum !== null && Number.isFinite(amountNum) && amountNum > 0);
  const telebirrRefValid = !showPaymentSection || paymentMethod === 'CASH' || (telebirrRef.trim().length >= 6 && /^[A-Za-z0-9_-]+$/.test(telebirrRef.trim()));
  const canSave = stop !== null && outcome !== null && qtyValid && partialValid && amountValid && telebirrRefValid
    && (!requiresSignature || signature !== null) && (!requiresReason || reason.trim().length > 0) && !saving;

  const capturePhoto = useCallback(async () => {
    if (!perm?.granted) { const r = await requestPerm(); if (!r.granted) { Alert.alert(t('driver.epod.perm_denied')); return; } }
    setCameraOpen(true);
  }, [perm, requestPerm, t]);

  const takePicture = useCallback(async () => {
    if (!cameraRef.current) return;
    try {
      const pic = await cameraRef.current.takePictureAsync({ base64: true, quality: 0.3, skipProcessing: true });
      if (pic?.base64) setPhoto(`data:image/jpeg;base64,${pic.base64}`);
      setCameraOpen(false);
    } catch (e) { Alert.alert(t('common.error'), String(e)); }
  }, [t]);

  const save = useCallback(async () => {
    if (!stop || !outcome || !canSave) return;
    setSaving(true);
    try {
      await recordProofOfDelivery({
        stopId: stop.id, outcome,
        qtyConfirmed: qtyNum ?? 0, qtyOrdered: stop.quantity_ordered,
        reason: requiresReason ? reason.trim() : null,
        signatureBase64: requiresSignature ? signature : null,
        photoBase64: photo,
        payment: showPaymentSection && amountNum !== null ? {
          method: paymentMethod, amountEtb: amountNum,
          telebirrRef: paymentMethod === 'TELEBIRR' ? telebirrRef.trim() : null,
        } : null,
      });
      onSaved();
    } catch (e) { Alert.alert(t('common.error'), e instanceof Error ? e.message : String(e)); }
    finally { setSaving(false); }
  }, [stop, outcome, canSave, qtyNum, reason, requiresReason, requiresSignature, signature, photo, showPaymentSection, amountNum, paymentMethod, telebirrRef, t, onSaved]);

  if (!isOpen) return null;
  return (
    <Modal visible animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView style={styles.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.header}>
          <Pressable onPress={onClose} hitSlop={12} style={styles.headerBtn}><Text style={styles.headerBtnText}>{t('common.cancel')}</Text></Pressable>
          <Text style={styles.headerTitle}>{t(OUTCOME_TITLE_KEY[outcome!])}</Text>
          <View style={styles.headerBtn} />
        </View>
        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <View style={styles.stopBox}>
            <Text style={styles.stopName}>{stop!.distributor_name}</Text>
            <Text style={styles.muted}>{t('driver.epod.ordered')}: {stop!.quantity_ordered}</Text>
          </View>
          <View style={styles.section}>
            <Text style={styles.label}>{t('driver.epod.qty_confirmed')}</Text>
            <TextInput value={qty} onChangeText={setQty} keyboardType="number-pad" placeholder="0" style={styles.input} editable={!saving} />
            {!partialValid && <Text style={styles.hintDanger}>{t('driver.epod.partial_hint', { ordered: stop!.quantity_ordered })}</Text>}
          </View>
          {requiresReason && (
            <View style={styles.section}>
              <Text style={styles.label}>{t('driver.epod.reason')}</Text>
              <TextInput value={reason} onChangeText={setReason} placeholder={t('driver.epod.reason_placeholder')} multiline numberOfLines={3} style={[styles.input, styles.multiline]} editable={!saving} />
            </View>
          )}
          {requiresSignature && (
            <View style={styles.section}>
              <View style={styles.labelRow}>
                <Text style={styles.label}>{t('driver.epod.signature')}</Text>
                {signature && <Pressable onPress={() => { setSignature(null); sigRef.current?.clearSignature?.(); }}><Text style={styles.clearBtn}>{t('driver.epod.clear')}</Text></Pressable>}
              </View>
              {signature ? <View style={styles.signatureBox}><Text style={styles.signedLabel}>{t('driver.epod.signed')}</Text></View>
                : <View style={styles.signatureBox}>
                    <SignatureCanvas ref={sigRef} onOK={(s: string) => setSignature(s || null)} onEmpty={() => setSignature(null)}
                      descriptionText="" clearText={t('driver.epod.clear')} confirmText={t('driver.epod.confirm')}
                      webStyle=".m-signature-pad { box-shadow: none; border: none; }" />
                  </View>}
            </View>
          )}
          {(outcome === 'DELIVERED' || outcome === 'PARTIAL') && (
            <View style={styles.section}>
              <View style={styles.labelRow}><Text style={styles.label}>{t('driver.payment.section')}</Text></View>
              <View style={styles.toggleRow}>
                <Pressable onPress={() => setPaymentCollected(true)} style={[styles.toggleBtn, paymentCollected && styles.toggleBtnActive]}>
                  <Text style={[styles.toggleText, paymentCollected && styles.toggleTextActive]}>{t('driver.payment.collected_yes')}</Text>
                </Pressable>
                <Pressable onPress={() => setPaymentCollected(false)} style={[styles.toggleBtn, !paymentCollected && styles.toggleBtnActive]}>
                  <Text style={[styles.toggleText, !paymentCollected && styles.toggleTextActive]}>{t('driver.payment.collected_no')}</Text>
                </Pressable>
              </View>
              {paymentCollected ? (
                <>
                  <View style={styles.methodRow}>
                    <Pressable onPress={() => setPaymentMethod('CASH')} style={[styles.methodBtn, paymentMethod === 'CASH' && styles.methodBtnActive]}>
                      <Text style={[styles.methodText, paymentMethod === 'CASH' && styles.methodTextActive]}>{t('driver.payment.method_cash')}</Text>
                    </Pressable>
                    <Pressable onPress={() => setPaymentMethod('TELEBIRR')} style={[styles.methodBtn, paymentMethod === 'TELEBIRR' && styles.methodBtnActive]}>
                      <Text style={[styles.methodText, paymentMethod === 'TELEBIRR' && styles.methodTextActive]}>{t('driver.payment.method_telebirr')}</Text>
                    </Pressable>
                  </View>
                  <Text style={styles.label}>{t('driver.payment.amount')}</Text>
                  <TextInput value={amount} onChangeText={setAmount} keyboardType="decimal-pad" placeholder="0" style={styles.input} editable={!saving} />
                  {paymentMethod === 'TELEBIRR' && (
                    <>
                      <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.payment.ref')}</Text>
                      <TextInput value={telebirrRef} onChangeText={setTelebirrRef} placeholder={t('driver.payment.ref_placeholder')} autoCapitalize="characters" autoCorrect={false} style={styles.input} editable={!saving} />
                      {telebirrRef.length > 0 && !telebirrRefValid && <Text style={styles.hintDanger}>{t('driver.payment.ref_invalid')}</Text>}
                    </>
                  )}
                </>
              ) : <Text style={styles.hint}>{t('driver.payment.no_payment_hint')}</Text>}
            </View>
          )}
          <View style={styles.section}>
            <View style={styles.labelRow}>
              <Text style={styles.label}>{t('driver.epod.photo')}</Text>
              {photo && <Pressable onPress={() => setPhoto(null)}><Text style={styles.clearBtn}>{t('driver.epod.clear')}</Text></Pressable>}
            </View>
            {photo ? <View style={styles.photoBox}><Text style={styles.signedLabel}>{t('driver.epod.photo_captured')}</Text></View>
              : cameraOpen ? (
                <View style={styles.cameraContainer}>
                  <CameraView ref={cameraRef} style={styles.camera} facing="back" />
                  <View style={styles.cameraActions}>
                    <Pressable onPress={() => setCameraOpen(false)} style={styles.camBtnSecondary}><Text style={[styles.camBtnText, { color: '#1a1a1a' }]}>{t('common.cancel')}</Text></Pressable>
                    <Pressable onPress={takePicture} style={styles.camBtnPrimary}><Text style={styles.camBtnText}>{t('driver.epod.capture')}</Text></Pressable>
                  </View>
                </View>
              ) : <Pressable onPress={capturePhoto} style={styles.photoBtn}><Text style={styles.photoBtnText}>{t('driver.epod.open_camera')}</Text></Pressable>}
          </View>
        </ScrollView>
        <View style={styles.footer}>
          <Pressable onPress={save} disabled={!canSave}
            style={({ pressed }) => [styles.saveBtn, !canSave && styles.saveBtnDisabled, pressed && { opacity: 0.85 }]}>
            {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.saveBtnText}>{t('driver.epod.save')}</Text>}
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: '#e5e5e0', backgroundColor: '#fff' },
  headerBtn: { minWidth: 60 },
  headerBtnText: { color: '#0f766e', fontSize: 15, fontWeight: '500' },
  headerTitle: { fontSize: 16, fontWeight: '600', color: '#1a1a1a' },
  content: { padding: 16, paddingBottom: 100 },
  stopBox: { backgroundColor: '#fff', borderRadius: 10, padding: 12, marginBottom: 16, borderWidth: 1, borderColor: '#e5e5e0' },
  stopName: { fontSize: 17, fontWeight: '600', color: '#1a1a1a' },
  muted: { fontSize: 13, color: '#6b6b6b', marginTop: 4 },
  section: { marginBottom: 20 },
  label: { fontSize: 13, color: '#1a1a1a', fontWeight: '600', marginBottom: 6 },
  labelRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 },
  clearBtn: { fontSize: 13, color: '#b91c1c', fontWeight: '500' },
  input: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 12, fontSize: 16, color: '#1a1a1a' },
  multiline: { minHeight: 72, textAlignVertical: 'top' },
  hintDanger: { fontSize: 12, color: '#b91c1c', marginTop: 4 },
  hint: { fontSize: 12, color: '#6b6b6b', marginTop: 4 },
  signatureBox: { height: 200, backgroundColor: '#fff', borderRadius: 10, borderWidth: 1, borderColor: '#e5e5e0', overflow: 'hidden', alignItems: 'center', justifyContent: 'center' },
  signedLabel: { color: '#166534', fontSize: 14, fontWeight: '500' },
  photoBox: { height: 160, backgroundColor: '#fff', borderRadius: 10, borderWidth: 1, borderColor: '#e5e5e0', alignItems: 'center', justifyContent: 'center' },
  cameraContainer: { borderRadius: 10, overflow: 'hidden', backgroundColor: '#000' },
  camera: { height: 260, width: '100%' },
  cameraActions: { flexDirection: 'row', backgroundColor: '#fff' },
  camBtnPrimary: { flex: 1, paddingVertical: 14, alignItems: 'center', backgroundColor: '#0f766e' },
  camBtnSecondary: { flex: 1, paddingVertical: 14, alignItems: 'center', backgroundColor: '#fff' },
  camBtnText: { color: '#fff', fontWeight: '600', fontSize: 15 },
  photoBtn: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#0f766e', borderRadius: 10, paddingVertical: 14, alignItems: 'center' },
  photoBtnText: { color: '#0f766e', fontSize: 15, fontWeight: '600' },
  toggleRow: { flexDirection: 'row', gap: 8, marginBottom: 12 },
  toggleBtn: { flex: 1, paddingVertical: 10, borderRadius: 8, alignItems: 'center', borderWidth: 1, borderColor: '#e5e5e0', backgroundColor: '#fff' },
  toggleBtnActive: { borderColor: '#0f766e', backgroundColor: '#ecfdf5' },
  toggleText: { fontSize: 14, color: '#6b6b6b', fontWeight: '500' },
  toggleTextActive: { color: '#0f766e', fontWeight: '600' },
  methodRow: { flexDirection: 'row', gap: 8, marginBottom: 12 },
  methodBtn: { flex: 1, paddingVertical: 12, borderRadius: 8, alignItems: 'center', borderWidth: 1, borderColor: '#e5e5e0', backgroundColor: '#fff' },
  methodBtnActive: { borderColor: '#0f766e', backgroundColor: '#ecfdf5' },
  methodText: { fontSize: 14, color: '#6b6b6b', fontWeight: '500' },
  methodTextActive: { color: '#0f766e', fontWeight: '600' },
  footer: { position: 'absolute', bottom: 0, left: 0, right: 0, padding: 16, paddingBottom: 24, backgroundColor: '#fafaf7', borderTopWidth: 1, borderTopColor: '#e5e5e0' },
  saveBtn: { backgroundColor: '#0f766e', borderRadius: 10, paddingVertical: 16, alignItems: 'center' },
  saveBtnDisabled: { backgroundColor: '#a3a3a3' },
  saveBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
EOF

W apps/driver-mobile/src/screens/FuelLogScreen.tsx <<'EOF'
import { useCallback, useEffect, useMemo, useState } from 'react';
import { View, Text, ScrollView, Pressable, TextInput, ActivityIndicator, StyleSheet, Alert, RefreshControl } from 'react-native';
import { useI18n } from '@tera/i18n';
import type { FuelContext, LocalFuelFill } from '@tera/offline-sync';
import { computeFuelHint } from '@tera/offline-sync';
import { readFuelContext, recordFuelLog } from '../offline/local';
import { getEngine } from '../offline/engine';
import Constants from 'expo-constants';

const DRIVER_ID = (Constants.expoConfig?.extra as any)?.driverId ?? 'D-201';
const EMPTY_CTX: FuelContext = { vehicle: null, last_fill: null, recent_fills: [] };

export function FuelLogScreen() {
  const { t } = useI18n();
  const [ctx, setCtx] = useState<FuelContext>(EMPTY_CTX);
  const [refreshing, setRefreshing] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [pending, setPending] = useState(0);
  const [banner, setBanner] = useState<{ kind: 'error' | 'info'; text: string } | null>(null);
  const [liters, setLiters] = useState('');
  const [amount, setAmount] = useState('');
  const [odometer, setOdometer] = useState('');
  const [station, setStation] = useState('');

  const refreshAll = useCallback(async () => {
    setCtx(await readFuelContext());
    const engine = await getEngine();
    setPending(await engine.pendingCount());
  }, []);
  useEffect(() => { void refreshAll(); }, [refreshAll]);

  const doSync = useCallback(async (trig = false) => {
    if (trig) setBanner(null);
    setSyncing(true);
    try {
      const engine = await getEngine();
      const r = await engine.sync();
      await refreshAll();
      if (trig) setBanner(r.errors.length > 0 ? { kind: 'error', text: r.errors.join(' · ') } : { kind: 'info', text: `+${r.pulled} ↓ ${r.pushed} ↑` });
    } catch (e) {
      if (trig) setBanner({ kind: 'error', text: e instanceof Error ? e.message : String(e) });
    } finally { setSyncing(false); }
  }, [refreshAll]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true); await doSync(true); setRefreshing(false);
  }, [doSync]);

  const previewHint = useMemo(() => {
    const l = parseFloat(liters); const o = parseFloat(odometer);
    if (!Number.isFinite(l) || l <= 0) return null;
    if (!Number.isFinite(o) || o <= 0) return null;
    return computeFuelHint({ liters: l, odometer_km: o, prev_odometer_km: ctx.last_fill?.odometer_km ?? null, baseline_l_per_100km: ctx.vehicle?.baseline_l_per_100km ?? null });
  }, [liters, odometer, ctx]);

  const litersN = parseFloat(liters); const amountN = parseFloat(amount); const odoN = parseFloat(odometer);
  const canSave = ctx.vehicle !== null && Number.isFinite(litersN) && litersN > 0 && Number.isFinite(amountN) && amountN > 0
    && Number.isFinite(odoN) && odoN > 0 && station.trim().length > 0 && (ctx.last_fill === null || odoN > ctx.last_fill.odometer_km) && !saving;

  const save = useCallback(async () => {
    if (!ctx.vehicle || !canSave) return;
    setSaving(true);
    try {
      const hint = await recordFuelLog({ vehicleId: ctx.vehicle.id, driverId: DRIVER_ID, liters: litersN, amountEtb: amountN, odometerKm: odoN, stationName: station.trim(), stationId: null });
      setLiters(''); setAmount(''); setOdometer(''); setStation('');
      await refreshAll(); void doSync(false);
      if (hint.level === 'high') Alert.alert(t('driver.fuel.variance_high'), t('driver.fuel.variance_high_body'));
      else if (hint.level === 'low') Alert.alert(t('driver.fuel.variance_low'), t('driver.fuel.variance_low_body'));
    } catch (e) { Alert.alert(t('common.error'), e instanceof Error ? e.message : String(e)); }
    finally { setSaving(false); }
  }, [ctx, canSave, litersN, amountN, odoN, station, refreshAll, doSync, t]);

  const { vehicle, last_fill, recent_fills } = ctx;
  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#0f766e" />}
      keyboardShouldPersistTaps="handled">
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>{t('driver.fuel.title')}</Text>
          <Text style={styles.subtitle}>{vehicle ? `${vehicle.plate}${vehicle.baseline_l_per_100km ? ` · ${t('driver.fuel.baseline')}: ${vehicle.baseline_l_per_100km} L/100km` : ''}` : t('driver.fuel.no_vehicle')}</Text>
        </View>
        <Pressable onPress={() => doSync(true)} disabled={syncing}
          style={({ pressed }) => [styles.syncBtn, (pressed || syncing) && { opacity: 0.6 }]}>
          {syncing ? <ActivityIndicator color="#fff" size="small" /> : <Text style={styles.syncBtnText}>{pending > 0 ? `${pending}` : t('driver.manifest.sync')}</Text>}
        </Pressable>
      </View>
      {banner && <View style={banner.kind === 'error' ? styles.errorBox : styles.infoBox}><Text style={banner.kind === 'error' ? styles.errorText : styles.infoText}>{banner.text}</Text></View>}
      {last_fill && (
        <View style={styles.lastFillBox}>
          <Text style={styles.sectionTitle}>{t('driver.fuel.last_fill')}</Text>
          <Text style={styles.muted}>{new Date(last_fill.captured_at).toLocaleString()} · {last_fill.odometer_km.toFixed(0)} km · {last_fill.liters} L</Text>
        </View>
      )}
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>{t('driver.fuel.new_fill')}</Text>
        <Text style={styles.label}>{t('driver.fuel.liters')}</Text>
        <TextInput value={liters} onChangeText={setLiters} keyboardType="decimal-pad" placeholder="0.00" style={styles.input} editable={!saving} />
        <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.fuel.amount')}</Text>
        <TextInput value={amount} onChangeText={setAmount} keyboardType="decimal-pad" placeholder="0.00" style={styles.input} editable={!saving} />
        <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.fuel.odometer')}</Text>
        <TextInput value={odometer} onChangeText={setOdometer} keyboardType="decimal-pad" placeholder={last_fill ? `> ${last_fill.odometer_km.toFixed(0)}` : '0'} style={styles.input} editable={!saving} />
        {last_fill && Number.isFinite(odoN) && odoN <= last_fill.odometer_km && <Text style={styles.hintDanger}>{t('driver.fuel.odometer_too_low')}</Text>}
        <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.fuel.station')}</Text>
        <TextInput value={station} onChangeText={setStation} placeholder={t('driver.fuel.station_placeholder')} style={styles.input} editable={!saving} />
        {previewHint && previewHint.level !== 'unknown' && <VarianceHint hint={previewHint} />}
        <Pressable onPress={save} disabled={!canSave}
          style={({ pressed }) => [styles.saveBtn, !canSave && styles.saveBtnDisabled, pressed && { opacity: 0.85 }]}>
          {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.saveBtnText}>{t('driver.fuel.save')}</Text>}
        </Pressable>
      </View>
      <View style={styles.historyBox}>
        <Text style={styles.sectionTitle}>{t('driver.fuel.recent')}</Text>
        {recent_fills.length === 0 ? <Text style={styles.muted}>{t('driver.fuel.no_fills')}</Text>
          : recent_fills.map((f) => <FillRow key={f.id} fill={f} />)}
      </View>
    </ScrollView>
  );
}

function VarianceHint({ hint }: { hint: { level: string; l_per_100km: number | null; ratio: number | null } }) {
  const { t } = useI18n();
  const tone = hint.level === 'high' ? styles.hintHigh : hint.level === 'low' ? styles.hintLow : styles.hintOk;
  const label = hint.level === 'high' ? t('driver.fuel.variance_high') : hint.level === 'low' ? t('driver.fuel.variance_low') : t('driver.fuel.variance_ok');
  return (
    <View style={[styles.hintBox, tone]}>
      <Text style={[styles.hintBoxTitle, tone]}>≈ {hint.l_per_100km?.toFixed(1)} L/100km — {label}</Text>
    </View>
  );
}
function FillRow({ fill }: { fill: LocalFuelFill }) {
  const { t } = useI18n();
  const flagTone = fill.variance_flag === 'HIGH' ? styles.pillHigh : fill.variance_flag === 'LOW' ? styles.pillLow : fill.variance_flag === 'OK' ? styles.pillOk : styles.pillNeutral;
  const label = fill.variance_flag === 'HIGH' ? t('driver.fuel.variance_high') : fill.variance_flag === 'LOW' ? t('driver.fuel.variance_low') : fill.variance_flag === 'OK' ? t('driver.fuel.variance_ok') : '—';
  return (
    <View style={styles.fillRow}>
      <View style={{ flex: 1 }}>
        <Text style={styles.fillMain}>{fill.liters} L · {fill.amount_etb} ETB</Text>
        <Text style={styles.muted}>{fill.odometer_km.toFixed(0)} km · {fill.station_name}</Text>
      </View>
      <View style={{ alignItems: 'flex-end', gap: 4 }}>
        <Text style={[styles.pill, flagTone]}>{label}</Text>
        {fill.synced_at === null && <Text style={styles.pillPending}>⏳</Text>}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  content: { padding: 16, paddingBottom: 96 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  title: { fontSize: 22, fontWeight: '700', color: '#1a1a1a' },
  subtitle: { fontSize: 12, color: '#6b6b6b', marginTop: 2 },
  syncBtn: { backgroundColor: '#0f766e', paddingHorizontal: 14, paddingVertical: 10, borderRadius: 10, minWidth: 64, alignItems: 'center' },
  syncBtnText: { color: '#fff', fontWeight: '600', fontSize: 14 },
  infoBox: { backgroundColor: '#ecfdf5', borderColor: '#6ee7b7', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  infoText: { color: '#065f46', fontSize: 13 },
  errorBox: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  errorText: { color: '#b91c1c', fontSize: 13 },
  lastFillBox: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12, marginBottom: 12 },
  card: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 14, marginBottom: 16 },
  sectionTitle: { fontSize: 14, fontWeight: '600', color: '#1a1a1a', marginBottom: 8 },
  label: { fontSize: 13, color: '#1a1a1a', fontWeight: '600', marginBottom: 6 },
  input: { backgroundColor: '#fafaf7', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 12, fontSize: 16, color: '#1a1a1a' },
  hintDanger: { fontSize: 12, color: '#b91c1c', marginTop: 4 },
  hintBox: { borderRadius: 8, borderWidth: 1, padding: 10, marginTop: 12 },
  hintBoxTitle: { fontSize: 13, fontWeight: '600' },
  hintOk: { backgroundColor: '#f0fdf4', borderColor: '#86efac', color: '#166534' },
  hintHigh: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', color: '#b91c1c' },
  hintLow: { backgroundColor: '#fffbeb', borderColor: '#fcd34d', color: '#b45309' },
  saveBtn: { backgroundColor: '#0f766e', borderRadius: 10, paddingVertical: 14, alignItems: 'center', marginTop: 16 },
  saveBtnDisabled: { backgroundColor: '#a3a3a3' },
  saveBtnText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  historyBox: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 14 },
  muted: { fontSize: 12, color: '#6b6b6b', marginTop: 2 },
  fillRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 10, borderTopWidth: 1, borderTopColor: '#f3f3f3', gap: 8 },
  fillMain: { fontSize: 14, fontWeight: '500', color: '#1a1a1a' },
  pill: { fontSize: 11, fontWeight: '500', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6, overflow: 'hidden' },
  pillOk: { backgroundColor: '#f0fdf4', color: '#166534' },
  pillHigh: { backgroundColor: '#fef2f2', color: '#b91c1c' },
  pillLow: { backgroundColor: '#fffbeb', color: '#b45309' },
  pillNeutral: { backgroundColor: '#f3f3f3', color: '#6b6b6b' },
  pillPending: { fontSize: 12, color: '#b45309' },
});
EOF

W apps/driver-mobile/App.tsx <<'EOF'
import { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { I18nProvider, useI18n } from '@tera/i18n';
import { ManifestScreen } from './src/screens/ManifestScreen';
import { FuelLogScreen } from './src/screens/FuelLogScreen';
import { SyncDemoScreen } from './src/screens/SyncDemoScreen';
import { getEngine } from './src/offline/engine';

type Tab = 'manifest' | 'fuel' | 'sync';

function Shell() {
  const { t } = useI18n();
  const [ready, setReady] = useState(false);
  const [tab, setTab] = useState<Tab>('manifest');
  useEffect(() => {
    (async () => { try { await getEngine(); } catch (e) { console.error('engine init', e); } finally { setReady(true); } })();
  }, []);
  if (!ready) return null;
  return (
    <View style={styles.root}>
      <View style={styles.screen}>
        {tab === 'manifest' ? <ManifestScreen /> : tab === 'fuel' ? <FuelLogScreen /> : <SyncDemoScreen />}
      </View>
      <View style={styles.tabBar}>
        <TabBtn label={t('driver.tab.manifest')} active={tab === 'manifest'} onPress={() => setTab('manifest')} />
        <TabBtn label={t('driver.tab.fuel')} active={tab === 'fuel'} onPress={() => setTab('fuel')} />
        <TabBtn label={t('driver.tab.sync')} active={tab === 'sync'} onPress={() => setTab('sync')} />
      </View>
    </View>
  );
}
function TabBtn({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={styles.tabBtn}>
      <Text style={[styles.tabText, active && styles.tabTextActive]}>{label}</Text>
      {active && <View style={styles.tabUnderline} />}
    </Pressable>
  );
}
export default function App() {
  return (
    <SafeAreaProvider>
      <I18nProvider initialLocale="am">
        <StatusBar style="dark" />
        <SafeAreaView style={{ flex: 1 }} edges={['top', 'bottom']}><Shell /></SafeAreaView>
      </I18nProvider>
    </SafeAreaProvider>
  );
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  screen: { flex: 1 },
  tabBar: { flexDirection: 'row', borderTopWidth: 1, borderTopColor: '#e5e5e0', backgroundColor: '#fff', paddingTop: 8 },
  tabBtn: { flex: 1, alignItems: 'center', paddingVertical: 8 },
  tabText: { fontSize: 13, color: '#6b6b6b', fontWeight: '500' },
  tabTextActive: { color: '#0f766e', fontWeight: '700' },
  tabUnderline: { width: 24, height: 2, backgroundColor: '#0f766e', borderRadius: 2, marginTop: 4 },
});
EOF

# ═══════════════════════════════════════════════════════════════════
# i18n — driver keys
# ═══════════════════════════════════════════════════════════════════
node <<'NODE'
const fs = require('fs');
const en = JSON.parse(fs.readFileSync('packages/i18n/src/locales/en.json', 'utf8'));
const am = JSON.parse(fs.readFileSync('packages/i18n/src/locales/am.json', 'utf8'));

Object.assign(en, {
  'driver.tab.manifest': 'Manifest', 'driver.tab.fuel': 'Fuel', 'driver.tab.sync': 'Sync',
  'driver.sync.title': 'Offline Sync Engine',
  'driver.sync.subtitle': 'Proof the app works without signal',
  'driver.sync.device': 'Device ID', 'driver.sync.cursor': 'Cursor',
  'driver.sync.last_sync': 'Last sync', 'driver.sync.pending': 'Pending ops',
  'driver.sync.now': 'Sync now', 'driver.sync.manifest': 'Local manifest',
  'driver.sync.empty': 'No local data — press Sync',
  'driver.manifest.title': "Today's Manifest",
  'driver.manifest.not_synced': 'Not synced yet',
  'driver.manifest.no_stops': 'No stops cached', 'driver.manifest.empty': 'No manifest yet',
  'driver.manifest.empty_hint': 'Pull down to sync, or tap the Sync tab.',
  'driver.manifest.sync': 'Sync', 'driver.manifest.sync_ok': 'Synced · {pulled} pulled, {pushed} pushed',
  'driver.manifest.pending': 'Pending', 'driver.manifest.delivered': 'Delivered', 'driver.manifest.failed': 'Failed',
  'driver.manifest.action.arrived': 'Arrived', 'driver.manifest.action.delivered': 'Delivered',
  'driver.manifest.action.partial': 'Partial', 'driver.manifest.action.not_available': 'Not available',
  'driver.manifest.status.pending': 'Pending', 'driver.manifest.status.arrived': 'Arrived',
  'driver.manifest.status.delivered': 'Delivered', 'driver.manifest.status.failed': 'Failed',
  'driver.epod.title.delivered': 'Confirm delivery', 'driver.epod.title.partial': 'Partial delivery',
  'driver.epod.title.not_available': 'Not available', 'driver.epod.title.returned': 'Return',
  'driver.epod.ordered': 'Ordered', 'driver.epod.qty_confirmed': 'Quantity confirmed',
  'driver.epod.partial_hint': 'Must be less than ordered ({ordered})',
  'driver.epod.reason': 'Reason', 'driver.epod.reason_placeholder': 'e.g. customer closed',
  'driver.epod.signature': 'Customer signature', 'driver.epod.photo': 'Photo (optional)',
  'driver.epod.clear': 'Clear', 'driver.epod.confirm': 'Save',
  'driver.epod.signed': '✓ Signed', 'driver.epod.photo_captured': '✓ Photo captured',
  'driver.epod.open_camera': 'Open camera', 'driver.epod.capture': 'Capture',
  'driver.epod.save': 'Save proof', 'driver.epod.perm_denied': 'Camera permission required',
  'driver.payment.section': 'Payment', 'driver.payment.collected_yes': 'Collected', 'driver.payment.collected_no': 'Not collected',
  'driver.payment.method_cash': 'Cash', 'driver.payment.method_telebirr': 'Telebirr',
  'driver.payment.amount': 'Amount (ETB)', 'driver.payment.ref': 'Telebirr reference',
  'driver.payment.ref_placeholder': 'e.g. TB1234567',
  'driver.payment.ref_invalid': 'Reference must be 6–40 alphanumeric characters',
  'driver.payment.no_payment_hint': 'Finance will follow up on payment.',
  'driver.payment.paid': 'Paid', 'driver.payment.pending': 'Payment pending',
  'driver.fuel.title': 'Fuel log', 'driver.fuel.no_vehicle': 'No vehicle synced',
  'driver.fuel.baseline': 'Baseline', 'driver.fuel.last_fill': 'Last fill', 'driver.fuel.new_fill': 'New fill',
  'driver.fuel.liters': 'Liters', 'driver.fuel.amount': 'Amount (ETB)', 'driver.fuel.odometer': 'Odometer (km)',
  'driver.fuel.odometer_too_low': 'Odometer must be greater than the last fill',
  'driver.fuel.station': 'Station', 'driver.fuel.station_placeholder': 'e.g. Bole Total',
  'driver.fuel.save': 'Save fuel log', 'driver.fuel.recent': 'Recent fills', 'driver.fuel.no_fills': 'No fills recorded yet',
  'driver.fuel.variance_ok': 'Within expected range',
  'driver.fuel.variance_high': 'Higher than expected', 'driver.fuel.variance_high_body': 'Fuel use is above this vehicle\'s baseline.',
  'driver.fuel.variance_low': 'Lower than expected', 'driver.fuel.variance_low_body': 'Fuel use is below this vehicle\'s baseline.',
  'driver.fuel.variance_unknown': 'No baseline yet',
});

Object.assign(am, {
  'driver.tab.manifest': 'ዝርዝር', 'driver.tab.fuel': 'ነዳጅ', 'driver.tab.sync': 'ማመሳሰል',
  'driver.sync.title': 'ከመስመር ውጪ ማመሳሰል', 'driver.sync.subtitle': 'ሲግናል ሳይኖር የሚሠራ ማረጋገጫ',
  'driver.sync.device': 'የመሣሪያ መለያ', 'driver.sync.cursor': 'አመልካች',
  'driver.sync.last_sync': 'የመጨረሻ ማመሳሰል', 'driver.sync.pending': 'በመጠባበቅ',
  'driver.sync.now': 'አሁን አመሳስል', 'driver.sync.manifest': 'የአካባቢ ዝርዝር', 'driver.sync.empty': 'ውሂብ የለም',
  'driver.manifest.title': 'የዛሬ ዝርዝር', 'driver.manifest.not_synced': 'አልተመሳሰለም',
  'driver.manifest.no_stops': 'ጣቢያ የለም', 'driver.manifest.empty': 'እስካሁን ዝርዝር የለም',
  'driver.manifest.empty_hint': 'ለማመሳሰል ወደታች ይጎትቱ።',
  'driver.manifest.sync': 'አመሳስል', 'driver.manifest.sync_ok': 'ተመሳስሏል · {pulled} ↓ {pushed} ↑',
  'driver.manifest.pending': 'በመጠባበቅ', 'driver.manifest.delivered': 'የደረሰ', 'driver.manifest.failed': 'ያልተሳካ',
  'driver.manifest.action.arrived': 'ደረስኩ', 'driver.manifest.action.delivered': 'ተላልፏል',
  'driver.manifest.action.partial': 'ከፊል', 'driver.manifest.action.not_available': 'አልተገኘም',
  'driver.manifest.status.pending': 'በመጠባበቅ', 'driver.manifest.status.arrived': 'ደርሷል',
  'driver.manifest.status.delivered': 'ተላልፏል', 'driver.manifest.status.failed': 'ያልተሳካ',
  'driver.epod.title.delivered': 'ማድረስ አረጋግጥ', 'driver.epod.title.partial': 'ከፊል ማድረስ',
  'driver.epod.title.not_available': 'አልተገኘም', 'driver.epod.title.returned': 'ተመላሽ',
  'driver.epod.ordered': 'የታዘዘ', 'driver.epod.qty_confirmed': 'የተረጋገጠ ብዛት',
  'driver.epod.partial_hint': 'ከታዘዘው ({ordered}) በታች መሆን አለበት',
  'driver.epod.reason': 'ምክንያት', 'driver.epod.reason_placeholder': 'ለምሳሌ ደንበኛ ዘግቷል',
  'driver.epod.signature': 'የደንበኛ ፊርማ', 'driver.epod.photo': 'ፎቶ (አማራጭ)',
  'driver.epod.clear': 'አጽዳ', 'driver.epod.confirm': 'አስቀምጥ',
  'driver.epod.signed': '✓ ተፈርሟል', 'driver.epod.photo_captured': '✓ ፎቶ ተይዟል',
  'driver.epod.open_camera': 'ካሜራ ክፈት', 'driver.epod.capture': 'ተኩስ',
  'driver.epod.save': 'ማስረጃ አስቀምጥ', 'driver.epod.perm_denied': 'የካሜራ ፍቃድ ያስፈልጋል',
  'driver.payment.section': 'ክፍያ', 'driver.payment.collected_yes': 'ተቀብያለሁ', 'driver.payment.collected_no': 'አልተቀበልኩም',
  'driver.payment.method_cash': 'ጥሬ ገንዘብ', 'driver.payment.method_telebirr': 'ቴሌብር',
  'driver.payment.amount': 'መጠን (ብር)', 'driver.payment.ref': 'የቴሌብር ማጣቀሻ',
  'driver.payment.ref_placeholder': 'ለምሳሌ TB1234567',
  'driver.payment.ref_invalid': 'ማጣቀሻው 6–40 ፊደላትና ቁጥሮች መሆን አለበት',
  'driver.payment.no_payment_hint': 'ፋይናንስ ክፍያውን ይከታተላል።',
  'driver.payment.paid': 'ተከፍሏል', 'driver.payment.pending': 'ክፍያ በመጠባበቅ',
  'driver.fuel.title': 'የነዳጅ መዝገብ', 'driver.fuel.no_vehicle': 'ተሽከርካሪ አልተመሳሰለም',
  'driver.fuel.baseline': 'መነሻ', 'driver.fuel.last_fill': 'የመጨረሻ ሙሌት', 'driver.fuel.new_fill': 'አዲስ ሙሌት',
  'driver.fuel.liters': 'ሊትር', 'driver.fuel.amount': 'መጠን (ብር)', 'driver.fuel.odometer': 'ኦዶሜትር (ኪሜ)',
  'driver.fuel.odometer_too_low': 'ኦዶሜትር ከመጨረሻ ሙሌት መብለጥ አለበት',
  'driver.fuel.station': 'ጣቢያ', 'driver.fuel.station_placeholder': 'ለምሳሌ ቦሌ ቶታል',
  'driver.fuel.save': 'የነዳጅ መዝገብ አስቀምጥ', 'driver.fuel.recent': 'የቅርብ ሙሌቶች', 'driver.fuel.no_fills': 'ሙሌት የለም',
  'driver.fuel.variance_ok': 'በተጠበቀው ክልል',
  'driver.fuel.variance_high': 'ከተጠበቀው በላይ', 'driver.fuel.variance_high_body': 'ከተሽከርካሪው መነሻ በላይ።',
  'driver.fuel.variance_low': 'ከተጠበቀው በታች', 'driver.fuel.variance_low_body': 'ከተሽከርካሪው መነሻ በታች።',
  'driver.fuel.variance_unknown': 'መነሻ የለም',
});

fs.writeFileSync('packages/i18n/src/locales/en.json', JSON.stringify(en, null, 2) + '\n');
fs.writeFileSync('packages/i18n/src/locales/am.json', JSON.stringify(am, null, 2) + '\n');
console.log('  i18n keys updated (driver)');
NODE

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Part 2a complete — Phase 3: offline engine + driver mobile"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "What's runnable NOW:"
echo "  • @tera/offline-sync package — complete SQLite engine"
echo "    (schema, outbox, sync-engine, conflict rules, driver ops, manifest read, fuel)"
echo "  • Driver mobile app — 5 screens (Manifest, Fuel, Sync + 2 modals)"
echo "  • Backend route-builder now correctly propagates totalQuantity → RouteStop"
echo ""
echo "Driver mobile requires Expo + device/emulator:"
echo "  pnpm install"
echo "  pnpm --filter @tera/api dev          # terminal 1"
echo "  pnpm --filter driver-mobile start    # terminal 2 — Expo dev tools"
echo ""
echo "  Android emulator: API URL is http://10.0.2.2:8000 (already in app.json)"
echo "  iOS simulator:    change extra.apiUrl to http://localhost:8000"
echo ""
echo "What you can do in the driver app:"
echo "  1. Opens on Manifest tab → pulls D-201's route (5 stops, V-101)"
echo "  2. Tap stop → action sheet (Arrived / Delivered / Partial / Not available)"
echo "  3. Delivered → e-POD screen: qty + signature + optional photo + payment (Cash/Telebirr)"
echo "  4. Save → stop turns green, payment pending badge, sync queue increments"
echo "  5. Fuel tab → shows vehicle baseline, last fill, new fill form with live variance hint"
echo "  6. Sync tab → debug view (client ID, cursor, pending ops, last sync)"
echo "  7. Airplane mode → everything works, ops queue locally"
echo "  8. Reconnect → Sync button pushes queue, pulls server changes"
echo ""
echo "📌 Build progress:"
echo "  ✓ Part 1a — Phase 0: Foundation"
echo "  ✓ Part 1b — Phases 1-2: Backend"
echo "  ✓ Part 1c — Phase 2 FE: Dispatcher app"
echo "  ✓ Part 2a — Phase 3: Offline sync + Driver app ← YOU ARE HERE"
echo ""
echo "📌 Next: Part 2b (Phases 4-5)"
echo "  • Warehouse console (dock queue + pick stage)"
echo "  • Admin console (masterdata 4 tabs + constraints + bulk import)"
echo ""
echo "  After Part 2b, the full operation loop is demoable:"
echo "  Distributor → Dispatcher → Warehouse → Driver → Finance → Exec"
echo ""
echo "Reply 'yes' for Part 2b."
echo "════════════════════════════════════════════════════════════════"


# ═══════════════════════════════════════════════════════════════════
# PHASE 4 — BACKEND: DISPATCH MODULE (missing from Part 1b)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 4 backend — dispatch module"

W services/api/src/modules/dispatch/repository.ts <<'EOF'
import { db } from '@tera/db';

export function findDocksWithTodaySlots(date: Date) {
  return db().dispatchDock.findMany({
    where: { active: true }, orderBy: { name: 'asc' },
    include: { slots: { where: { date }, orderBy: { startAt: 'asc' } } },
  });
}
export function findPlannedRoutes(date: Date) {
  return db().routePlan.findMany({
    where: { date, status: 'PLANNED' },
    include: { stops: { select: { id: true, pickedAt: true } } },
    orderBy: { vehicleId: 'asc' },
  });
}
export function findRoutePlanById(id: string) {
  return db().routePlan.findUnique({
    where: { id }, include: { stops: { select: { id: true, pickedAt: true } } },
  });
}
export function findSlotForRoute(routeId: string) {
  return db().dispatchDockSlot.findUnique({ where: { routePlanId: routeId } });
}
export function findAvailableSlots(date: Date) {
  return db().dispatchDockSlot.findMany({ where: { date, status: 'AVAILABLE' }, orderBy: { startAt: 'asc' } });
}
export function findSlotById(id: string) { return db().dispatchDockSlot.findUnique({ where: { id } }); }
export async function allocateSlot(slotId: string, routePlanId: string) {
  return db().dispatchDockSlot.update({ where: { id: slotId }, data: { status: 'ALLOCATED', routePlanId } });
}
export async function confirmSlot(slotId: string, confirmedBy: string) {
  return db().dispatchDockSlot.update({ where: { id: slotId }, data: { status: 'CONFIRMED', confirmedAt: new Date(), confirmedBy } });
}
export async function dispatchRoute(routeId: string, slotId: string) {
  return db().$transaction(async (tx) => {
    await tx.routePlan.update({ where: { id: routeId }, data: { status: 'DISPATCHED' } });
    await tx.dispatchDockSlot.update({ where: { id: slotId }, data: { status: 'COMPLETED' } });
  });
}
export function findAllRoutesForDate(date: Date) {
  return db().routePlan.findMany({
    where: { date }, include: { stops: { select: { id: true, pickedAt: true } } },
    orderBy: { vehicleId: 'asc' },
  });
}
export function findAllSlotsForDate(date: Date) {
  return db().dispatchDockSlot.findMany({ where: { date }, orderBy: { startAt: 'asc' } });
}
EOF

W services/api/src/modules/dispatch/service.ts <<'EOF'
import type { BoardResponse, Dock, DockSlot, RouteSummary, ConfirmSlotResponse, DispatchRouteResponse } from '@tera/contracts';
import * as repo from './repository.js';
import { canDispatch, nextRouteStatus, nextSlotStatus, canConfirmLoading } from './rules.js';
import { writeAudit } from '../../core/audit.js';

function startOfTodayUTC(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

function summarizeRoute(route: {
  id: string; vehicleId: string; driverId: string; status: string;
  plannedKm: any; plannedMin: number; stops: { id: string; pickedAt: Date | null }[];
}): RouteSummary {
  return {
    id: route.id, vehicle_id: route.vehicleId, driver_id: route.driverId,
    status: route.status as RouteSummary['status'],
    planned_km: Number(route.plannedKm), planned_min: route.plannedMin,
    stop_count: route.stops.length,
    picked_count: route.stops.filter((s) => s.pickedAt !== null).length,
  };
}

export async function getBoard(): Promise<BoardResponse> {
  const date = startOfTodayUTC();
  const [docks, allRoutes, allSlots] = await Promise.all([
    repo.findDocksWithTodaySlots(date),
    repo.findAllRoutesForDate(date),
    repo.findAllSlotsForDate(date),
  ]);
  const routeById = new Map(allRoutes.map((r) => [r.id, r]));
  const dockViews: Dock[] = docks.map((d) => ({
    id: d.id, name: d.name,
    slots: d.slots.map((s): DockSlot => {
      const route = s.routePlanId ? routeById.get(s.routePlanId) : null;
      return {
        id: s.id, start_at: s.startAt.toISOString(), end_at: s.endAt.toISOString(),
        status: s.status as DockSlot['status'],
        confirmed_at: s.confirmedAt ? s.confirmedAt.toISOString() : null,
        confirmed_by: s.confirmedBy,
        route: route ? summarizeRoute(route) : null,
      };
    }),
  }));
  const allocatedRouteIds = new Set(allSlots.map((s) => s.routePlanId).filter((x): x is string => !!x));
  return {
    as_of: new Date().toISOString(),
    summary: {
      routes_planned: allRoutes.filter((r) => r.status === 'PLANNED').length,
      routes_dispatched: allRoutes.filter((r) => r.status === 'DISPATCHED').length,
      slots_available: allSlots.filter((s) => s.status === 'AVAILABLE').length,
      slots_allocated: allSlots.filter((s) => s.status === 'ALLOCATED').length,
      slots_confirmed: allSlots.filter((s) => s.status === 'CONFIRMED').length,
      unallocated_routes: allRoutes.filter((r) => r.status === 'PLANNED' && !allocatedRouteIds.has(r.id)).length,
    },
    docks: dockViews,
  };
}

export async function allocateAll(): Promise<{ allocated: number; skipped_unallocatable: number }> {
  const date = startOfTodayUTC();
  const [planned, available] = await Promise.all([repo.findPlannedRoutes(date), repo.findAvailableSlots(date)]);
  let allocated = 0; let skipped = 0;
  for (let i = 0; i < planned.length; i++) {
    const slot = available[i];
    if (!slot) { skipped = planned.length - i; break; }
    await repo.allocateSlot(slot.id, planned[i]!.id);
    allocated++;
  }
  return { allocated, skipped_unallocatable: skipped };
}

export async function confirmSlot(slotId: string, actorId: string): Promise<ConfirmSlotResponse> {
  const slot = await repo.findSlotById(slotId);
  if (!slot) { const e = new Error('slot not found') as any; e.statusCode = 404; throw e; }
  if (!slot.routePlanId) { const e = new Error('cannot confirm: no route on this slot') as any; e.statusCode = 400; throw e; }
  const route = await repo.findRoutePlanById(slot.routePlanId);
  if (!route) { const e = new Error('cannot confirm: route not found') as any; e.statusCode = 404; throw e; }
  const pickedCount = route.stops.filter((s) => s.pickedAt !== null).length;
  const gate = canConfirmLoading({ slotStatus: slot.status as any, pickedCount, totalCount: route.stops.length });
  if (!gate.allowed) { const e = new Error(gate.reason!) as any; e.statusCode = 400; throw e; }
  const updated = await repo.confirmSlot(slotId, actorId);
  await writeAudit({ actorId, entity: 'dock_slot', entityId: slotId, action: 'confirmed', reason: `all ${pickedCount} stops picked`, meta: { slotId } });
  return { slot_id: updated.id, status: updated.status as any, confirmed_at: updated.confirmedAt!.toISOString() };
}

export async function dispatchRoute(routeId: string, actorId: string): Promise<DispatchRouteResponse> {
  const route = await repo.findRoutePlanById(routeId);
  if (!route) { const e = new Error('route not found') as any; e.statusCode = 404; throw e; }
  const slot = await repo.findSlotForRoute(routeId);
  const gate = canDispatch({ routeStatus: route.status as any, slotStatus: (slot?.status ?? null) as any });
  if (!gate.allowed) { const e = new Error(`cannot dispatch: ${gate.reason}`) as any; e.statusCode = 400; throw e; }
  await repo.dispatchRoute(routeId, slot!.id);
  await writeAudit({ actorId, entity: 'route', entityId: routeId, action: 'dispatched', reason: `slot ${slot!.id} confirmed`, meta: { slotId: slot!.id } });
  return { route_id: routeId, status: nextRouteStatus(), slot_status: nextSlotStatus() };
}
EOF

W services/api/src/modules/dispatch/schemas.ts <<'EOF'
export {
  BoardResponseSchema, AllocateResponseSchema, ConfirmSlotResponseSchema, DispatchRouteResponseSchema,
  SlotStatusEnum, RouteBoardStatusEnum, DockSchema, DockSlotSchema, RouteSummarySchema,
} from '@tera/contracts';
EOF

W services/api/src/modules/dispatch/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { BoardResponseSchema, AllocateResponseSchema, ConfirmSlotResponseSchema, DispatchRouteResponseSchema } from './schemas.js';
import * as service from './service.js';

export const dispatchRoutes: FastifyPluginAsync = async (app) => {
  app.get('/board', { schema: { response: { 200: BoardResponseSchema as any } } }, async () => service.getBoard());
  app.post('/slots/allocate', { schema: { response: { 200: AllocateResponseSchema as any } } }, async () => service.allocateAll());
  app.post('/slots/:id/confirm', { schema: { response: { 200: ConfirmSlotResponseSchema as any } } },
    async (req: any) => service.confirmSlot(req.params.id, req.user?.sub ?? 'warehouse'));
  app.post('/routes/:id/dispatch', { schema: { response: { 200: DispatchRouteResponseSchema as any } } },
    async (req: any) => service.dispatchRoute(req.params.id, req.user?.sub ?? 'dispatcher'));
};
EOF

W services/api/src/modules/dispatch/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { dispatchRoutes } from './routes.js';
export const dispatchPlugin: FastifyPluginAsync = async (app) => { await app.register(dispatchRoutes); };
export default dispatchPlugin;
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 5 — BACKEND: MASTERDATA MODULE
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 5 backend — masterdata module"

W services/api/src/modules/masterdata/validation.ts <<'EOF'
export function parseNumber(v: string | undefined): number | null {
  if (v === undefined || v.trim() === '') return null;
  const n = Number(v.trim());
  return Number.isFinite(n) ? n : null;
}
export function parseInt2(v: string | undefined): number | null {
  const n = parseNumber(v);
  if (n === null || !Number.isInteger(n)) return null;
  return n;
}
export function validateDistributorShape(row: Record<string, string>): string[] {
  const errs: string[] = [];
  const name = (row.name ?? '').trim();
  const region = (row.region ?? '').trim();
  if (!name) errs.push('name is required');
  else if (name.length > 200) errs.push('name must be <= 200 chars');
  if (!region) errs.push('region is required');
  else if (region.length > 100) errs.push('region must be <= 100 chars');
  return errs;
}
export function validateVehicleShape(row: Record<string, string>): string[] {
  const errs: string[] = [];
  const plate = (row.plate ?? '').trim();
  if (!plate) errs.push('plate is required');
  else if (plate.length > 20) errs.push('plate must be <= 20 chars');
  const capKg = parseNumber(row.capacity_kg);
  if (capKg === null || capKg <= 0) errs.push('capacity_kg must be > 0');
  const capM3 = parseNumber(row.capacity_m3);
  if (capM3 === null || capM3 <= 0) errs.push('capacity_m3 must be > 0');
  const sh = parseInt2(row.shift_start_h);
  if (sh === null || sh < 0 || sh > 23) errs.push('shift_start_h must be 0-23');
  const eh = parseInt2(row.shift_end_h);
  if (eh === null || eh < 0 || eh > 23) errs.push('shift_end_h must be 0-23');
  if (sh !== null && eh !== null && eh <= sh) errs.push('shift_end_h must be > shift_start_h');
  const lat = parseNumber(row.start_lat);
  if (lat === null || lat < -90 || lat > 90) errs.push('start_lat must be -90 to 90');
  const lng = parseNumber(row.start_lng);
  if (lng === null || lng < -180 || lng > 180) errs.push('start_lng must be -180 to 180');
  if (row.baseline_l_per_100km !== undefined && row.baseline_l_per_100km.trim() !== '') {
    const b = parseNumber(row.baseline_l_per_100km);
    if (b === null || b <= 0) errs.push('baseline_l_per_100km must be > 0 or empty');
  }
  return errs;
}
export function validateSkuShape(row: Record<string, string>): string[] {
  const errs: string[] = [];
  const code = (row.code ?? '').trim();
  if (!code) errs.push('code is required');
  else if (code.length > 40) errs.push('code must be <= 40 chars');
  const name = (row.name ?? '').trim();
  if (!name) errs.push('name is required');
  else if (name.length > 200) errs.push('name must be <= 200 chars');
  const unit = (row.unit ?? '').trim();
  if (!unit) errs.push('unit is required');
  const w = parseNumber(row.weight_kg);
  if (w === null || w <= 0) errs.push('weight_kg must be > 0');
  const v = parseNumber(row.volume_m3);
  if (v === null || v <= 0) errs.push('volume_m3 must be > 0');
  for (const f of ['reorder_point', 'safety_stock', 'lead_time_days'] as const) {
    const x = row[f];
    if (x !== undefined && x.trim() !== '') {
      const n = parseInt2(x);
      if (n === null || n < 0) errs.push(`${f} must be >= 0 or empty`);
    }
  }
  return errs;
}
EOF

W services/api/src/modules/masterdata/repository.ts <<'EOF'
import { db } from '@tera/db';

export function findDistributors() { return db().distributor.findMany({ orderBy: [{ active: 'desc' }, { name: 'asc' }] }); }
export function createDistributor(d: { name: string; region: string }) { return db().distributor.create({ data: d }); }
export function findDistributorById(id: string) { return db().distributor.findUnique({ where: { id } }); }
export function updateDistributorActive(id: string, active: boolean) { return db().distributor.update({ where: { id }, data: { active } }); }
export function findDistributorNames() { return db().distributor.findMany({ select: { name: true } }); }

export function findVehicles() { return db().vehicle.findMany({ orderBy: [{ active: 'desc' }, { plate: 'asc' }] }); }
export function createVehicle(d: any) { return db().vehicle.create({ data: d }); }
export function findVehicleById(id: string) { return db().vehicle.findUnique({ where: { id } }); }
export function updateVehicleActive(id: string, active: boolean) { return db().vehicle.update({ where: { id }, data: { active } }); }
export function findVehiclePlates() { return db().vehicle.findMany({ select: { plate: true } }); }

export function findSkus() { return db().sku.findMany({ orderBy: [{ active: 'desc' }, { code: 'asc' }] }); }
export function createSku(d: any) { return db().sku.create({ data: d }); }
export function findSkuById(id: string) { return db().sku.findUnique({ where: { id } }); }
export function updateSkuActive(id: string, active: boolean) { return db().sku.update({ where: { id }, data: { active } }); }
export function findSkuCodes() { return db().sku.findMany({ select: { code: true } }); }
EOF

W services/api/src/modules/masterdata/service.ts <<'EOF'
import type {
  Distributor, Vehicle, Sku, CreateDistributor, CreateVehicle, CreateSku,
  MasterdataEntityType, ImportRowResult, ValidateImportResponse, CommitImportResponse,
} from '@tera/contracts';
import * as repo from './repository.js';
import { validateDistributorShape, validateVehicleShape, validateSkuShape, parseNumber, parseInt2 } from './validation.js';

export async function listDistributors(): Promise<{ distributors: Distributor[] }> {
  const rows = await repo.findDistributors();
  return { distributors: rows.map((r) => ({ id: r.id, name: r.name, region: r.region, active: r.active, created_at: r.createdAt.toISOString(), updated_at: r.updatedAt.toISOString() })) };
}
export async function createDistributor(input: CreateDistributor): Promise<Distributor> {
  const names = await repo.findDistributorNames();
  if (names.some((n) => n.name.toLowerCase() === input.name.toLowerCase())) {
    const e = new Error(`distributor "${input.name}" already exists`) as any; e.statusCode = 409; throw e;
  }
  const row = await repo.createDistributor({ name: input.name, region: input.region });
  return { id: row.id, name: row.name, region: row.region, active: row.active, created_at: row.createdAt.toISOString(), updated_at: row.updatedAt.toISOString() };
}
export async function toggleDistributorActive(id: string, active: boolean): Promise<Distributor> {
  const row = await repo.findDistributorById(id);
  if (!row) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const u = await repo.updateDistributorActive(id, active);
  return { id: u.id, name: u.name, region: u.region, active: u.active, created_at: u.createdAt.toISOString(), updated_at: u.updatedAt.toISOString() };
}

export async function listVehicles(): Promise<{ vehicles: Vehicle[] }> {
  const rows = await repo.findVehicles();
  return { vehicles: rows.map((v) => ({
    id: v.id, plate: v.plate, capacity_kg: Number(v.capacityKg), capacity_m3: Number(v.capacityM3),
    shift_start_h: v.shiftStartH, shift_end_h: v.shiftEndH,
    start_lat: Number(v.startLat), start_lng: Number(v.startLng),
    baseline_l_per_100km: v.baselineLPer100Km ? Number(v.baselineLPer100Km) : null,
    active: v.active, created_at: v.createdAt.toISOString(), updated_at: v.updatedAt.toISOString(),
  })) };
}
export async function createVehicle(input: CreateVehicle): Promise<Vehicle> {
  const plates = await repo.findVehiclePlates();
  if (plates.some((p) => p.plate.toLowerCase() === input.plate.toLowerCase())) {
    const e = new Error(`vehicle "${input.plate}" already exists`) as any; e.statusCode = 409; throw e;
  }
  const row = await repo.createVehicle({
    plate: input.plate.toUpperCase(), capacityKg: input.capacity_kg, capacityM3: input.capacity_m3,
    shiftStartH: input.shift_start_h, shiftEndH: input.shift_end_h,
    startLat: input.start_lat, startLng: input.start_lng,
    baselineLPer100Km: input.baseline_l_per_100km,
  });
  return { id: row.id, plate: row.plate, capacity_kg: Number(row.capacityKg), capacity_m3: Number(row.capacityM3),
    shift_start_h: row.shiftStartH, shift_end_h: row.shiftEndH, start_lat: Number(row.startLat), start_lng: Number(row.startLng),
    baseline_l_per_100km: row.baselineLPer100Km ? Number(row.baselineLPer100Km) : null,
    active: row.active, created_at: row.createdAt.toISOString(), updated_at: row.updatedAt.toISOString() };
}
export async function toggleVehicleActive(id: string, active: boolean): Promise<Vehicle> {
  const row = await repo.findVehicleById(id);
  if (!row) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const u = await repo.updateVehicleActive(id, active);
  return { id: u.id, plate: u.plate, capacity_kg: Number(u.capacityKg), capacity_m3: Number(u.capacityM3),
    shift_start_h: u.shiftStartH, shift_end_h: u.shiftEndH, start_lat: Number(u.startLat), start_lng: Number(u.startLng),
    baseline_l_per_100km: u.baselineLPer100Km ? Number(u.baselineLPer100Km) : null,
    active: u.active, created_at: u.createdAt.toISOString(), updated_at: u.updatedAt.toISOString() };
}

export async function listSkus(): Promise<{ skus: Sku[] }> {
  const rows = await repo.findSkus();
  return { skus: rows.map((s) => ({
    id: s.id, code: s.code, name: s.name, unit: s.unit,
    weight_kg: Number(s.weightKg), volume_m3: Number(s.volumeM3),
    reorder_point: s.reorderPoint, safety_stock: s.safetyStock, lead_time_days: s.leadTimeDays,
    active: s.active, created_at: s.createdAt.toISOString(), updated_at: s.updatedAt.toISOString(),
  })) };
}
export async function createSku(input: CreateSku): Promise<Sku> {
  const codes = await repo.findSkuCodes();
  if (codes.some((c) => c.code.toLowerCase() === input.code.toLowerCase())) {
    const e = new Error(`SKU "${input.code}" already exists`) as any; e.statusCode = 409; throw e;
  }
  const row = await repo.createSku({
    code: input.code.toUpperCase(), name: input.name, unit: input.unit,
    weightKg: input.weight_kg, volumeM3: input.volume_m3,
    reorderPoint: input.reorder_point, safetyStock: input.safety_stock, leadTimeDays: input.lead_time_days,
  });
  return { id: row.id, code: row.code, name: row.name, unit: row.unit,
    weight_kg: Number(row.weightKg), volume_m3: Number(row.volumeM3),
    reorder_point: row.reorderPoint, safety_stock: row.safetyStock, lead_time_days: row.leadTimeDays,
    active: row.active, created_at: row.createdAt.toISOString(), updated_at: row.updatedAt.toISOString() };
}
export async function toggleSkuActive(id: string, active: boolean): Promise<Sku> {
  const row = await repo.findSkuById(id);
  if (!row) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const u = await repo.updateSkuActive(id, active);
  return { id: u.id, code: u.code, name: u.name, unit: u.unit,
    weight_kg: Number(u.weightKg), volume_m3: Number(u.volumeM3),
    reorder_point: u.reorderPoint, safety_stock: u.safetyStock, lead_time_days: u.leadTimeDays,
    active: u.active, created_at: u.createdAt.toISOString(), updated_at: u.updatedAt.toISOString() };
}

export async function validateImport(type: MasterdataEntityType, rows: Record<string, string>[]): Promise<ValidateImportResponse> {
  const existingNames = type === 'distributor' ? new Set((await repo.findDistributorNames()).map((d) => d.name.toLowerCase())) : null;
  const existingPlates = type === 'vehicle' ? new Set((await repo.findVehiclePlates()).map((v) => v.plate.toLowerCase())) : null;
  const existingCodes = type === 'sku' ? new Set((await repo.findSkuCodes()).map((s) => s.code.toLowerCase())) : null;
  const seenInFile = new Set<string>();
  const result: ImportRowResult[] = [];
  let valid = 0; let invalid = 0;
  for (let i = 0; i < rows.length; i++) {
    const row_number = i + 2;
    const data = rows[i]!;
    const errors: string[] = [];
    if (type === 'distributor') {
      errors.push(...validateDistributorShape(data));
      const name = (data.name ?? '').trim();
      if (name) {
        const k = name.toLowerCase();
        if (existingNames!.has(k)) errors.push(`distributor "${name}" already exists`);
        else if (seenInFile.has(k)) errors.push(`duplicate "${name}" in file`);
        else seenInFile.add(k);
      }
    } else if (type === 'vehicle') {
      errors.push(...validateVehicleShape(data));
      const plate = (data.plate ?? '').trim();
      if (plate) {
        const k = plate.toLowerCase();
        if (existingPlates!.has(k)) errors.push(`vehicle "${plate}" already exists`);
        else if (seenInFile.has(k)) errors.push(`duplicate "${plate}" in file`);
        else seenInFile.add(k);
      }
    } else if (type === 'sku') {
      errors.push(...validateSkuShape(data));
      const code = (data.code ?? '').trim();
      if (code) {
        const k = code.toLowerCase();
        if (existingCodes!.has(k)) errors.push(`SKU "${code}" already exists`);
        else if (seenInFile.has(k)) errors.push(`duplicate "${code}" in file`);
        else seenInFile.add(k);
      }
    }
    result.push({ row_number, data, status: errors.length === 0 ? 'valid' : 'invalid', errors });
    if (errors.length === 0) valid++; else invalid++;
  }
  return { type, total_rows: rows.length, valid_rows: valid, invalid_rows: invalid, rows: result };
}

export async function commitImport(type: MasterdataEntityType, rows: Record<string, string>[]): Promise<CommitImportResponse> {
  const validation = await validateImport(type, rows);
  let inserted = 0; let skipped = 0; const errors: Array<{ row_number: number; error: string }> = [];
  for (const row of validation.rows) {
    if (row.status === 'invalid') { skipped++; continue; }
    try {
      if (type === 'distributor') {
        await repo.createDistributor({ name: row.data.name!.trim(), region: row.data.region!.trim() });
      } else if (type === 'vehicle') {
        await repo.createVehicle({
          plate: row.data.plate!.trim().toUpperCase(),
          capacityKg: parseNumber(row.data.capacity_kg)!, capacityM3: parseNumber(row.data.capacity_m3)!,
          shiftStartH: parseInt2(row.data.shift_start_h)!, shiftEndH: parseInt2(row.data.shift_end_h)!,
          startLat: parseNumber(row.data.start_lat)!, startLng: parseNumber(row.data.start_lng)!,
          baselineLPer100Km: row.data.baseline_l_per_100km?.trim() ? parseNumber(row.data.baseline_l_per_100km)! : null,
        });
      } else if (type === 'sku') {
        await repo.createSku({
          code: row.data.code!.trim().toUpperCase(), name: row.data.name!.trim(), unit: row.data.unit!.trim(),
          weightKg: parseNumber(row.data.weight_kg)!, volumeM3: parseNumber(row.data.volume_m3)!,
          reorderPoint: row.data.reorder_point?.trim() ? parseInt2(row.data.reorder_point)! : 0,
          safetyStock: row.data.safety_stock?.trim() ? parseInt2(row.data.safety_stock)! : 0,
          leadTimeDays: row.data.lead_time_days?.trim() ? parseInt2(row.data.lead_time_days)! : 0,
        });
      }
      inserted++;
    } catch (e) { skipped++; errors.push({ row_number: row.row_number, error: (e as Error).message }); }
  }
  return { inserted, skipped, errors };
}
EOF

W services/api/src/modules/masterdata/schemas.ts <<'EOF'
export {
  DistributorSchema, DistributorsResponseSchema, VehicleSchema, VehiclesResponseSchema, SkuSchema, SkusResponseSchema,
  CreateDistributorSchema, CreateVehicleSchema, CreateSkuSchema, ToggleActiveSchema,
  ImportRequestSchema, ValidateImportResponseSchema, CommitImportResponseSchema,
  MasterdataEntityTypeEnum, ImportRowResultSchema,
} from '@tera/contracts';
EOF

W services/api/src/modules/masterdata/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import {
  DistributorsResponseSchema, DistributorSchema, VehiclesResponseSchema, VehicleSchema, SkusResponseSchema, SkuSchema,
  CreateDistributorSchema, CreateVehicleSchema, CreateSkuSchema, ToggleActiveSchema,
  ImportRequestSchema, ValidateImportResponseSchema, CommitImportResponseSchema,
} from './schemas.js';
import * as service from './service.js';

export const masterdataRoutes: FastifyPluginAsync = async (app) => {
  app.get('/distributors', { schema: { response: { 200: DistributorsResponseSchema as any } } }, async () => service.listDistributors());
  app.post('/distributors', { schema: { body: CreateDistributorSchema as any, response: { 200: DistributorSchema as any } } }, async (req: any) => service.createDistributor(req.body));
  app.patch('/distributors/:id', { schema: { body: ToggleActiveSchema as any, response: { 200: DistributorSchema as any } } }, async (req: any) => service.toggleDistributorActive(req.params.id, req.body.active));

  app.get('/vehicles', { schema: { response: { 200: VehiclesResponseSchema as any } } }, async () => service.listVehicles());
  app.post('/vehicles', { schema: { body: CreateVehicleSchema as any, response: { 200: VehicleSchema as any } } }, async (req: any) => service.createVehicle(req.body));
  app.patch('/vehicles/:id', { schema: { body: ToggleActiveSchema as any, response: { 200: VehicleSchema as any } } }, async (req: any) => service.toggleVehicleActive(req.params.id, req.body.active));

  app.get('/skus', { schema: { response: { 200: SkusResponseSchema as any } } }, async () => service.listSkus());
  app.post('/skus', { schema: { body: CreateSkuSchema as any, response: { 200: SkuSchema as any } } }, async (req: any) => service.createSku(req.body));
  app.patch('/skus/:id', { schema: { body: ToggleActiveSchema as any, response: { 200: SkuSchema as any } } }, async (req: any) => service.toggleSkuActive(req.params.id, req.body.active));

  app.post('/import/validate', { schema: { body: ImportRequestSchema as any, response: { 200: ValidateImportResponseSchema as any } } }, async (req: any) => service.validateImport(req.body.type, req.body.rows));
  app.post('/import/commit', { schema: { body: ImportRequestSchema as any, response: { 200: CommitImportResponseSchema as any } } }, async (req: any) => service.commitImport(req.body.type, req.body.rows));
};
EOF

W services/api/src/modules/masterdata/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { masterdataRoutes } from './routes.js';
export const masterdataPlugin: FastifyPluginAsync = async (app) => { await app.register(masterdataRoutes); };
export default masterdataPlugin;
EOF

W services/api/src/modules/masterdata/__tests__/validation.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { validateDistributorShape, validateVehicleShape, validateSkuShape, parseNumber, parseInt2 } from '../validation.js';

describe('parseNumber / parseInt2', () => {
  it('parses decimals', () => { expect(parseNumber('12.5')).toBe(12.5); expect(parseNumber('')).toBeNull(); });
  it('parseInt2 rejects non-integers', () => { expect(parseInt2('5')).toBe(5); expect(parseInt2('5.5')).toBeNull(); });
});

describe('validateDistributorShape', () => {
  it('accepts', () => expect(validateDistributorShape({ name: 'A', region: 'B' })).toEqual([]));
  it('rejects empty name', () => expect(validateDistributorShape({ name: '', region: 'B' })).toContain('name is required'));
});
describe('validateVehicleShape', () => {
  const good = { plate: 'AA', capacity_kg: '1500', capacity_m3: '8', shift_start_h: '7', shift_end_h: '18', start_lat: '9', start_lng: '38', baseline_l_per_100km: '12' };
  it('accepts', () => expect(validateVehicleShape(good)).toEqual([]));
  it('rejects bad shift', () => expect(validateVehicleShape({ ...good, shift_end_h: '6' }).length).toBeGreaterThan(0));
});
describe('validateSkuShape', () => {
  const good = { code: 'X', name: 'Y', unit: 'each', weight_kg: '0.5', volume_m3: '0.001', reorder_point: '10', safety_stock: '5', lead_time_days: '3' };
  it('accepts', () => expect(validateSkuShape(good)).toEqual([]));
  it('rejects zero weight', () => expect(validateSkuShape({ ...good, weight_kg: '0' }).length).toBeGreaterThan(0));
});
EOF

# ═══════════════════════════════════════════════════════════════════
# UPDATE API — register dispatch + masterdata
# ═══════════════════════════════════════════════════════════════════
W services/api/src/app.ts <<'EOF'
import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { errorHandler } from './plugins/errorHandler.js';
import { authPlugin } from './plugins/auth.js';

import credit from './modules/credit/index.js';
import configMod from './modules/config/index.js';
import geo from './modules/geo/index.js';
import routing from './modules/routing/index.js';
import orders from './modules/orders/index.js';
import dispatch from './modules/dispatch/index.js';
import masterdata from './modules/masterdata/index.js';

export async function buildApp() {
  const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
  await app.register(cors, { origin: true });
  await app.register(sensible);
  await app.register(swagger, {
    openapi: {
      info: { title: 'Tera OMS API', version: '0.1.0' },
      components: { securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } } },
    },
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });
  app.setErrorHandler(errorHandler);
  await app.register(authPlugin);

  await app.register(configMod, { prefix: '/config/v1' });
  await app.register(credit,    { prefix: '/credit/v1' });
  await app.register(geo,       { prefix: '/geo/v1' });
  await app.register(routing,   { prefix: '/routing/v1' });
  await app.register(orders,    { prefix: '/orders/v1' });
  await app.register(dispatch,  { prefix: '/dispatch/v1' });
  await app.register(masterdata, { prefix: '/masterdata/v1' });

  app.get('/health', async () => ({ ok: true }));
  return app;
}
EOF

# ═══════════════════════════════════════════════════════════════════
# WAREHOUSE WEB
# ═══════════════════════════════════════════════════════════════════
echo "▸ Warehouse console"

W apps/warehouse-web/package.json <<'EOF'
{
  "name": "warehouse-web",
  "private": true, "version": "0.1.0", "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build", "test": "vitest run", "lint": "tsc --noEmit" },
  "dependencies": {
    "react": "^18.3.0", "react-dom": "^18.3.0", "react-router-dom": "^6.24.0", "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*", "@tera/i18n": "workspace:*", "@tera/contracts": "workspace:*"
  },
  "devDependencies": {
    "vite": "^5.3.0", "@vitejs/plugin-react": "^4.3.0", "typescript": "^5.4.0", "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0", "autoprefixer": "^10.4.0", "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0", "@testing-library/jest-dom": "^6.4.0", "jsdom": "^24.1.0",
    "@types/react": "^18.3.0", "@types/react-dom": "^18.3.0"
  }
}
EOF
W apps/warehouse-web/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "composite": true, "outDir": "dist", "noEmit": true, "types": ["vite/client"] }, "include": ["src"] }
EOF
W apps/warehouse-web/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], server: { port: 5174 } });
EOF
W apps/warehouse-web/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], globals: true, css: false } });
EOF
W apps/warehouse-web/tailwind.config.ts <<'EOF'
import type { Config } from 'tailwindcss';
import preset from '@tera/ui/tailwind-preset';
export default { presets: [preset], content: ['./index.html', './src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'] } satisfies Config;
EOF
W apps/warehouse-web/postcss.config.cjs <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF
W apps/warehouse-web/index.html <<'EOF'
<!doctype html>
<html lang="am"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
<link rel="preconnect" href="https://fonts.googleapis.com" /><link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Ethiopic:wght@400;500;600;700&display=swap" rel="stylesheet" />
<title>ተራ OMS · መጋዘን</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
W apps/warehouse-web/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base { html, body, #root { height: 100%; } body { background-color: theme('colors.bg'); color: theme('colors.text'); font-family: theme('fontFamily.sans'); -webkit-font-smoothing: antialiased; } }
EOF
W apps/warehouse-web/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_BASE_URL: string; readonly VITE_DEFAULT_LOCALE: string; }
interface ImportMeta { readonly env: ImportMetaEnv; }
EOF
W apps/warehouse-web/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
W apps/warehouse-web/src/api/client.ts <<'EOF'
const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); }
}
export async function api<T>({ method = 'GET', path, body, signal }: { method?: string; path: string; body?: unknown; signal?: AbortSignal }): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: body !== undefined ? JSON.stringify(body) : undefined, signal });
  if (!res.ok) { const p = await res.json().catch(() => ({})); throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p); }
  return res.status === 204 ? (undefined as T) : res.json();
}
EOF
W apps/warehouse-web/src/api/queryClient.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 5_000, retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2) } } });
EOF
W apps/warehouse-web/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { AppRouter } from './app/routes';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AppProviders><AppRouter /></AppProviders></React.StrictMode>);
EOF
W apps/warehouse-web/src/app/AppProviders.tsx <<'EOF'
import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';
const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';
export function AppProviders({ children }: { children: ReactNode }) {
  return <I18nProvider initialLocale={locale}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></I18nProvider>;
}
EOF
W apps/warehouse-web/src/app/AppLayout.tsx <<'EOF'
import { useEffect, useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';

function useClock() {
  const [now, setNow] = useState(new Date());
  useEffect(() => { const t = setInterval(() => setNow(new Date()), 30_000); return () => clearInterval(t); }, []);
  return now;
}
export function AppLayout() {
  const { t } = useI18n();
  const now = useClock();
  return (
    <div className="h-full flex flex-col bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3 flex items-center gap-6">
        <div><p className="text-sm text-muted">{t('app.name')}</p><p className="text-xl font-bold">{t('warehouse.title')}</p></div>
        <nav className="flex gap-1 ml-4">
          <TabLink to="/dock" label={t('warehouse.tab.dock')} />
          <TabLink to="/pick" label={t('warehouse.tab.pick')} />
        </nav>
        <div className="ml-auto text-right">
          <p className="text-2xl font-semibold tabular-nums leading-tight">{now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
          <p className="text-xs text-muted">{now.toLocaleDateString([], { weekday: 'long', month: 'short', day: 'numeric' })}</p>
        </div>
      </header>
      <main className="flex-1 min-h-0 overflow-auto p-6"><Outlet /></main>
    </div>
  );
}
function TabLink({ to, label }: { to: string; label: string }) {
  return <NavLink to={to} className={({ isActive }) => `px-4 py-2 rounded-md text-base font-medium transition ${isActive ? 'bg-bg text-text border border-border' : 'text-muted hover:bg-bg'}`}>{label}</NavLink>;
}
EOF
W apps/warehouse-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { DockQueuePage } from '../modules/dock-queue';
import { PickStagePage } from '../modules/pick-stage';

const router = createBrowserRouter([{
  path: '/', element: <AppLayout />,
  children: [
    { index: true, element: <Navigate to="/dock" replace /> },
    { path: 'dock', element: <DockQueuePage /> },
    { path: 'pick', element: <PickStagePage /> },
  ],
}]);
export function AppRouter() { return <RouterProvider router={router} />; }
EOF

# ── dock-queue module
W apps/warehouse-web/src/modules/dock-queue/types.ts <<'EOF'
export type { BoardResponse, Dock, DockSlot, RouteSummary } from '@tera/contracts';
EOF
W apps/warehouse-web/src/modules/dock-queue/api.ts <<'EOF'
import { api } from '../../api/client';
import type { BoardResponse } from './types';
export const dockKeys = { all: ['dock-queue'] as const, board: () => [...dockKeys.all, 'board'] as const };
export function fetchBoard(signal?: AbortSignal) { return api<BoardResponse>({ path: '/dispatch/v1/board', signal }); }
export function confirmLoading(slotId: string) { return api<{ slot_id: string; status: string; confirmed_at: string }>({ method: 'POST', path: `/dispatch/v1/slots/${slotId}/confirm` }); }
EOF
W apps/warehouse-web/src/modules/dock-queue/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { dockKeys, fetchBoard, confirmLoading } from './api';
export function useBoard() { return useQuery({ queryKey: dockKeys.board(), queryFn: ({ signal }) => fetchBoard(signal), refetchInterval: 10_000 }); }
export function useConfirmLoading() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (slotId: string) => confirmLoading(slotId), onSuccess: () => qc.invalidateQueries({ queryKey: dockKeys.all }) });
}
EOF
W apps/warehouse-web/src/modules/dock-queue/components/SlotCard.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { Button, StatusPill } from '@tera/ui';
import type { DockSlot } from '../types';

export function SlotCard({ slot, onConfirm, isConfirming }: { slot: DockSlot; onConfirm: (id: string) => void; isConfirming: boolean }) {
  const { t } = useI18n();
  const time = (iso: string) => new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const route = slot.route;
  const allPicked = route ? route.picked_count === route.stop_count : false;
  const canConfirm = slot.status === 'ALLOCATED' && allPicked;
  if (slot.status !== 'ALLOCATED' && slot.status !== 'CONFIRMED') return null;
  return (
    <div className={`border rounded-lg bg-surface p-4 ${slot.status === 'CONFIRMED' ? 'border-success/40' : 'border-warn/40'}`}>
      <div className="flex items-center justify-between mb-3">
        <span className="text-lg font-semibold tabular-nums">{time(slot.start_at)} – {time(slot.end_at)}</span>
        <StatusPill tone={slot.status === 'ALLOCATED' ? 'warn' : 'success'}>
          {slot.status === 'ALLOCATED' ? t('dispatch.slot.allocated') : t('dispatch.slot.confirmed')}
        </StatusPill>
      </div>
      {route ? (
        <>
          <div className="text-base font-medium mb-1">{route.vehicle_id}</div>
          <div className="text-sm text-muted mb-2">{route.driver_id} · {route.stop_count} {t('dispatch.stops')} · {route.planned_km.toFixed(1)} km</div>
          <div className={`text-sm mb-3 ${allPicked ? 'text-success' : 'text-warn'}`}>{route.picked_count} / {route.stop_count} {t('warehouse.dock.picked_label')}</div>
          {slot.status === 'ALLOCATED' && (
            <Button size="lg" disabled={!canConfirm || isConfirming} loading={isConfirming} onClick={() => onConfirm(slot.id)} className="w-full">
              {allPicked ? t('warehouse.dock.confirm_loading') : t('warehouse.dock.pick_first')}
            </Button>
          )}
          {slot.status === 'CONFIRMED' && <div className="text-sm text-success font-medium">✓ {t('warehouse.dock.awaiting_dispatch')}</div>}
        </>
      ) : <div className="text-sm text-muted">{t('dispatch.empty_slot')}</div>}
    </div>
  );
}
EOF
W apps/warehouse-web/src/modules/dock-queue/DockQueuePage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner } from '@tera/ui';
import { SlotCard } from './components/SlotCard';
import { useBoard, useConfirmLoading } from './hooks';

export function DockQueuePage() {
  const { t } = useI18n();
  const [kiosk, setKiosk] = useState(true);
  const boardQ = useBoard();
  const confirmMut = useConfirmLoading();
  if (boardQ.isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (boardQ.isError || !boardQ.data) {
    return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-base text-danger">
      {t('common.error')}{' '}<button onClick={() => boardQ.refetch()} className="underline">{t('common.retry')}</button>
    </div></div>;
  }
  const actionableDocks = boardQ.data.docks.map((d) => ({ ...d, slots: d.slots.filter((s) => s.status === 'ALLOCATED' || s.status === 'CONFIRMED') })).filter((d) => d.slots.length > 0);
  const hasWork = actionableDocks.length > 0;
  return (
    <div className={kiosk ? 'px-2' : ''}>
      <header className="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className={`font-bold ${kiosk ? 'text-4xl' : 'text-2xl'}`}>{t('warehouse.dock.title')}</h1>
          <p className={`text-muted mt-1 ${kiosk ? 'text-lg' : 'text-base'}`}>{t('warehouse.dock.subtitle')}</p>
        </div>
        <button onClick={() => setKiosk((v) => !v)} className="text-sm text-muted hover:text-text px-3 py-2 rounded-md border border-border bg-surface">
          {kiosk ? t('warehouse.mode.normal') : t('warehouse.mode.kiosk')}
        </button>
      </header>
      {confirmMut.isError && <div className="mb-4 text-base text-danger border border-danger/30 bg-dangerBg rounded-md px-4 py-3">{(confirmMut.error as Error).message}</div>}
      {!hasWork ? <EmptyState title={t('warehouse.dock.empty')} hint={t('warehouse.dock.empty_hint')} />
        : (
          <div className={`grid gap-4 ${kiosk ? 'grid-cols-1 md:grid-cols-3' : 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3'}`}>
            {actionableDocks.map((dock) => (
              <div key={dock.id} className="flex flex-col gap-3">
                <div className={`font-semibold px-1 pb-2 border-b border-border ${kiosk ? 'text-2xl' : 'text-base'}`}>{dock.name}</div>
                {dock.slots.map((slot) => (
                  <SlotCard key={slot.id} slot={slot} onConfirm={(id) => confirmMut.mutate(id)} isConfirming={confirmMut.isPending && confirmMut.variables === slot.id} />
                ))}
              </div>
            ))}
          </div>
        )}
    </div>
  );
}
EOF
W apps/warehouse-web/src/modules/dock-queue/index.ts <<'EOF'
export { DockQueuePage } from './DockQueuePage';
export type { BoardResponse, Dock, DockSlot, RouteSummary } from './types';
EOF
W apps/warehouse-web/src/modules/dock-queue/__tests__/DockQueuePage.test.tsx <<'EOF'
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider } from '@tera/i18n';
import { DockQueuePage } from '../DockQueuePage';

vi.mock('../api', () => ({
  dockKeys: { all: ['dock-queue'], board: () => ['dock-queue', 'board'] },
  fetchBoard: vi.fn().mockResolvedValue({
    as_of: new Date().toISOString(),
    summary: { routes_planned: 1, routes_dispatched: 0, slots_available: 10, slots_allocated: 1, slots_confirmed: 0, unallocated_routes: 0 },
    docks: [{ id: 'dock-a', name: 'Dock A', slots: [{
      id: 'slot-1', start_at: new Date().toISOString(), end_at: new Date(Date.now() + 3600_000).toISOString(),
      status: 'ALLOCATED', confirmed_at: null, confirmed_by: null,
      route: { id: 'r1', vehicle_id: 'V-102', driver_id: 'D-202', status: 'PLANNED', planned_km: 38, planned_min: 220, stop_count: 4, picked_count: 4 },
    }] }],
  }),
  confirmLoading: vi.fn(),
}));

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<I18nProvider initialLocale="en"><QueryClientProvider client={qc}>{ui}</QueryClientProvider></I18nProvider>);
}
describe('DockQueuePage', () => {
  it('renders board with V-102 and Confirm loading button', async () => {
    wrap(<DockQueuePage />);
    expect(await screen.findByText('Dock Queue')).toBeInTheDocument();
    expect(await screen.findByText('V-102')).toBeInTheDocument();
    expect(await screen.findByRole('button', { name: /Confirm loading/ })).toBeInTheDocument();
  });
});
EOF

# ── pick-stage module
W apps/warehouse-web/src/modules/pick-stage/types.ts <<'EOF'
export type { PickListResponse, PickListStop, MarkPickedResponse } from '@tera/contracts';
export interface PickableRoute {
  route_id: string; vehicle_id: string; driver_id: string;
  stop_count: number; picked_count: number;
  slot_id: string; slot_status: 'ALLOCATED' | 'CONFIRMED';
  start_at: string; end_at: string;
}
EOF
W apps/warehouse-web/src/modules/pick-stage/api.ts <<'EOF'
import { api } from '../../api/client';
import type { PickListResponse, MarkPickedResponse } from './types';
export const pickKeys = { all: ['pick-stage'] as const, list: (routeId: string) => [...pickKeys.all, 'list', routeId] as const };
export function fetchPickList(routeId: string, signal?: AbortSignal) { return api<PickListResponse>({ path: `/routing/v1/routes/${routeId}/pick-list`, signal }); }
export function markPicked(routeId: string, stopId: string) {
  return api<MarkPickedResponse>({ method: 'POST', path: `/routing/v1/routes/${routeId}/stops/${stopId}/picked` });
}
export function confirmLoading(slotId: string) { return api<{ slot_id: string; status: string; confirmed_at: string }>({ method: 'POST', path: `/dispatch/v1/slots/${slotId}/confirm` }); }
EOF
W apps/warehouse-web/src/modules/pick-stage/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { pickKeys, fetchPickList, markPicked, confirmLoading } from './api';
import { dockKeys } from '../dock-queue/api';
export function usePickList(routeId: string | null) {
  return useQuery({ queryKey: pickKeys.list(routeId ?? ''), queryFn: ({ signal }) => fetchPickList(routeId!, signal), enabled: routeId !== null });
}
export function useMarkPicked(routeId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (stopId: string) => markPicked(routeId, stopId),
    onSuccess: () => { void qc.invalidateQueries({ queryKey: pickKeys.all }); void qc.invalidateQueries({ queryKey: dockKeys.all }); },
  });
}
export function useConfirmLoading() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (slotId: string) => confirmLoading(slotId),
    onSuccess: () => { void qc.invalidateQueries({ queryKey: pickKeys.all }); void qc.invalidateQueries({ queryKey: dockKeys.all }); },
  });
}
EOF
W apps/warehouse-web/src/modules/pick-stage/components/RouteList.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { EmptyState, StatusPill } from '@tera/ui';
import type { PickableRoute } from '../types';

export function RouteList({ routes, selectedId, onSelect }: { routes: PickableRoute[]; selectedId: string | null; onSelect: (id: string) => void }) {
  const { t } = useI18n();
  if (routes.length === 0) {
    return <div className="border border-border rounded-md bg-surface"><EmptyState title={t('warehouse.pick.no_routes')} hint={t('warehouse.pick.no_routes_hint')} /></div>;
  }
  return (
    <div className="flex flex-col gap-2">
      {routes.map((r) => {
        const picked = r.picked_count === r.stop_count;
        return (
          <button key={r.route_id} onClick={() => onSelect(r.route_id)}
            className={`text-left p-4 rounded-lg border-2 transition ${r.route_id === selectedId ? 'border-primary bg-surface' : 'border-border bg-surface hover:border-primary/40'}`}>
            <div className="flex items-center justify-between mb-1">
              <span className="text-base font-semibold">{r.vehicle_id}</span>
              <StatusPill tone={r.slot_status === 'CONFIRMED' || picked ? 'success' : 'warn'}>
                {r.slot_status === 'CONFIRMED' ? t('dispatch.slot.confirmed') : picked ? t('warehouse.pick.ready') : t('warehouse.pick.pending')}
              </StatusPill>
            </div>
            <div className="text-sm text-muted">{r.driver_id} · {r.picked_count}/{r.stop_count} {t('warehouse.dock.picked_label')}</div>
          </button>
        );
      })}
    </div>
  );
}
EOF
W apps/warehouse-web/src/modules/pick-stage/components/PickListPanel.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import type { PickListResponse, MarkPickedResponse } from '../types';

interface Props {
  pickList: PickListResponse | undefined;
  isLoading: boolean; isError: boolean;
  onRetry: () => void;
  onMarkPicked: (stopId: string) => void;
  onConfirmLoading: (slotId: string) => void;
  isMarking: boolean; isConfirming: boolean;
  lastMarked: MarkPickedResponse | null;
  confirmError: string | null;
}
export function PickListPanel({ pickList, isLoading, isError, onRetry, onMarkPicked, onConfirmLoading, isMarking, isConfirming, lastMarked, confirmError }: Props) {
  const { t } = useI18n();
  if (isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (isError || !pickList) return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-base text-danger">{t('common.error')}{' '}<button onClick={onRetry} className="underline">{t('common.retry')}</button></div></div>;
  const picked = lastMarked?.picked_count ?? pickList.picked_count;
  const total = pickList.total_count;
  const canConfirm = pickList.can_confirm_loading;
  const allPicked = picked === total;
  return (
    <div className="flex flex-col h-full">
      <div className="mb-4 pb-4 border-b border-border">
        <div className="flex items-baseline justify-between">
          <div><h2 className="text-2xl font-bold">{pickList.vehicle_id}</h2><p className="text-sm text-muted mt-1">{pickList.driver_id} · {total} {t('dispatch.stops')}</p></div>
          <div className="text-right"><p className={`text-3xl font-bold tabular-nums ${allPicked ? 'text-success' : 'text-warn'}`}>{picked}/{total}</p><p className="text-xs text-muted">{t('warehouse.dock.picked_label')}</p></div>
        </div>
      </div>
      {confirmError && <div className="mb-4 text-base text-danger border border-danger/30 bg-dangerBg rounded-md px-4 py-3">{confirmError}</div>}
      <div className="flex-1 overflow-y-auto -mx-2 px-2">
        {pickList.stops.map((s) => {
          const isPicked = s.picked_at !== null || (lastMarked && lastMarked.stop_id === s.stop_id);
          return (
            <div key={s.stop_id} className={`flex items-center gap-4 p-4 mb-2 rounded-lg border-2 transition ${isPicked ? 'bg-successBg border-success/40' : 'bg-surface border-border'}`}>
              <div className={`flex items-center justify-center w-12 h-12 rounded-full text-lg font-bold ${isPicked ? 'bg-success text-white' : 'bg-border text-muted'}`}>{isPicked ? '✓' : s.seq}</div>
              <div className="flex-1 min-w-0"><p className="text-lg font-medium truncate">{s.distributor_name}</p><p className="text-sm text-muted">{t('warehouse.pick.qty_ordered')}: <span className="font-medium text-text">{s.quantity_ordered}</span></p></div>
              {!isPicked && pickList.slot_status === 'ALLOCATED' && <Button size="lg" disabled={isMarking} onClick={() => onMarkPicked(s.stop_id)}>{t('warehouse.pick.mark_picked')}</Button>}
              {isPicked && <span className="text-sm text-success font-medium">{t('warehouse.pick.picked')}</span>}
            </div>
          );
        })}
      </div>
      {pickList.slot_status === 'ALLOCATED' && pickList.slot_id && (
        <div className="mt-4 pt-4 border-t border-border">
          <Button size="lg" className="w-full" disabled={!canConfirm || isConfirming} loading={isConfirming} onClick={() => onConfirmLoading(pickList.slot_id!)}>
            {canConfirm ? t('warehouse.pick.confirm_loading') : t('warehouse.pick.cannot_confirm')}
          </Button>
        </div>
      )}
      {pickList.slot_status === 'CONFIRMED' && <div className="mt-4 pt-4 border-t border-border"><div className="text-base text-success font-medium text-center">✓ {t('warehouse.dock.awaiting_dispatch')}</div></div>}
    </div>
  );
}
EOF
W apps/warehouse-web/src/modules/pick-stage/PickStagePage.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { useBoard } from '../dock-queue/hooks';
import { usePickList, useMarkPicked, useConfirmLoading } from './hooks';
import { RouteList } from './components/RouteList';
import { PickListPanel } from './components/PickListPanel';
import type { PickableRoute } from './types';

export function PickStagePage() {
  const { t } = useI18n();
  const [selected, setSelected] = useState<string | null>(null);
  const boardQ = useBoard();
  const pickListQ = usePickList(selected);
  const markMut = useMarkPicked(selected ?? '');
  const confirmMut = useConfirmLoading();
  const routes: PickableRoute[] = useMemo(() => {
    const board = boardQ.data;
    if (!board) return [];
    const out: PickableRoute[] = [];
    for (const dock of board.docks) {
      for (const slot of dock.slots) {
        if (!slot.route) continue;
        if (slot.status !== 'ALLOCATED' && slot.status !== 'CONFIRMED') continue;
        out.push({ route_id: slot.route.id, vehicle_id: slot.route.vehicle_id, driver_id: slot.route.driver_id,
          stop_count: slot.route.stop_count, picked_count: slot.route.picked_count,
          slot_id: slot.id, slot_status: slot.status as any, start_at: slot.start_at, end_at: slot.end_at });
      }
    }
    return out;
  }, [boardQ.data]);
  const effective = selected ?? routes[0]?.route_id ?? null;
  return (
    <div>
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('warehouse.pick.title')}</h1><p className="text-sm text-muted mt-1">{t('warehouse.pick.subtitle')}</p></header>
      <div className="grid grid-cols-1 lg:grid-cols-[380px_1fr] gap-6">
        <aside><p className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('warehouse.pick.routes_today')}</p>
          <RouteList routes={routes} selectedId={effective} onSelect={setSelected} />
        </aside>
        <section className="min-h-[500px]">
          {effective === null ? <div className="flex items-center justify-center h-full text-muted text-base border border-border rounded-md bg-surface p-8">{t('warehouse.pick.select_route')}</div>
            : <PickListPanel pickList={pickListQ.data} isLoading={pickListQ.isLoading} isError={pickListQ.isError}
                onRetry={() => pickListQ.refetch()}
                onMarkPicked={(stopId) => markMut.mutate(stopId)}
                onConfirmLoading={(slotId) => confirmMut.mutate(slotId)}
                isMarking={markMut.isPending} isConfirming={confirmMut.isPending}
                lastMarked={markMut.data ?? null}
                confirmError={confirmMut.isError ? (confirmMut.error as Error).message : null} />}
        </section>
      </div>
    </div>
  );
}
EOF
W apps/warehouse-web/src/modules/pick-stage/index.ts <<'EOF'
export { PickStagePage } from './PickStagePage';
export type { PickListResponse, PickListStop, PickableRoute } from './types';
EOF

# ═══════════════════════════════════════════════════════════════════
# ADMIN WEB
# ═══════════════════════════════════════════════════════════════════
echo "▸ Admin console"

W apps/admin-web/package.json <<'EOF'
{
  "name": "admin-web",
  "private": true, "version": "0.1.0", "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build", "test": "vitest run", "lint": "tsc --noEmit" },
  "dependencies": {
    "react": "^18.3.0", "react-dom": "^18.3.0", "react-router-dom": "^6.24.0", "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*", "@tera/i18n": "workspace:*", "@tera/contracts": "workspace:*",
    "leaflet": "^1.9.4", "react-leaflet": "^4.2.1"
  },
  "devDependencies": {
    "vite": "^5.3.0", "@vitejs/plugin-react": "^4.3.0", "typescript": "^5.4.0", "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0", "autoprefixer": "^10.4.0", "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0", "@testing-library/jest-dom": "^6.4.0", "jsdom": "^24.1.0",
    "@types/react": "^18.3.0", "@types/react-dom": "^18.3.0", "@types/leaflet": "^1.9.12"
  }
}
EOF
W apps/admin-web/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "composite": true, "outDir": "dist", "noEmit": true, "types": ["vite/client"] }, "include": ["src"] }
EOF
W apps/admin-web/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], server: { port: 5175 } });
EOF
W apps/admin-web/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], globals: true, css: false } });
EOF
W apps/admin-web/tailwind.config.ts <<'EOF'
import type { Config } from 'tailwindcss';
import preset from '@tera/ui/tailwind-preset';
export default { presets: [preset], content: ['./index.html', './src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'] } satisfies Config;
EOF
W apps/admin-web/postcss.config.cjs <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF
W apps/admin-web/index.html <<'EOF'
<!doctype html>
<html lang="am"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
<link rel="preconnect" href="https://fonts.googleapis.com" /><link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Ethiopic:wght@400;500;600;700&display=swap" rel="stylesheet" />
<title>ተራ OMS · አስተዳዳሪ</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
W apps/admin-web/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base { html, body, #root { height: 100%; } body { background-color: theme('colors.bg'); color: theme('colors.text'); font-family: theme('fontFamily.sans'); -webkit-font-smoothing: antialiased; } }
EOF
W apps/admin-web/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_BASE_URL: string; readonly VITE_DEFAULT_LOCALE: string; }
interface ImportMeta { readonly env: ImportMetaEnv; }
EOF
W apps/admin-web/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
W apps/admin-web/src/api/client.ts <<'EOF'
const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); }
}
export async function api<T>({ method = 'GET', path, body, signal }: { method?: string; path: string; body?: unknown; signal?: AbortSignal }): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: body !== undefined ? JSON.stringify(body) : undefined, signal });
  if (!res.ok) { const p = await res.json().catch(() => ({})); throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p); }
  return res.status === 204 ? (undefined as T) : res.json();
}
EOF
W apps/admin-web/src/api/queryClient.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 10_000, retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2) } } });
EOF
W apps/admin-web/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { AppRouter } from './app/routes';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AppProviders><AppRouter /></AppProviders></React.StrictMode>);
EOF
W apps/admin-web/src/app/AppProviders.tsx <<'EOF'
import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';
const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';
export function AppProviders({ children }: { children: ReactNode }) {
  return <I18nProvider initialLocale={locale}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></I18nProvider>;
}
EOF
W apps/admin-web/src/app/AppLayout.tsx <<'EOF'
import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';
const NAV = [
  { to: '/masterdata', key: 'admin.nav.masterdata' },
  { to: '/constraints', key: 'admin.nav.constraints' },
];
export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="h-full flex">
      <aside className="w-60 shrink-0 border-r border-border bg-surface flex flex-col">
        <div className="px-5 py-4 border-b border-border"><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('admin.title')}</p></div>
        <nav className="flex-1 p-2">
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to} className={({ isActive }) => `block px-3 py-2 rounded-md text-sm ${isActive ? 'bg-bg text-text font-medium' : 'text-muted hover:bg-bg'}`}>{t(n.key)}</NavLink>
          ))}
        </nav>
      </aside>
      <main className="flex-1 min-w-0 overflow-auto p-6"><Outlet /></main>
    </div>
  );
}
EOF
W apps/admin-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { MasterdataPage } from '../modules/masterdata';
import { ConstraintsPage } from '../modules/constraints';
const router = createBrowserRouter([{
  path: '/', element: <AppLayout />,
  children: [
    { index: true, element: <Navigate to="/masterdata" replace /> },
    { path: 'masterdata', element: <MasterdataPage /> },
    { path: 'constraints', element: <ConstraintsPage /> },
  ],
}]);
export function AppRouter() { return <RouterProvider router={router} />; }
EOF

# ── masterdata module (4 tabs)
W apps/admin-web/src/modules/masterdata/types.ts <<'EOF'
export type { Distributor, Vehicle, Sku, CreateDistributor, CreateVehicle, CreateSku, MasterdataEntityType, ImportRowResult, ValidateImportResponse, CommitImportResponse } from '@tera/contracts';
export type Tab = 'distributors' | 'vehicles' | 'skus' | 'import';
EOF
W apps/admin-web/src/modules/masterdata/api.ts <<'EOF'
import { api } from '../../api/client';
import type { Distributor, Vehicle, Sku, CreateDistributor, CreateVehicle, CreateSku, MasterdataEntityType, ValidateImportResponse, CommitImportResponse } from './types';
export const mdKeys = { all: ['masterdata'] as const, distributors: () => [...mdKeys.all, 'distributors'] as const, vehicles: () => [...mdKeys.all, 'vehicles'] as const, skus: () => [...mdKeys.all, 'skus'] as const };
export function fetchDistributors(signal?: AbortSignal) { return api<{ distributors: Distributor[] }>({ path: '/masterdata/v1/distributors', signal }); }
export function createDistributor(body: CreateDistributor) { return api<Distributor>({ method: 'POST', path: '/masterdata/v1/distributors', body }); }
export function setDistributorActive(id: string, active: boolean) { return api<Distributor>({ method: 'PATCH', path: `/masterdata/v1/distributors/${id}`, body: { active } }); }
export function fetchVehicles(signal?: AbortSignal) { return api<{ vehicles: Vehicle[] }>({ path: '/masterdata/v1/vehicles', signal }); }
export function createVehicle(body: CreateVehicle) { return api<Vehicle>({ method: 'POST', path: '/masterdata/v1/vehicles', body }); }
export function setVehicleActive(id: string, active: boolean) { return api<Vehicle>({ method: 'PATCH', path: `/masterdata/v1/vehicles/${id}`, body: { active } }); }
export function fetchSkus(signal?: AbortSignal) { return api<{ skus: Sku[] }>({ path: '/masterdata/v1/skus', signal }); }
export function createSku(body: CreateSku) { return api<Sku>({ method: 'POST', path: '/masterdata/v1/skus', body }); }
export function setSkuActive(id: string, active: boolean) { return api<Sku>({ method: 'PATCH', path: `/masterdata/v1/skus/${id}`, body: { active } }); }
export function validateImport(type: MasterdataEntityType, rows: Record<string, string>[]) { return api<ValidateImportResponse>({ method: 'POST', path: '/masterdata/v1/import/validate', body: { type, rows } }); }
export function commitImport(type: MasterdataEntityType, rows: Record<string, string>[]) { return api<CommitImportResponse>({ method: 'POST', path: '/masterdata/v1/import/commit', body: { type, rows } }); }
EOF
W apps/admin-web/src/modules/masterdata/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { mdKeys, fetchDistributors, fetchVehicles, fetchSkus, createDistributor, createVehicle, createSku, setDistributorActive, setVehicleActive, setSkuActive, validateImport, commitImport } from './api';
import type { CreateDistributor, CreateVehicle, CreateSku, MasterdataEntityType } from './types';
export const useDistributors = () => useQuery({ queryKey: mdKeys.distributors(), queryFn: ({ signal }) => fetchDistributors(signal) });
export const useVehicles = () => useQuery({ queryKey: mdKeys.vehicles(), queryFn: ({ signal }) => fetchVehicles(signal) });
export const useSkus = () => useQuery({ queryKey: mdKeys.skus(), queryFn: ({ signal }) => fetchSkus(signal) });
export function useCreateDistributor() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateDistributor) => createDistributor(b), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.distributors() }) }); }
export function useCreateVehicle() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateVehicle) => createVehicle(b), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.vehicles() }) }); }
export function useCreateSku() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateSku) => createSku(b), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.skus() }) }); }
export function useToggleDistributorActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => setDistributorActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.distributors() }) }); }
export function useToggleVehicleActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => setVehicleActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.vehicles() }) }); }
export function useToggleSkuActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => setSkuActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.skus() }) }); }
export function useValidateImport() { return useMutation({ mutationFn: ({ type, rows }: { type: MasterdataEntityType; rows: Record<string, string>[] }) => validateImport(type, rows) }); }
export function useCommitImport() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ type, rows }: { type: MasterdataEntityType; rows: Record<string, string>[] }) => commitImport(type, rows), onSuccess: () => qc.invalidateQueries({ queryKey: mdKeys.all }) }); }
EOF
W apps/admin-web/src/modules/masterdata/components/CsvParser.ts <<'EOF'
import type { MasterdataEntityType } from '../types';
export function parseCsv(text: string): Record<string, string>[] {
  const clean = text.replace(/^\uFEFF/, '');
  const raw = parseRawCsv(clean);
  if (raw.length === 0) return [];
  const headers = raw[0]!.map((h) => h.trim().toLowerCase());
  const rows: Record<string, string>[] = [];
  for (let i = 1; i < raw.length; i++) {
    const cells = raw[i]!;
    if (cells.every((c) => c.trim() === '')) continue;
    const obj: Record<string, string> = {};
    for (let j = 0; j < headers.length; j++) obj[headers[j]!] = (cells[j] ?? '').trim();
    rows.push(obj);
  }
  return rows;
}
function parseRawCsv(text: string): string[][] {
  const rows: string[][] = []; let row: string[] = []; let field = ''; let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i]!;
    if (inQuotes) { if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else inQuotes = false; } else field += c; }
    else { if (c === '"') inQuotes = true; else if (c === ',') { row.push(field); field = ''; } else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; } else if (c === '\r') {} else field += c; }
  }
  if (field !== '' || row.length > 0) { row.push(field); rows.push(row); }
  return rows;
}
const TEMPLATES: Record<MasterdataEntityType, { headers: string[]; example: string[] }> = {
  distributor: { headers: ['name', 'region'], example: ['Acme Trading Co.', 'Addis Ababa'] },
  vehicle: { headers: ['plate', 'capacity_kg', 'capacity_m3', 'shift_start_h', 'shift_end_h', 'start_lat', 'start_lng', 'baseline_l_per_100km'], example: ['AA-3-B-201', '1500', '8', '7', '18', '9.0108', '38.7613', '12'] },
  sku: { headers: ['code', 'name', 'unit', 'weight_kg', 'volume_m3', 'reorder_point', 'safety_stock', 'lead_time_days'], example: ['SKU-EXAMPLE', 'Example Product', 'each', '0.5', '0.001', '20', '10', '3'] },
};
export function downloadTemplate(type: MasterdataEntityType): void {
  const t = TEMPLATES[type];
  const csv = `${t.headers.join(',')}\n${t.example.map((c) => (c.includes(',') ? `"${c}"` : c)).join(',')}\n`;
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = `${type}-template.csv`; document.body.appendChild(a); a.click(); document.body.removeChild(a); URL.revokeObjectURL(url);
}
EOF
W apps/admin-web/src/modules/masterdata/components/DistributorsTab.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useDistributors, useCreateDistributor, useToggleDistributorActive } from '../hooks';

export function DistributorsTab() {
  const { t } = useI18n();
  const list = useDistributors(); const create = useCreateDistributor(); const toggle = useToggleDistributorActive();
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState(''); const [region, setRegion] = useState('');
  const reset = () => { setName(''); setRegion(''); setShowForm(false); };
  const submit = () => { if (!name.trim() || !region.trim()) return; create.mutate({ name: name.trim(), region: region.trim() }, { onSuccess: reset }); };
  if (list.isLoading) return <Spinner label={t('common.loading')} />;
  if (list.isError || !list.data) return <div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">{t('common.error')}{' '}<button onClick={() => list.refetch()} className="underline">{t('common.retry')}</button></div>;
  const rows = list.data.distributors;
  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-muted">{rows.length} {t('admin.md.distributors_count')}</p>
        {!showForm && <Button onClick={() => setShowForm(true)}>{t('admin.md.add')}</Button>}
      </div>
      {showForm && (
        <div className="border border-primary/30 bg-surface rounded-md p-4 mb-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <label className="text-sm"><span className="text-muted block mb-1">{t('admin.md.name')}</span><input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
            <label className="text-sm"><span className="text-muted block mb-1">{t('admin.md.region')}</span><input value={region} onChange={(e) => setRegion(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          </div>
          {create.isError && <p className="text-sm text-danger mt-2">{(create.error as Error).message}</p>}
          <div className="flex justify-end gap-2 mt-4"><Button variant="secondary" onClick={reset} disabled={create.isPending}>{t('common.cancel')}</Button><Button onClick={submit} disabled={!name.trim() || !region.trim()} loading={create.isPending}>{t('common.confirm')}</Button></div>
        </div>
      )}
      {rows.length === 0 ? <EmptyState title={t('admin.md.no_distributors')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-bg border-b border-border"><tr>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.name')}</th>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.region')}</th>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
              <th className="text-right px-4 py-3"></th>
            </tr></thead>
            <tbody>
              {rows.map((d) => (
                <tr key={d.id} className="border-b border-border last:border-0">
                  <td className="px-4 py-3">{d.name}</td><td className="px-4 py-3">{d.region}</td>
                  <td className="px-4 py-3"><StatusPill tone={d.active ? 'success' : 'neutral'}>{d.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
                  <td className="px-4 py-3 text-right"><Button size="sm" variant={d.active ? 'ghost' : 'secondary'} onClick={() => toggle.mutate({ id: d.id, active: !d.active })} disabled={toggle.isPending}>{d.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/masterdata/components/VehiclesTab.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useVehicles, useCreateVehicle, useToggleVehicleActive } from '../hooks';
const EMPTY = { plate: '', capacity_kg: '', capacity_m3: '', shift_start_h: '7', shift_end_h: '18', start_lat: '9.0108', start_lng: '38.7613', baseline_l_per_100km: '' };

export function VehiclesTab() {
  const { t } = useI18n();
  const list = useVehicles(); const create = useCreateVehicle(); const toggle = useToggleVehicleActive();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const upd = (k: keyof typeof EMPTY, v: string) => setForm({ ...form, [k]: v });
  const reset = () => { setForm(EMPTY); setShowForm(false); };
  const submit = () => { create.mutate({
    plate: form.plate.trim(), capacity_kg: parseFloat(form.capacity_kg), capacity_m3: parseFloat(form.capacity_m3),
    shift_start_h: parseInt(form.shift_start_h, 10), shift_end_h: parseInt(form.shift_end_h, 10),
    start_lat: parseFloat(form.start_lat), start_lng: parseFloat(form.start_lng),
    baseline_l_per_100km: form.baseline_l_per_100km.trim() ? parseFloat(form.baseline_l_per_100km) : null,
  }, { onSuccess: reset }); };
  if (list.isLoading) return <Spinner label={t('common.loading')} />;
  if (list.isError || !list.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const rows = list.data.vehicles;
  return (
    <div>
      <div className="flex items-center justify-between mb-4"><p className="text-sm text-muted">{rows.length} {t('admin.md.vehicles_count')}</p>{!showForm && <Button onClick={() => setShowForm(true)}>{t('admin.md.add')}</Button>}</div>
      {showForm && (
        <div className="border border-primary/30 bg-surface rounded-md p-4 mb-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <Field label={t('admin.md.plate')} value={form.plate} onChange={(v) => upd('plate', v)} />
            <Field label={t('admin.md.capacity_kg')} value={form.capacity_kg} onChange={(v) => upd('capacity_kg', v)} type="number" />
            <Field label={t('admin.md.capacity_m3')} value={form.capacity_m3} onChange={(v) => upd('capacity_m3', v)} type="number" />
            <Field label={t('admin.md.baseline')} value={form.baseline_l_per_100km} onChange={(v) => upd('baseline_l_per_100km', v)} type="number" />
            <Field label={t('admin.md.shift_start')} value={form.shift_start_h} onChange={(v) => upd('shift_start_h', v)} type="number" />
            <Field label={t('admin.md.shift_end')} value={form.shift_end_h} onChange={(v) => upd('shift_end_h', v)} type="number" />
            <Field label={t('admin.md.start_lat')} value={form.start_lat} onChange={(v) => upd('start_lat', v)} type="number" />
            <Field label={t('admin.md.start_lng')} value={form.start_lng} onChange={(v) => upd('start_lng', v)} type="number" />
          </div>
          {create.isError && <p className="text-sm text-danger mt-2">{(create.error as Error).message}</p>}
          <div className="flex justify-end gap-2 mt-4"><Button variant="secondary" onClick={reset} disabled={create.isPending}>{t('common.cancel')}</Button><Button onClick={submit} disabled={!form.plate.trim() || !form.capacity_kg || !form.capacity_m3} loading={create.isPending}>{t('common.confirm')}</Button></div>
        </div>
      )}
      {rows.length === 0 ? <EmptyState title={t('admin.md.no_vehicles')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.plate')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">kg</th>
            <th className="text-right px-4 py-3 font-medium text-muted">m³</th>
            <th className="text-right px-4 py-3 font-medium text-muted">L/100km</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead>
          <tbody>{rows.map((v) => (
            <tr key={v.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-medium">{v.plate}</td>
              <td className="px-4 py-3 text-right tabular-nums">{v.capacity_kg}</td>
              <td className="px-4 py-3 text-right tabular-nums">{v.capacity_m3}</td>
              <td className="px-4 py-3 text-right tabular-nums">{v.baseline_l_per_100km ?? '—'}</td>
              <td className="px-4 py-3"><StatusPill tone={v.active ? 'success' : 'neutral'}>{v.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
              <td className="px-4 py-3 text-right"><Button size="sm" variant={v.active ? 'ghost' : 'secondary'} onClick={() => toggle.mutate({ id: v.id, active: !v.active })}>{v.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
function Field({ label, value, onChange, type = 'text' }: { label: string; value: string; onChange: (v: string) => void; type?: 'text' | 'number' }) {
  return <label className="text-sm"><span className="text-muted block mb-1">{label}</span><input type={type} value={value} onChange={(e) => onChange(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>;
}
EOF
W apps/admin-web/src/modules/masterdata/components/SkusTab.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useSkus, useCreateSku, useToggleSkuActive } from '../hooks';
const EMPTY = { code: '', name: '', unit: 'each', weight_kg: '', volume_m3: '', reorder_point: '0', safety_stock: '0', lead_time_days: '0' };

export function SkusTab() {
  const { t } = useI18n();
  const list = useSkus(); const create = useCreateSku(); const toggle = useToggleSkuActive();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const upd = (k: keyof typeof EMPTY, v: string) => setForm({ ...form, [k]: v });
  const reset = () => { setForm(EMPTY); setShowForm(false); };
  const submit = () => { create.mutate({
    code: form.code.trim(), name: form.name.trim(), unit: form.unit.trim(),
    weight_kg: parseFloat(form.weight_kg), volume_m3: parseFloat(form.volume_m3),
    reorder_point: parseInt(form.reorder_point, 10) || 0,
    safety_stock: parseInt(form.safety_stock, 10) || 0,
    lead_time_days: parseInt(form.lead_time_days, 10) || 0,
  }, { onSuccess: reset }); };
  if (list.isLoading) return <Spinner label={t('common.loading')} />;
  if (list.isError || !list.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const rows = list.data.skus;
  return (
    <div>
      <div className="flex items-center justify-between mb-4"><p className="text-sm text-muted">{rows.length} {t('admin.md.skus_count')}</p>{!showForm && <Button onClick={() => setShowForm(true)}>{t('admin.md.add')}</Button>}</div>
      {showForm && (
        <div className="border border-primary/30 bg-surface rounded-md p-4 mb-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <F label={t('admin.md.code')} value={form.code} onChange={(v) => upd('code', v)} />
            <F label={t('admin.md.name')} value={form.name} onChange={(v) => upd('name', v)} />
            <F label={t('admin.md.unit')} value={form.unit} onChange={(v) => upd('unit', v)} />
            <F label={t('admin.md.weight_kg')} value={form.weight_kg} onChange={(v) => upd('weight_kg', v)} type="number" />
            <F label={t('admin.md.volume_m3')} value={form.volume_m3} onChange={(v) => upd('volume_m3', v)} type="number" />
            <F label={t('admin.md.lead_time')} value={form.lead_time_days} onChange={(v) => upd('lead_time_days', v)} type="number" />
            <F label={t('admin.md.reorder')} value={form.reorder_point} onChange={(v) => upd('reorder_point', v)} type="number" />
            <F label={t('admin.md.safety')} value={form.safety_stock} onChange={(v) => upd('safety_stock', v)} type="number" />
          </div>
          {create.isError && <p className="text-sm text-danger mt-2">{(create.error as Error).message}</p>}
          <div className="flex justify-end gap-2 mt-4"><Button variant="secondary" onClick={reset} disabled={create.isPending}>{t('common.cancel')}</Button><Button onClick={submit} disabled={!form.code.trim() || !form.name.trim() || !form.weight_kg || !form.volume_m3} loading={create.isPending}>{t('common.confirm')}</Button></div>
        </div>
      )}
      {rows.length === 0 ? <EmptyState title={t('admin.md.no_skus')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.code')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.name')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.unit')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">kg</th>
            <th className="text-right px-4 py-3 font-medium text-muted">m³</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead>
          <tbody>{rows.map((s) => (
            <tr key={s.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-mono text-xs">{s.code}</td>
              <td className="px-4 py-3">{s.name}</td>
              <td className="px-4 py-3">{s.unit}</td>
              <td className="px-4 py-3 text-right tabular-nums">{s.weight_kg}</td>
              <td className="px-4 py-3 text-right tabular-nums">{s.volume_m3}</td>
              <td className="px-4 py-3"><StatusPill tone={s.active ? 'success' : 'neutral'}>{s.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
              <td className="px-4 py-3 text-right"><Button size="sm" variant={s.active ? 'ghost' : 'secondary'} onClick={() => toggle.mutate({ id: s.id, active: !s.active })}>{s.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
function F({ label, value, onChange, type = 'text' }: { label: string; value: string; onChange: (v: string) => void; type?: 'text' | 'number' }) {
  return <label className="text-sm"><span className="text-muted block mb-1">{label}</span><input type={type} value={value} onChange={(e) => onChange(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>;
}
EOF
W apps/admin-web/src/modules/masterdata/components/ImportTab.tsx <<'EOF'
import { useRef, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, StatusPill } from '@tera/ui';
import { parseCsv, downloadTemplate } from './CsvParser';
import { useValidateImport, useCommitImport } from '../hooks';
import type { MasterdataEntityType, ValidateImportResponse, CommitImportResponse } from '../types';
const TYPES: MasterdataEntityType[] = ['distributor', 'vehicle', 'sku'];

export function ImportTab() {
  const { t } = useI18n();
  const fileRef = useRef<HTMLInputElement>(null);
  const [type, setType] = useState<MasterdataEntityType>('distributor');
  const [rows, setRows] = useState<Record<string, string>[] | null>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const [report, setReport] = useState<ValidateImportResponse | null>(null);
  const [result, setResult] = useState<CommitImportResponse | null>(null);
  const [showValid, setShowValid] = useState(false);
  const [parseError, setParseError] = useState<string | null>(null);
  const validateMut = useValidateImport(); const commitMut = useCommitImport();
  const reset = () => { setRows(null); setFileName(null); setReport(null); setResult(null); setParseError(null); setShowValid(false); if (fileRef.current) fileRef.current.value = ''; };
  const handleFile = async (file: File) => { reset(); setFileName(file.name); try { const text = await file.text(); const parsed = parseCsv(text); if (parsed.length === 0) { setParseError(t('admin.import.empty_file')); return; } setRows(parsed); } catch (e) { setParseError((e as Error).message); } };
  return (
    <div>
      <div className="mb-6"><p className="text-sm font-semibold text-muted uppercase tracking-wide mb-2">{t('admin.import.step1')}</p>
        <div className="flex flex-wrap gap-2">{TYPES.map((ty) => <Button key={ty} variant={type === ty ? 'primary' : 'secondary'} onClick={() => { setType(ty); reset(); }}>{t(`admin.import.type.${ty}`)}</Button>)}</div>
      </div>
      <div className="mb-6"><p className="text-sm font-semibold text-muted uppercase tracking-wide mb-2">{t('admin.import.step2')}</p>
        <div className="flex items-center gap-3 flex-wrap">
          <Button variant="ghost" onClick={() => downloadTemplate(type)}>⬇ {t('admin.import.download_template')}</Button>
          <label className="inline-flex items-center gap-2 px-4 py-2 rounded-md border border-border bg-surface cursor-pointer hover:bg-bg">
            <input ref={fileRef} type="file" accept=".csv,text/csv" onChange={(e) => { const f = e.target.files?.[0]; if (f) void handleFile(f); }} className="sr-only" />
            <span className="text-sm font-medium">{t('admin.import.choose_file')}</span>
          </label>
          {fileName && <span className="text-sm text-muted">{fileName}</span>}
        </div>
        {parseError && <p className="text-sm text-danger mt-2">{parseError}</p>}
      </div>
      {rows && !report && !result && (
        <div className="border border-border rounded-md bg-surface p-4 flex items-center justify-between">
          <p className="text-sm">{rows.length} {t('admin.import.rows_detected')}</p>
          <Button onClick={() => validateMut.mutate({ type, rows }, { onSuccess: (r) => { setReport(r); setResult(null); } })} loading={validateMut.isPending}>{t('admin.import.validate')}</Button>
        </div>
      )}
      {report && !result && (
        <div className="border border-border rounded-md bg-surface">
          <div className="px-4 py-3 border-b border-border flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-3">
              <StatusPill tone="success">{report.valid_rows} {t('admin.import.valid')}</StatusPill>
              {report.invalid_rows > 0 && <StatusPill tone="danger">{report.invalid_rows} {t('admin.import.invalid')}</StatusPill>}
            </div>
            <div className="flex gap-2">
              <Button variant="secondary" onClick={reset} disabled={commitMut.isPending}>{t('common.cancel')}</Button>
              <Button disabled={report.valid_rows === 0} loading={commitMut.isPending}
                onClick={() => { if (rows) commitMut.mutate({ type, rows }, { onSuccess: (r) => setResult(r) }); }}>
                {t('admin.import.commit', { n: report.valid_rows })}
              </Button>
            </div>
          </div>
          {report.rows.filter((r) => r.status === 'invalid').length > 0 && (
            <div className="p-4 border-b border-border">
              <p className="text-sm font-semibold text-danger mb-2">{t('admin.import.fix_these', { n: report.invalid_rows })}</p>
              <table className="w-full text-xs"><tbody>
                {report.rows.filter((r) => r.status === 'invalid').map((r) => (
                  <tr key={r.row_number} className="border-t border-border">
                    <td className="px-3 py-2 tabular-nums font-mono w-12">{r.row_number}</td>
                    <td className="px-3 py-2 text-danger">{r.errors.join(' · ')}</td>
                  </tr>
                ))}
              </tbody></table>
            </div>
          )}
          <div className="p-4">
            <button onClick={() => setShowValid((v) => !v)} className="text-sm text-primary hover:underline">
              {showValid ? '−' : '+'} {t('admin.import.show_valid', { n: report.valid_rows })}
            </button>
          </div>
        </div>
      )}
      {result && (
        <div className="border border-border rounded-md bg-surface p-6 text-center">
          <div className="text-4xl mb-2">{result.errors.length === 0 ? '✓' : '⚠'}</div>
          <p className="text-lg font-semibold">{t('admin.import.committed', { n: result.inserted })}</p>
          {result.skipped > 0 && <p className="text-sm text-warn mt-1">{t('admin.import.skipped', { n: result.skipped })}</p>}
          <Button onClick={reset} className="mt-4">{t('admin.import.import_another')}</Button>
        </div>
      )}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/masterdata/MasterdataPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { DistributorsTab } from './components/DistributorsTab';
import { VehiclesTab } from './components/VehiclesTab';
import { SkusTab } from './components/SkusTab';
import { ImportTab } from './components/ImportTab';
import type { Tab } from './types';

const TABS: { id: Tab; key: string }[] = [
  { id: 'distributors', key: 'admin.md.tab.distributors' },
  { id: 'vehicles', key: 'admin.md.tab.vehicles' },
  { id: 'skus', key: 'admin.md.tab.skus' },
  { id: 'import', key: 'admin.md.tab.import' },
];
export function MasterdataPage() {
  const { t } = useI18n();
  const [tab, setTab] = useState<Tab>('distributors');
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('admin.md.title')}</h1><p className="text-sm text-muted mt-1">{t('admin.md.subtitle')}</p></header>
      <div className="border-b border-border mb-6"><nav className="flex gap-1 -mb-px">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </nav></div>
      {tab === 'distributors' && <DistributorsTab />}
      {tab === 'vehicles' && <VehiclesTab />}
      {tab === 'skus' && <SkusTab />}
      {tab === 'import' && <ImportTab />}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/masterdata/index.ts <<'EOF'
export { MasterdataPage } from './MasterdataPage';
export type { Distributor, Vehicle, Sku, MasterdataEntityType } from './types';
EOF

# ── constraints module (curfew + fuel stations)
W apps/admin-web/src/modules/constraints/types.ts <<'EOF'
export type { CurfewZone, CreateCurfewZone, UpdateCurfewHours, FuelStation, FuelStationStatus, CreateFuelStation, GeoJsonPolygon } from '@tera/contracts';
export type Tab = 'curfews' | 'fuel-stations';
EOF
W apps/admin-web/src/modules/constraints/geo-utils.ts <<'EOF'
export type LatLng = [number, number];
export interface GeoJsonPolygon { type: 'Polygon'; coordinates: [number, number][][]; }
export function toGeoJson(points: LatLng[]): GeoJsonPolygon {
  if (points.length < 3) throw new Error('polygon needs at least 3 points');
  const ring: [number, number][] = points.map(([lat, lng]) => [lng, lat]);
  ring.push(ring[0]!);
  return { type: 'Polygon', coordinates: [ring] };
}
export function fromGeoJson(geojson: GeoJsonPolygon): LatLng[] {
  const ring = geojson.coordinates[0] ?? [];
  return ring.slice(0, -1).map(([lng, lat]) => [lat, lng] as LatLng);
}
export function isActiveNow(startHour: number, endHour: number, now = new Date()): boolean {
  const h = now.getHours();
  if (startHour <= endHour) return h >= startHour && h < endHour;
  return h >= startHour || h < endHour;
}
export function formatHour(h: number): string { return `${String(h).padStart(2, '0')}:00`; }
export function formatRange(startH: number, endH: number): string { return `${formatHour(startH)} – ${formatHour(endH)}`; }
EOF
W apps/admin-web/src/modules/constraints/api.ts <<'EOF'
import { api } from '../../api/client';
import type { CurfewZone, CreateCurfewZone, UpdateCurfewHours, FuelStation, FuelStationStatus, CreateFuelStation } from './types';
export const geoKeys = { all: ['constraints'] as const, curfews: () => [...geoKeys.all, 'curfews'] as const, stations: () => [...geoKeys.all, 'stations'] as const };
export function fetchCurfews(signal?: AbortSignal) { return api<{ zones: CurfewZone[] }>({ path: '/geo/v1/curfew-zones?includeInactive=1', signal }); }
export function createCurfew(body: CreateCurfewZone) { return api<CurfewZone>({ method: 'POST', path: '/geo/v1/curfew-zones', body }); }
export function updateCurfewHours(id: string, body: UpdateCurfewHours) { return api<CurfewZone>({ method: 'PATCH', path: `/geo/v1/curfew-zones/${id}/hours`, body }); }
export function toggleCurfewActive(id: string, active: boolean) { return api<CurfewZone>({ method: 'PATCH', path: `/geo/v1/curfew-zones/${id}`, body: { active } }); }
export function fetchStations(signal?: AbortSignal) { return api<{ stations: FuelStation[] }>({ path: '/geo/v1/fuel-stations?includeInactive=1', signal }); }
export function createStation(body: CreateFuelStation) { return api<FuelStation>({ method: 'POST', path: '/geo/v1/fuel-stations', body }); }
export function setStationStatus(id: string, status: FuelStationStatus) { return api<FuelStation>({ method: 'PATCH', path: `/geo/v1/fuel-stations/${id}/status`, body: { status } }); }
export function toggleStationActive(id: string, active: boolean) { return api<FuelStation>({ method: 'PATCH', path: `/geo/v1/fuel-stations/${id}`, body: { active } }); }
EOF
W apps/admin-web/src/modules/constraints/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { geoKeys, fetchCurfews, createCurfew, updateCurfewHours, toggleCurfewActive, fetchStations, createStation, setStationStatus, toggleStationActive } from './api';
import type { CreateCurfewZone, UpdateCurfewHours, CreateFuelStation, FuelStationStatus } from './types';
export const useCurfews = () => useQuery({ queryKey: geoKeys.curfews(), queryFn: ({ signal }) => fetchCurfews(signal) });
export function useCreateCurfew() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateCurfewZone) => createCurfew(b), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.curfews() }) }); }
export function useUpdateCurfewHours() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, body }: { id: string; body: UpdateCurfewHours }) => updateCurfewHours(id, body), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.curfews() }) }); }
export function useToggleCurfewActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => toggleCurfewActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.curfews() }) }); }
export const useStations = () => useQuery({ queryKey: geoKeys.stations(), queryFn: ({ signal }) => fetchStations(signal) });
export function useCreateStation() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: CreateFuelStation) => createStation(b), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.stations() }) }); }
export function useSetStationStatus() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, status }: { id: string; status: FuelStationStatus }) => setStationStatus(id, status), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.stations() }) }); }
export function useToggleStationActive() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, active }: { id: string; active: boolean }) => toggleStationActive(id, active), onSuccess: () => qc.invalidateQueries({ queryKey: geoKeys.stations() }) }); }
EOF
W apps/admin-web/src/modules/constraints/components/CurfewMapEditor.tsx <<'EOF'
import { useEffect } from 'react';
import { MapContainer, TileLayer, Polygon, Polyline, CircleMarker, Popup, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { CurfewZone } from '../types';
import { fromGeoJson, isActiveNow, formatRange, type LatLng } from '../geo-utils';

delete (L.Icon.Default.prototype as any)._getIconUrl;
const CENTER: LatLng = [9.0108, 38.7613];

interface Props {
  zones: CurfewZone[];
  drawing: boolean;
  drawingPoints: LatLng[];
  onAddPoint: (p: LatLng) => void;
}
export function CurfewMapEditor({ zones, drawing, drawingPoints, onAddPoint }: Props) {
  useEffect(() => { const t = setTimeout(() => window.dispatchEvent(new Event('resize')), 200); return () => clearTimeout(t); }, []);
  return (
    <div className="w-full h-full min-h-[500px] rounded-md overflow-hidden border border-border relative">
      <MapContainer center={CENTER} zoom={12} style={{ width: '100%', height: '100%' }}>
        <TileLayer attribution='&copy; OpenStreetMap' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        {zones.map((z) => {
          const positions = fromGeoJson(z.polygon);
          const activeNow = z.active && isActiveNow(z.start_hour, z.end_hour);
          const pathOptions = !z.active
            ? { color: '#6b6b6b', fillColor: '#6b6b6b', fillOpacity: 0.08, weight: 1.5, dashArray: '2 4' }
            : activeNow ? { color: '#b91c1c', fillColor: '#b91c1c', fillOpacity: 0.25, weight: 3 }
              : { color: '#b91c1c', fillColor: '#b91c1c', fillOpacity: 0.1, weight: 2, dashArray: '4 4' };
          return (
            <Polygon key={z.id} positions={positions} pathOptions={pathOptions}>
              <Popup><div className="text-sm"><strong>{z.name}</strong><br />{formatRange(z.start_hour, z.end_hour)}<br /><em className="text-xs">{z.reason}</em><br /><span className="text-xs">{!z.active ? '⏸ Inactive' : activeNow ? '● Active now' : '○ Scheduled'}</span></div></Popup>
            </Polygon>
          );
        })}
        {drawing && (
          <>
            {drawingPoints.length >= 3 && <Polygon positions={drawingPoints} pathOptions={{ color: '#0f766e', fillColor: '#0f766e', fillOpacity: 0.2, weight: 2, dashArray: '6 4' }} />}
            {drawingPoints.length === 2 && <Polyline positions={drawingPoints} pathOptions={{ color: '#0f766e', weight: 2, dashArray: '6 4' }} />}
            {drawingPoints.map((p, i) => <CircleMarker key={i} center={p} radius={7} pathOptions={{ color: '#0f766e', fillColor: '#0f766e', fillOpacity: 1, weight: 2 }}><Popup>Point {i + 1}</Popup></CircleMarker>)}
            <ClickCatcher onAddPoint={onAddPoint} />
          </>
        )}
      </MapContainer>
    </div>
  );
}
function ClickCatcher({ onAddPoint }: { onAddPoint: (p: LatLng) => void }) {
  useMapEvents({ click: (e) => onAddPoint([e.latlng.lat, e.latlng.lng]) });
  return null;
}
EOF
W apps/admin-web/src/modules/constraints/components/CurfewSaveModal.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreateCurfewZone } from '../types';
import { toGeoJson, type LatLng } from '../geo-utils';

interface Props { points: LatLng[]; onSubmit: (b: CreateCurfewZone) => void; onCancel: () => void; isSaving: boolean; error: string | null; }

export function CurfewSaveModal({ points, onSubmit, onCancel, isSaving, error }: Props) {
  const { t } = useI18n();
  const [name, setName] = useState(''); const [reason, setReason] = useState('');
  const [startHour, setStartHour] = useState('7'); const [endHour, setEndHour] = useState('10');
  const startNum = parseInt(startHour, 10); const endNum = parseInt(endHour, 10);
  const hoursValid = Number.isInteger(startNum) && startNum >= 0 && startNum <= 23 && Number.isInteger(endNum) && endNum >= 0 && endNum <= 23 && startNum !== endNum;
  const canSubmit = name.trim().length > 0 && reason.trim().length > 0 && hoursValid && !isSaving;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-1">{t('admin.constraints.curfew.save_title')}</h2>
        <p className="text-sm text-muted mb-4">{points.length} {t('admin.constraints.curfew.points')}</p>
        <label className="block text-sm mb-3"><span className="text-muted block mb-1">{t('admin.constraints.curfew.name')}</span>
          <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        <div className="grid grid-cols-2 gap-3 mb-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.start_hour')}</span>
            <input type="number" min={0} max={23} value={startHour} onChange={(e) => setStartHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.end_hour')}</span>
            <input type="number" min={0} max={23} value={endHour} onChange={(e) => setEndHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        </div>
        {!hoursValid && <p className="text-xs text-danger mb-3">{t('admin.constraints.curfew.hours_hint')}</p>}
        <label className="block text-sm mb-4"><span className="text-muted block mb-1">{t('admin.constraints.curfew.reason')}</span>
          <input value={reason} onChange={(e) => setReason(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        {error && <p className="text-sm text-danger mb-3">{error}</p>}
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isSaving}>{t('common.cancel')}</Button>
          <Button onClick={() => { if (!canSubmit) return; try { onSubmit({ name: name.trim(), polygon: toGeoJson(points), start_hour: startNum, end_hour: endNum, reason: reason.trim() }); } catch { /* */ } }} disabled={!canSubmit} loading={isSaving}>{t('common.confirm')}</Button>
        </div>
      </div>
    </div>
  );
}
EOF
W apps/admin-web/src/modules/constraints/components/CurfewHoursModal.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CurfewZone, UpdateCurfewHours } from '../types';

interface Props { zone: CurfewZone; onSubmit: (b: UpdateCurfewHours) => void; onCancel: () => void; isSaving: boolean; error: string | null; }

export function CurfewHoursModal({ zone, onSubmit, onCancel, isSaving, error }: Props) {
  const { t } = useI18n();
  const [startHour, setStartHour] = useState(String(zone.start_hour));
  const [endHour, setEndHour] = useState(String(zone.end_hour));
  const [reason, setReason] = useState(zone.reason);
  const startNum = parseInt(startHour, 10); const endNum = parseInt(endHour, 10);
  const hoursValid = Number.isInteger(startNum) && startNum >= 0 && startNum <= 23 && Number.isInteger(endNum) && endNum >= 0 && endNum <= 23 && startNum !== endNum;
  const canSubmit = reason.trim().length > 0 && hoursValid && !isSaving;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-1">{t('admin.constraints.curfew.edit_title')}</h2>
        <p className="text-sm text-muted mb-4">{zone.name}</p>
        <div className="grid grid-cols-2 gap-3 mb-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.start_hour')}</span>
            <input type="number" min={0} max={23} value={startHour} onChange={(e) => setStartHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.curfew.end_hour')}</span>
            <input type="number" min={0} max={23} value={endHour} onChange={(e) => setEndHour(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        </div>
        <label className="block text-sm mb-4"><span className="text-muted block mb-1">{t('admin.constraints.curfew.reason')}</span>
          <input value={reason} onChange={(e) => setReason(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        {error && <p className="text-sm text-danger mb-3">{error}</p>}
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isSaving}>{t('common.cancel')}</Button>
          <Button onClick={() => onSubmit({ start_hour: startNum, end_hour: endNum, reason: reason.trim() })} disabled={!canSubmit} loading={isSaving}>{t('common.confirm')}</Button>
        </div>
      </div>
    </div>
  );
}
EOF
W apps/admin-web/src/modules/constraints/components/CurfewsTab.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { CurfewMapEditor } from './CurfewMapEditor';
import { CurfewSaveModal } from './CurfewSaveModal';
import { CurfewHoursModal } from './CurfewHoursModal';
import { useCurfews, useCreateCurfew, useUpdateCurfewHours, useToggleCurfewActive } from '../hooks';
import { isActiveNow, formatRange, type LatLng } from '../geo-utils';
import type { CurfewZone } from '../types';

export function CurfewsTab() {
  const { t } = useI18n();
  const [drawing, setDrawing] = useState(false);
  const [points, setPoints] = useState<LatLng[]>([]);
  const [showSave, setShowSave] = useState(false);
  const [editing, setEditing] = useState<CurfewZone | null>(null);
  const zonesQ = useCurfews(); const createMut = useCreateCurfew(); const hoursMut = useUpdateCurfewHours(); const toggleMut = useToggleCurfewActive();
  const zones = useMemo(() => zonesQ.data?.zones ?? [], [zonesQ.data]);
  return (
    <div>
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <p className="text-sm text-muted">{zones.length} {t('admin.constraints.curfew.count')}</p>
        <div className="flex gap-2">
          {!drawing && <Button onClick={() => { setDrawing(true); setPoints([]); setShowSave(false); }}>{t('admin.constraints.curfew.draw')}</Button>}
          {drawing && (<>
            <Button variant="ghost" onClick={() => setPoints((p) => p.slice(0, -1))} disabled={points.length === 0}>{t('admin.constraints.curfew.undo')}</Button>
            <Button variant="secondary" onClick={() => { setDrawing(false); setPoints([]); setShowSave(false); }}>{t('common.cancel')}</Button>
            <Button onClick={() => { if (points.length >= 3) setShowSave(true); }} disabled={points.length < 3}>{t('admin.constraints.curfew.save_points', { n: points.length })}</Button>
          </>)}
        </div>
      </div>
      {drawing && <div className="mb-3 text-sm bg-primary/5 border border-primary/30 rounded-md px-3 py-2">{t('admin.constraints.curfew.instructions')}</div>}
      <div className="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-4">
        <div className="min-h-[500px]">
          <CurfewMapEditor zones={zones} drawing={drawing} drawingPoints={points} onAddPoint={(p) => setPoints((prev) => [...prev, p])} />
        </div>
        <aside className="flex flex-col gap-2">
          <div className="text-sm font-semibold text-muted uppercase tracking-wide px-1 mb-1">{t('admin.constraints.curfew.zones')}</div>
          {zonesQ.isLoading && <Spinner label={t('common.loading')} />}
          {zonesQ.isError && <div className="text-sm text-danger border border-danger/30 bg-dangerBg rounded-md p-3">{t('common.error')}</div>}
          {!zonesQ.isLoading && !zonesQ.isError && zones.length === 0 && <EmptyState title={t('admin.constraints.curfew.none')} />}
          {zones.map((z) => {
            const activeNow = z.active && isActiveNow(z.start_hour, z.end_hour);
            return (
              <div key={z.id} className={`border rounded-md p-3 bg-surface ${z.active ? 'border-border' : 'border-border opacity-60'}`}>
                <div className="flex items-center justify-between mb-1">
                  <span className="font-medium text-sm">{z.name}</span>
                  <StatusPill tone={!z.active ? 'neutral' : activeNow ? 'danger' : 'warn'}>{!z.active ? t('admin.constraints.curfew.inactive') : activeNow ? t('admin.constraints.curfew.active_now') : t('admin.constraints.curfew.scheduled')}</StatusPill>
                </div>
                <div className="text-xs text-muted">{formatRange(z.start_hour, z.end_hour)}</div>
                <div className="text-xs text-muted mt-1 italic">"{z.reason}"</div>
                <div className="flex gap-1 mt-2">
                  <Button size="sm" variant="ghost" onClick={() => setEditing(z)}>{t('admin.constraints.curfew.edit_hours')}</Button>
                  <Button size="sm" variant={z.active ? 'ghost' : 'secondary'} onClick={() => toggleMut.mutate({ id: z.id, active: !z.active })} disabled={toggleMut.isPending}>{z.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button>
                </div>
              </div>
            );
          })}
        </aside>
      </div>
      {showSave && points.length >= 3 && <CurfewSaveModal points={points} onSubmit={(b) => createMut.mutate(b, { onSuccess: () => { setDrawing(false); setPoints([]); setShowSave(false); } })} onCancel={() => setShowSave(false)} isSaving={createMut.isPending} error={createMut.isError ? (createMut.error as Error).message : null} />}
      {editing && <CurfewHoursModal zone={editing} onSubmit={(b) => hoursMut.mutate({ id: editing.id, body: b }, { onSuccess: () => setEditing(null) })} onCancel={() => setEditing(null)} isSaving={hoursMut.isPending} error={hoursMut.isError ? (hoursMut.error as Error).message : null} />}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/constraints/components/AddStationModal.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreateFuelStation, FuelStationStatus } from '../types';
interface Props { onSubmit: (b: CreateFuelStation) => void; onCancel: () => void; isSaving: boolean; error: string | null; }
export function AddStationModal({ onSubmit, onCancel, isSaving, error }: Props) {
  const { t } = useI18n();
  const [name, setName] = useState(''); const [lat, setLat] = useState('9.0108'); const [lng, setLng] = useState('38.7613'); const [status, setStatus] = useState<FuelStationStatus>('operational');
  const latNum = parseFloat(lat); const lngNum = parseFloat(lng);
  const valid = name.trim().length > 0 && Number.isFinite(latNum) && latNum >= -90 && latNum <= 90 && Number.isFinite(lngNum) && lngNum >= -180 && lngNum <= 180;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-4">{t('admin.constraints.station.add_title')}</h2>
        <label className="block text-sm mb-3"><span className="text-muted block mb-1">{t('admin.constraints.station.name')}</span>
          <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        <div className="grid grid-cols-2 gap-3 mb-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.station.lat')}</span>
            <input type="number" step="0.0001" value={lat} onChange={(e) => setLat(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('admin.constraints.station.lng')}</span>
            <input type="number" step="0.0001" value={lng} onChange={(e) => setLng(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
        </div>
        <label className="block text-sm mb-4"><span className="text-muted block mb-1">{t('admin.constraints.station.status')}</span>
          <select value={status} onChange={(e) => setStatus(e.target.value as FuelStationStatus)} className="w-full rounded-md border border-border bg-bg px-3 py-2">
            <option value="operational">{t('admin.constraints.station.status.operational')}</option>
            <option value="queued">{t('admin.constraints.station.status.queued')}</option>
            <option value="dry">{t('admin.constraints.station.status.dry')}</option>
          </select>
        </label>
        {error && <p className="text-sm text-danger mb-3">{error}</p>}
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isSaving}>{t('common.cancel')}</Button>
          <Button onClick={() => onSubmit({ name: name.trim(), lat: latNum, lng: lngNum, status })} disabled={!valid} loading={isSaving}>{t('common.confirm')}</Button>
        </div>
      </div>
    </div>
  );
}
EOF
W apps/admin-web/src/modules/constraints/components/FuelStationsTab.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { AddStationModal } from './AddStationModal';
import { useStations, useCreateStation, useSetStationStatus, useToggleStationActive } from '../hooks';
import type { FuelStationStatus } from '../types';

const CENTER: [number, number] = [9.0108, 38.7613];
function statusTone(s: FuelStationStatus): 'success' | 'warn' | 'danger' { return s === 'operational' ? 'success' : s === 'queued' ? 'warn' : 'danger'; }
function statusColor(s: FuelStationStatus, active: boolean): string { if (!active) return '#9a9a9a'; return s === 'operational' ? '#166534' : s === 'queued' ? '#b45309' : '#b91c1c'; }

export function FuelStationsTab() {
  const { t } = useI18n();
  const [showAdd, setShowAdd] = useState(false);
  const stationsQ = useStations(); const createMut = useCreateStation(); const statusMut = useSetStationStatus(); const toggleMut = useToggleStationActive();
  const stations = useMemo(() => stationsQ.data?.stations ?? [], [stationsQ.data]);
  const activeStations = stations.filter((s) => s.active);
  if (stationsQ.isLoading) return <Spinner label={t('common.loading')} />;
  if (stationsQ.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div>
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <p className="text-sm text-muted">{stations.length} {t('admin.constraints.station.count')}</p>
        <Button onClick={() => setShowAdd(true)}>{t('admin.md.add')}</Button>
      </div>
      {activeStations.length > 0 && (
        <div className="mb-4 rounded-md overflow-hidden border border-border h-[280px]">
          <MapContainer center={CENTER} zoom={12} style={{ width: '100%', height: '100%' }}>
            <TileLayer attribution='&copy; OpenStreetMap' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
            {activeStations.map((s) => <CircleMarker key={s.id} center={[s.lat, s.lng]} radius={10} pathOptions={{ color: statusColor(s.status, s.active), fillColor: statusColor(s.status, s.active), fillOpacity: 0.7, weight: 2 }}>
              <Popup><strong>{s.name}</strong><br /><span className="text-xs">{s.status}</span></Popup>
            </CircleMarker>)}
          </MapContainer>
        </div>
      )}
      {stations.length === 0 ? <EmptyState title={t('admin.constraints.station.none')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.constraints.station.name')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">Lat, Lng</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.constraints.station.status')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead>
          <tbody>{stations.map((s) => (
            <tr key={s.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-medium">{s.name}</td>
              <td className="px-4 py-3 text-right tabular-nums text-xs text-muted">{s.lat.toFixed(4)}, {s.lng.toFixed(4)}</td>
              <td className="px-4 py-3"><div className="flex items-center gap-2">
                <select value={s.status} onChange={(e) => statusMut.mutate({ id: s.id, status: e.target.value as FuelStationStatus })} disabled={statusMut.isPending || !s.active} className="rounded-md border border-border bg-bg px-2 py-1 text-sm">
                  <option value="operational">{t('admin.constraints.station.status.operational')}</option>
                  <option value="queued">{t('admin.constraints.station.status.queued')}</option>
                  <option value="dry">{t('admin.constraints.station.status.dry')}</option>
                </select>
                <StatusPill tone={statusTone(s.status)}>{s.status}</StatusPill>
              </div></td>
              <td className="px-4 py-3"><StatusPill tone={s.active ? 'success' : 'neutral'}>{s.active ? t('admin.md.active') : t('admin.md.inactive')}</StatusPill></td>
              <td className="px-4 py-3 text-right"><Button size="sm" variant={s.active ? 'ghost' : 'secondary'} onClick={() => toggleMut.mutate({ id: s.id, active: !s.active })} disabled={toggleMut.isPending}>{s.active ? t('admin.md.deactivate') : t('admin.md.activate')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
      {showAdd && <AddStationModal onSubmit={(b) => createMut.mutate(b, { onSuccess: () => setShowAdd(false) })} onCancel={() => setShowAdd(false)} isSaving={createMut.isPending} error={createMut.isError ? (createMut.error as Error).message : null} />}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/constraints/ConstraintsPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { CurfewsTab } from './components/CurfewsTab';
import { FuelStationsTab } from './components/FuelStationsTab';
import type { Tab } from './types';
const TABS: { id: Tab; key: string }[] = [{ id: 'curfews', key: 'admin.constraints.tab.curfews' }, { id: 'fuel-stations', key: 'admin.constraints.tab.fuel' }];
export function ConstraintsPage() {
  const { t } = useI18n();
  const [tab, setTab] = useState<Tab>('curfews');
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('admin.constraints.title')}</h1><p className="text-sm text-muted mt-1">{t('admin.constraints.subtitle')}</p></header>
      <div className="border-b border-border mb-6"><nav className="flex gap-1 -mb-px">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </nav></div>
      {tab === 'curfews' && <CurfewsTab />}
      {tab === 'fuel-stations' && <FuelStationsTab />}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/constraints/index.ts <<'EOF'
export { ConstraintsPage } from './ConstraintsPage';
export type { CurfewZone, FuelStation, FuelStationStatus } from './types';
EOF

# ═══════════════════════════════════════════════════════════════════
# i18n — warehouse + admin keys
# ═══════════════════════════════════════════════════════════════════
node <<'NODE'
const fs = require('fs');
const en = JSON.parse(fs.readFileSync('packages/i18n/src/locales/en.json', 'utf8'));
const am = JSON.parse(fs.readFileSync('packages/i18n/src/locales/am.json', 'utf8'));

Object.assign(en, {
  'warehouse.title': 'Warehouse', 'warehouse.tab.dock': 'Dock Queue', 'warehouse.tab.pick': 'Pick & Stage',
  'warehouse.mode.kiosk': 'Kiosk mode', 'warehouse.mode.normal': 'Normal mode',
  'warehouse.dock.title': 'Dock Queue', 'warehouse.dock.subtitle': 'Loading — tap Confirm when all goods are on the truck',
  'warehouse.dock.empty': 'Nothing to load right now', 'warehouse.dock.empty_hint': 'Newly allocated slots will appear here.',
  'warehouse.dock.confirm_loading': 'Confirm loading', 'warehouse.dock.pick_first': 'Pick all stops first',
  'warehouse.dock.picked_label': 'picked', 'warehouse.dock.awaiting_dispatch': 'Loading confirmed — awaiting dispatcher',
  'warehouse.pick.title': 'Pick & Stage', 'warehouse.pick.subtitle': 'Pick in stop order, mark each one done, then confirm loading',
  'warehouse.pick.routes_today': "Today's routes", 'warehouse.pick.select_route': 'Select a route on the left to see its pick list',
  'warehouse.pick.no_routes': 'No routes to pick today', 'warehouse.pick.no_routes_hint': 'Routes appear here once the dispatcher allocates a dock slot.',
  'warehouse.pick.no_stops': 'This route has no stops', 'warehouse.pick.qty_ordered': 'Ordered',
  'warehouse.pick.mark_picked': 'Mark picked', 'warehouse.pick.picked': 'Picked',
  'warehouse.pick.confirm_loading': 'Confirm loading', 'warehouse.pick.cannot_confirm': 'All stops must be picked',
  'warehouse.pick.ready': 'Ready', 'warehouse.pick.pending': 'Picking',

  'admin.title': 'Admin', 'admin.nav.masterdata': 'Master Data', 'admin.nav.constraints': 'Constraints',
  'admin.md.title': 'Master Data', 'admin.md.subtitle': 'Distributors, vehicles, SKUs — the nouns the whole system runs on',
  'admin.md.tab.distributors': 'Distributors', 'admin.md.tab.vehicles': 'Vehicles', 'admin.md.tab.skus': 'SKUs', 'admin.md.tab.import': 'Import',
  'admin.md.add': 'Add new', 'admin.md.name': 'Name', 'admin.md.region': 'Region', 'admin.md.status': 'Status',
  'admin.md.active': 'Active', 'admin.md.inactive': 'Inactive',
  'admin.md.deactivate': 'Deactivate', 'admin.md.activate': 'Activate',
  'admin.md.plate': 'Plate', 'admin.md.capacity_kg': 'Capacity (kg)', 'admin.md.capacity_m3': 'Capacity (m³)',
  'admin.md.baseline': 'Baseline (L/100km)', 'admin.md.shift_start': 'Shift start', 'admin.md.shift_end': 'Shift end',
  'admin.md.start_lat': 'Start lat', 'admin.md.start_lng': 'Start lng',
  'admin.md.code': 'Code', 'admin.md.unit': 'Unit', 'admin.md.weight_kg': 'Weight (kg)', 'admin.md.volume_m3': 'Volume (m³)',
  'admin.md.reorder': 'Reorder point', 'admin.md.safety': 'Safety stock', 'admin.md.lead_time': 'Lead time (days)',
  'admin.md.distributors_count': 'distributors', 'admin.md.vehicles_count': 'vehicles', 'admin.md.skus_count': 'SKUs',
  'admin.md.no_distributors': 'No distributors yet', 'admin.md.no_vehicles': 'No vehicles yet', 'admin.md.no_skus': 'No SKUs yet',
  'admin.import.step1': 'Step 1 — What are you importing?', 'admin.import.step2': 'Step 2 — Download template, then upload your file',
  'admin.import.type.distributor': 'Distributors', 'admin.import.type.vehicle': 'Vehicles', 'admin.import.type.sku': 'SKUs',
  'admin.import.download_template': 'Download CSV template', 'admin.import.choose_file': 'Choose file', 'admin.import.empty_file': 'File is empty',
  'admin.import.rows_detected': 'rows detected', 'admin.import.validate': 'Validate',
  'admin.import.valid': 'valid', 'admin.import.invalid': 'invalid',
  'admin.import.fix_these': 'Fix these {n} rows before importing', 'admin.import.show_valid': 'Show {n} valid rows',
  'admin.import.commit': 'Import {n} valid rows', 'admin.import.committed': 'Imported {n} rows',
  'admin.import.skipped': '{n} rows skipped', 'admin.import.import_another': 'Import another file',
  'admin.constraints.title': 'Constraints', 'admin.constraints.subtitle': 'Curfew zones and fuel stations — the two constraints the router respects',
  'admin.constraints.tab.curfews': 'Curfews', 'admin.constraints.tab.fuel': 'Fuel Stations',
  'admin.constraints.curfew.count': 'zones', 'admin.constraints.curfew.zones': 'Zones',
  'admin.constraints.curfew.none': 'No curfew zones yet — draw one on the map',
  'admin.constraints.curfew.draw': 'Draw new zone', 'admin.constraints.curfew.undo': 'Undo last',
  'admin.constraints.curfew.save_points': 'Save ({n} points)', 'admin.constraints.curfew.instructions': 'Click on the map to add points. 3 minimum.',
  'admin.constraints.curfew.points': 'points', 'admin.constraints.curfew.name': 'Zone name',
  'admin.constraints.curfew.start_hour': 'Start hour (0-23)', 'admin.constraints.curfew.end_hour': 'End hour (0-23)',
  'admin.constraints.curfew.hours_hint': 'Hours must be 0-23 and differ', 'admin.constraints.curfew.reason': 'Reason',
  'admin.constraints.curfew.save_title': 'Save curfew zone', 'admin.constraints.curfew.edit_title': 'Edit curfew hours',
  'admin.constraints.curfew.edit_hours': 'Edit hours', 'admin.constraints.curfew.active_now': 'Active now',
  'admin.constraints.curfew.scheduled': 'Scheduled', 'admin.constraints.curfew.inactive': 'Inactive',
  'admin.constraints.station.count': 'stations', 'admin.constraints.station.none': 'No fuel stations yet',
  'admin.constraints.station.name': 'Station name', 'admin.constraints.station.lat': 'Latitude', 'admin.constraints.station.lng': 'Longitude',
  'admin.constraints.station.status': 'Status',
  'admin.constraints.station.status.operational': 'Operational', 'admin.constraints.station.status.queued': 'Queued', 'admin.constraints.station.status.dry': 'Dry',
  'admin.constraints.station.add_title': 'Add fuel station',
});

Object.assign(am, {
  'warehouse.title': 'መጋዘን', 'warehouse.tab.dock': 'የመጫኛ ሰልፍ', 'warehouse.tab.pick': 'መምረጥ እና ማዘጋጀት',
  'warehouse.mode.kiosk': 'የኪዮስክ ሁነታ', 'warehouse.mode.normal': 'መደበኛ ሁነታ',
  'warehouse.dock.title': 'የመጫኛ ሰልፍ', 'warehouse.dock.subtitle': 'መጫን — ሁሉም ሸቀጦች ጭነው ሲጠናቀቁ ያረጋግጡ',
  'warehouse.dock.empty': 'አሁን ለመጫን ምንም የለም', 'warehouse.dock.empty_hint': 'አዲስ ማስያዣዎች እዚህ ይታያሉ።',
  'warehouse.dock.confirm_loading': 'መጫንን አረጋግጥ', 'warehouse.dock.pick_first': 'መጀመሪያ ሁሉንም ጣቢያዎች ይምረጡ',
  'warehouse.dock.picked_label': 'ተመርጧል', 'warehouse.dock.awaiting_dispatch': 'መጫን ተረጋግጧል — ለማመላለሻ በመጠባበቅ',
  'warehouse.pick.title': 'መምረጥ እና ማዘጋጀት', 'warehouse.pick.subtitle': 'በጣቢያ ቅደም ተከተል ይምረጡ',
  'warehouse.pick.routes_today': 'የዛሬ መንገዶች', 'warehouse.pick.select_route': 'መንገድ ይምረጡ',
  'warehouse.pick.no_routes': 'ዛሬ ለመምረጥ መንገድ የለም', 'warehouse.pick.no_routes_hint': 'ማመላለሻው ማስያዣ ሲመድብ ይታያሉ።',
  'warehouse.pick.no_stops': 'ጣቢያ የለውም', 'warehouse.pick.qty_ordered': 'የታዘዘ',
  'warehouse.pick.mark_picked': 'እንደተመረጠ ምልክት አድርግ', 'warehouse.pick.picked': 'ተመርጧል',
  'warehouse.pick.confirm_loading': 'መጫንን አረጋግጥ', 'warehouse.pick.cannot_confirm': 'ሁሉም ጣቢያዎች መመረጥ አለባቸው',
  'warehouse.pick.ready': 'ዝግጁ', 'warehouse.pick.pending': 'በመመረጥ ላይ',

  'admin.title': 'አስተዳዳሪ', 'admin.nav.masterdata': 'ዋና ውሂብ', 'admin.nav.constraints': 'ገደቦች',
  'admin.md.title': 'ዋና ውሂብ', 'admin.md.subtitle': 'አከፋፋዮች፣ ተሽከርካሪዎች፣ SKUዎች',
  'admin.md.tab.distributors': 'አከፋፋዮች', 'admin.md.tab.vehicles': 'ተሽከርካሪዎች', 'admin.md.tab.skus': 'SKUዎች', 'admin.md.tab.import': 'አስገባ',
  'admin.md.add': 'አዲስ ጨምር', 'admin.md.name': 'ስም', 'admin.md.region': 'ክልል', 'admin.md.status': 'ሁኔታ',
  'admin.md.active': 'ንቁ', 'admin.md.inactive': 'የቆመ', 'admin.md.deactivate': 'አቁም', 'admin.md.activate': 'አንቃ',
  'admin.md.plate': 'ታርጋ', 'admin.md.capacity_kg': 'አቅም (ኪግ)', 'admin.md.capacity_m3': 'አቅም (ሜ³)',
  'admin.md.baseline': 'መነሻ (L/100km)', 'admin.md.shift_start': 'የፈረቃ መጀመሪያ', 'admin.md.shift_end': 'የፈረቃ መጨረሻ',
  'admin.md.start_lat': 'መነሻ ላቲቲዩድ', 'admin.md.start_lng': 'መነሻ ሎንጊቲዩድ',
  'admin.md.code': 'ኮድ', 'admin.md.unit': 'መለኪያ', 'admin.md.weight_kg': 'ክብደት (ኪግ)', 'admin.md.volume_m3': 'መጠን (ሜ³)',
  'admin.md.reorder': 'የመደጋገሚያ ነጥብ', 'admin.md.safety': 'የደህንነት ክምችት', 'admin.md.lead_time': 'የመላኪያ ጊዜ (ቀናት)',
  'admin.md.distributors_count': 'አከፋፋዮች', 'admin.md.vehicles_count': 'ተሽከርካሪዎች', 'admin.md.skus_count': 'SKUዎች',
  'admin.md.no_distributors': 'እስካሁን አከፋፋይ የለም', 'admin.md.no_vehicles': 'እስካሁን ተሽከርካሪ የለም', 'admin.md.no_skus': 'እስካሁን SKU የለም',
  'admin.import.step1': 'ደረጃ 1 — ምን እያስገቡ ነው?', 'admin.import.step2': 'ደረጃ 2 — አብነቱን አውርዱ፣ ከዚያ ፋይልዎን ይስቀሉ',
  'admin.import.type.distributor': 'አከፋፋዮች', 'admin.import.type.vehicle': 'ተሽከርካሪዎች', 'admin.import.type.sku': 'SKUዎች',
  'admin.import.download_template': 'የCSV አብነት አውርድ', 'admin.import.choose_file': 'ፋይል ምረጥ', 'admin.import.empty_file': 'ፋይሉ ባዶ ነው',
  'admin.import.rows_detected': 'ረድፎች ተገኝተዋል', 'admin.import.validate': 'አረጋግጥ',
  'admin.import.valid': 'ትክክል', 'admin.import.invalid': 'ስህተት',
  'admin.import.fix_these': 'እነዚህን {n} ረድፎች ያስተካክሉ', 'admin.import.show_valid': '{n} ትክክለኛ ረድፎችን አሳይ',
  'admin.import.commit': '{n} ትክክለኛ ረድፎችን አስገባ', 'admin.import.committed': '{n} ረድፎች ገብተዋል',
  'admin.import.skipped': '{n} ረድፎች ተዘለዋል', 'admin.import.import_another': 'ሌላ ፋይል አስገባ',
  'admin.constraints.title': 'ገደቦች', 'admin.constraints.subtitle': 'የእገዳ አካባቢዎች እና የነዳጅ ጣቢያዎች',
  'admin.constraints.tab.curfews': 'እገዳዎች', 'admin.constraints.tab.fuel': 'የነዳጅ ጣቢያዎች',
  'admin.constraints.curfew.count': 'አካባቢዎች', 'admin.constraints.curfew.zones': 'አካባቢዎች',
  'admin.constraints.curfew.none': 'እስካሁን የእገዳ አካባቢ የለም', 'admin.constraints.curfew.draw': 'አዲስ አካባቢ ሳል',
  'admin.constraints.curfew.undo': 'የመጨረሻውን መልስ', 'admin.constraints.curfew.save_points': 'አስቀምጥ ({n} ነጥቦች)',
  'admin.constraints.curfew.instructions': 'በካርታ ላይ ይጫኑ ነጥቦችን ለመጨመር',
  'admin.constraints.curfew.points': 'ነጥቦች', 'admin.constraints.curfew.name': 'የአካባቢ ስም',
  'admin.constraints.curfew.start_hour': 'የመጀመሪያ ሰዓት (0-23)', 'admin.constraints.curfew.end_hour': 'የመጨረሻ ሰዓት (0-23)',
  'admin.constraints.curfew.hours_hint': 'ሰዓቶች 0–23 መሆን አለባቸው', 'admin.constraints.curfew.reason': 'ምክንያት',
  'admin.constraints.curfew.save_title': 'የእገዳ አካባቢ አስቀምጥ', 'admin.constraints.curfew.edit_title': 'የእገዳ ሰዓቶችን አርትዕ',
  'admin.constraints.curfew.edit_hours': 'ሰዓቶችን አርትዕ', 'admin.constraints.curfew.active_now': 'አሁን ንቁ',
  'admin.constraints.curfew.scheduled': 'የተያዘ', 'admin.constraints.curfew.inactive': 'የቆመ',
  'admin.constraints.station.count': 'ጣቢያዎች', 'admin.constraints.station.none': 'የነዳጅ ጣቢያ የለም',
  'admin.constraints.station.name': 'የጣቢያ ስም', 'admin.constraints.station.lat': 'ላቲቲዩድ', 'admin.constraints.station.lng': 'ሎንጊቲዩድ',
  'admin.constraints.station.status': 'ሁኔታ',
  'admin.constraints.station.status.operational': 'የሚሠራ', 'admin.constraints.station.status.queued': 'ተራ ላይ', 'admin.constraints.station.status.dry': 'ደርቋል',
  'admin.constraints.station.add_title': 'የነዳጅ ጣቢያ ጨምር',
});

fs.writeFileSync('packages/i18n/src/locales/en.json', JSON.stringify(en, null, 2) + '\n');
fs.writeFileSync('packages/i18n/src/locales/am.json', JSON.stringify(am, null, 2) + '\n');
console.log('  i18n keys updated (warehouse + admin)');
NODE

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Part 2b complete — Phases 4-5: warehouse + admin"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "What's now runnable:"
echo "  Backend: dispatch module (board, slots, dispatch) + masterdata module (distributors/vehicles/skus CRUD + bulk import)"
echo "  Warehouse-web: dock queue (kiosk mode) + pick & stage"
echo "  Admin-web: masterdata (4 tabs: Distributors, Vehicles, SKUs, Import) + constraints (curfew map editor + fuel stations)"
echo ""
echo "Setup (from repo root):"
echo "  pnpm install   # first time"
echo "  docker compose up -d mysql redis"
echo "  pnpm db:generate && pnpm db:migrate && pnpm db:seed"
echo ""
echo "Start three terminals:"
echo "  pnpm --filter @tera/api dev           # terminal 1"
echo "  pnpm --filter warehouse-web dev       # terminal 2 — http://localhost:5174"
echo "  pnpm --filter admin-web dev           # terminal 3 — http://localhost:5175"
echo ""
echo "What you can do in the warehouse console (5174):"
echo "  1. Dock Queue opens in kiosk mode (default)"
echo "     → V-102 slot is ALLOCATED with 0/4 picked (from seed)"
echo "     → Button disabled: 'Pick all stops first'"
echo "  2. Switch to Pick & Stage tab"
echo "     → Left: V-102 card showing 0/4 picked"
echo "     → Right: 4 stops (CMC Store, Bole Medhanialem, Megenagna Shop, Sarbet Retail)"
echo "  3. Tap 'Mark picked' on each stop → rows turn green, count increments"
echo "  4. At 4/4, 'Confirm loading' becomes enabled"
echo "  5. Click it → success"
echo "  6. Back to Dock Queue → V-102 now CONFIRMED (awaiting dispatcher)"
echo "  7. In dispatcher-web /board → V-102 slot now has 'Dispatch route' enabled"
echo "     → Click it → V-102 DISPATCHED, slot COMPLETED"
echo ""
echo "What you can do in the admin console (5175):"
echo "  MASTERDATA tab:"
echo "  1. Distributors → shows 5 seeded (all active), Add new works, Deactivate toggles"
echo "  2. Vehicles → shows 3 seeded, Add new with 8 fields, Deactivate works"
echo "  3. SKUs → shows 5 seeded (Coca-Cola, Pepsi, Ambo Water, Bread, Milk), Add new works"
echo "  4. Import → 3-step wizard: choose type → download template / upload file → validate → commit"
echo "     → Try: download distributor CSV, open in Excel, add 2 rows, upload, validate shows '2 valid', import"
echo ""
echo "  CONSTRAINTS tab:"
echo "  5. Curfews → map with 4 seeded zones (Merkato, Piassa, Bole, Old Airport inactive)"
echo "     → Right sidebar shows each zone with active/scheduled/inactive badge"
echo "     → Click 'Draw new zone' → click 3+ points on map → 'Save (N points)'"
echo "     → Modal opens → name + hours + reason → Confirm → zone appears"
echo "  6. Fuel Stations → 4 seeded (1 dry = Sarbet Shell), inline status dropdown per row"
echo "     → Change status → map dot color changes, table pill updates instantly"
echo "     → Add new station works"
echo ""
echo "  BULK IMPORT (the pilot's productivity multiplier):"
echo "  7. Import tab → Distributors type"
echo "  8. Click 'Download CSV template' → get distributor-template.csv"
echo "  9. Add 3 rows (name,region), save"
echo " 10. Upload → '4 rows detected. [Validate]'"
echo " 11. Validate → '4 valid / 0 invalid. [+ Show 4 valid rows]. [Cancel] [Import 4 valid rows]'"
echo " 12. Add a duplicate name row → re-validate → '1 invalid' shown in red"
echo " 13. Commit → 'Imported 3 rows'"
echo " 14. Distributors tab → 3 new distributors appear"
echo ""
echo "  Test a duplicate import:"
echo " 15. Re-run the same file → all 3 marked invalid ('already exists')"
echo "     → Server re-validates on commit — no trust in client"
echo ""
echo "Tests:"
echo "  pnpm --filter @tera/api test           # now 27 tests (was 23 + 4 masterdata)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📌 Build progress:"
echo "  ✓ Part 1a — Phase 0: Foundation"
echo "  ✓ Part 1b — Phases 1-2: Backend (credit, geo, orders, routing)"
echo "  ✓ Part 1c — Phase 2 FE: Dispatcher app"
echo "  ✓ Part 2a — Phase 3: Offline sync + Driver app"
echo "  ✓ Part 2b — Phases 4-5: Warehouse + Admin ← YOU ARE HERE"
echo ""
echo "📌 Next: Part 3 (Phases 6-9 — FINAL)"
echo "  • Phase 6: Exec dashboard + Finance console + Distributor portal"
echo "  • Phase 7: Optimizer process + Worker process (nightly jobs)"
echo "  • Phase 8: Audit + Notifications admin tabs"
echo "  • Phase 9: Monitoring + Final i18n consolidation + Smoke test"
echo ""
echo "After Part 3, the ENTIRE system is complete."
echo "All 8 frontends, 3 backend services, all modules."
echo ""
echo "Reply 'yes' to finish with Part 3."
echo "════════════════════════════════════════════════════════════════"


# ═══════════════════════════════════════════════════════════════════
# PHASE 6a — BACKEND: ANALYTICS (ROI computation)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 6a — analytics backend"

W services/api/src/modules/analytics/metrics.ts <<'EOF'
import type { Tile } from '@tera/contracts';

export interface MetricSpec {
  key: Tile['metric_key']; labelKey: string; unit: string;
  direction: 'up' | 'down'; targetMode: 'relative' | 'absolute';
  targetMin: number; targetMax: number;
}

export const METRIC_SPECS: MetricSpec[] = [
  { key: 'variable_cost_per_month_etb',       labelKey: 'exec.tile.variable_cost', unit: 'ETB',         direction: 'down', targetMode: 'relative', targetMin: 15, targetMax: 20 },
  { key: 'km_per_delivery',                    labelKey: 'exec.tile.km',            unit: 'km',          direction: 'down', targetMode: 'relative', targetMin: 10, targetMax: 15 },
  { key: 'median_delivery_hours',              labelKey: 'exec.tile.delivery_time', unit: 'h',           direction: 'down', targetMode: 'relative', targetMin: 15, targetMax: 35 },
  { key: 'on_time_sla_pct',                    labelKey: 'exec.tile.on_time',       unit: '%',           direction: 'up',   targetMode: 'relative', targetMin: 20, targetMax: 30 },
  { key: 'stockout_sku_days_per_month',        labelKey: 'exec.tile.stockout',      unit: 'SKU-days',    direction: 'down', targetMode: 'relative', targetMin: 25, targetMax: 40 },
  { key: 'dock_turnaround_minutes',            labelKey: 'exec.tile.dock',          unit: 'min',         direction: 'down', targetMode: 'relative', targetMin: 20, targetMax: 30 },
  { key: 'reserve_violations_per_100_routes',  labelKey: 'exec.tile.fuel_risk',     unit: '/100',        direction: 'down', targetMode: 'relative', targetMin: 10, targetMax: 25 },
  { key: 'deliveries_per_vehicle_per_day',     labelKey: 'exec.tile.fleet',         unit: 'del',         direction: 'up',   targetMode: 'relative', targetMin: 15, targetMax: 20 },
  { key: 'clean_epod_rate_pct',                labelKey: 'exec.tile.accuracy',      unit: '%',           direction: 'up',   targetMode: 'absolute', targetMin: 95, targetMax: 99 },
  { key: 'credit_blocked_pre_dispatch_pct',    labelKey: 'exec.tile.credit',        unit: '%',           direction: 'up',   targetMode: 'absolute', targetMin: 99, targetMax: 100 },
];

export interface Assumptions {
  monthlyDeliveries: number; monthlyRoutes: number; dailyVehicles: number;
  vehicleWearEtbPerKm: number; marginPerSkuDayEtb: number;
  costPerFuelIncidentEtb: number; avgMarginPerDeliveryEtb: number;
}

export const DEFAULT_ASSUMPTIONS: Assumptions = {
  monthlyDeliveries: 1200, monthlyRoutes: 120, dailyVehicles: 10,
  vehicleWearEtbPerKm: 3.5, marginPerSkuDayEtb: 500,
  costPerFuelIncidentEtb: 2000, avgMarginPerDeliveryEtb: 250,
};

export function computeImprovement(spec: MetricSpec, baseline: number, current: number): number {
  if (spec.targetMode === 'absolute') return spec.direction === 'up' ? current - baseline : baseline - current;
  if (baseline === 0) return 0;
  return spec.direction === 'up' ? ((current - baseline) / baseline) * 100 : ((baseline - current) / baseline) * 100;
}
export function isInTarget(spec: MetricSpec, baseline: number, current: number): boolean {
  if (spec.targetMode === 'absolute') return spec.direction === 'up' ? current >= spec.targetMin : current <= spec.targetMax;
  return computeImprovement(spec, baseline, current) >= spec.targetMin;
}
export function isFullyInTarget(spec: MetricSpec, baseline: number, current: number): boolean {
  if (spec.targetMode === 'absolute') return spec.direction === 'up' ? current >= spec.targetMax : current <= spec.targetMin;
  return computeImprovement(spec, baseline, current) >= spec.targetMax;
}
export function computeEtbImpact(spec: MetricSpec, baseline: number, current: number, a: Assumptions): number | null {
  switch (spec.key) {
    case 'variable_cost_per_month_etb': return Math.max(0, baseline - current);
    case 'km_per_delivery': return Math.max(0, baseline - current) * a.monthlyDeliveries * a.vehicleWearEtbPerKm;
    case 'stockout_sku_days_per_month': return Math.max(0, baseline - current) * a.marginPerSkuDayEtb;
    case 'reserve_violations_per_100_routes': return (Math.max(0, baseline - current) / 100) * a.monthlyRoutes * a.costPerFuelIncidentEtb;
    case 'deliveries_per_vehicle_per_day': return Math.max(0, current - baseline) * a.dailyVehicles * a.avgMarginPerDeliveryEtb * 30;
    default: return null;
  }
}
export function buildTile(spec: MetricSpec, baseline: number, current: number, trend: number[], assumptions: Assumptions): Tile {
  return {
    metric_key: spec.key, label_key: spec.labelKey, unit: spec.unit,
    baseline, current, target_min: spec.targetMin, target_max: spec.targetMax,
    direction: spec.direction, target_mode: spec.targetMode,
    improvement_pct: Math.round(computeImprovement(spec, baseline, current) * 100) / 100,
    in_target: isInTarget(spec, baseline, current),
    fully_in_target: isFullyInTarget(spec, baseline, current),
    trend_7d: trend,
    etb_impact: computeEtbImpact(spec, baseline, current, assumptions),
  };
}
export function computeHero(tiles: Tile[], baselineFrozenAt: Date, now: Date = new Date()) {
  const cost = tiles.find((t) => t.metric_key === 'variable_cost_per_month_etb');
  if (!cost || cost.etb_impact === null) return null;
  const days = Math.max(0, Math.floor((now.getTime() - baselineFrozenAt.getTime()) / 86_400_000));
  const monthly = cost.etb_impact;
  return { monthly_savings_etb: Math.round(monthly), cumulative_savings_etb: Math.round((monthly / 30) * days), annualized_savings_etb: Math.round(monthly * 12), days_since_baseline: days };
}
EOF

W services/api/src/modules/analytics/repository.ts <<'EOF'
import { db } from '@tera/db';
export const findBaselines = () => db().baseline.findMany();
export const upsertBaseline = (i: any) => db().baseline.upsert({ where: { key: i.key }, create: i, update: i });
export const getLatestSnapshot = (key: string) => db().metricSnapshot.findFirst({ where: { key }, orderBy: { date: 'desc' } });
export const getLastNDays = (key: string, n: number) => db().metricSnapshot.findMany({ where: { key }, orderBy: { date: 'desc' }, take: n });
export const getAssumptions = () => db().costAssumption.findMany();
export const upsertAssumption = (key: string, value: number, unit: string) => db().costAssumption.upsert({ where: { key }, create: { key, value, unit }, update: { value } });
export const getFlag = (key: string) => db().setting.findUnique({ where: { key } });
export const setFlag = (key: string, value: string) => db().setting.upsert({ where: { key }, create: { key, value }, update: { value } });
EOF

W services/api/src/modules/analytics/service.ts <<'EOF'
import type { DashboardResponse, Tile, CostAssumption, FreezeBaselineRequest } from '@tera/contracts';
import * as repo from './repository.js';
import { METRIC_SPECS, DEFAULT_ASSUMPTIONS, buildTile, computeHero, type Assumptions } from './metrics.js';

function assumptionsFromRows(rows: { key: string; value: number }[]): Assumptions {
  const m = new Map(rows.map((r) => [r.key, r.value]));
  return {
    monthlyDeliveries: m.get('monthly_deliveries') ?? DEFAULT_ASSUMPTIONS.monthlyDeliveries,
    monthlyRoutes: m.get('monthly_routes') ?? DEFAULT_ASSUMPTIONS.monthlyRoutes,
    dailyVehicles: m.get('daily_vehicles') ?? DEFAULT_ASSUMPTIONS.dailyVehicles,
    vehicleWearEtbPerKm: m.get('vehicle_wear_etb_per_km') ?? DEFAULT_ASSUMPTIONS.vehicleWearEtbPerKm,
    marginPerSkuDayEtb: m.get('margin_per_sku_day_etb') ?? DEFAULT_ASSUMPTIONS.marginPerSkuDayEtb,
    costPerFuelIncidentEtb: m.get('cost_per_fuel_incident_etb') ?? DEFAULT_ASSUMPTIONS.costPerFuelIncidentEtb,
    avgMarginPerDeliveryEtb: m.get('avg_margin_per_delivery_etb') ?? DEFAULT_ASSUMPTIONS.avgMarginPerDeliveryEtb,
  };
}
async function isDemoMode() { const r = await repo.getFlag('analytics.demoMode'); return r?.value === 'true'; }

export async function getDashboard(): Promise<DashboardResponse> {
  const [baselineRows, assumptionRows, demoMode] = await Promise.all([repo.findBaselines(), repo.getAssumptions(), isDemoMode()]);
  if (baselineRows.length === 0) return { as_of: new Date().toISOString(), baseline_frozen_at: null, is_demo: demoMode, hero: null, tiles: [] };
  const assumptions = assumptionsFromRows(assumptionRows);
  const baselineMap = new Map(baselineRows.map((b) => [b.key, b]));
  const frozenAt = baselineRows[0]!.frozenAt;
  const tiles: Tile[] = [];
  for (const spec of METRIC_SPECS) {
    const b = baselineMap.get(spec.key); if (!b) continue;
    const current = await repo.getLatestSnapshot(spec.key); if (!current) continue;
    const trendRows = await repo.getLastNDays(spec.key, 7);
    const trend = trendRows.slice().reverse().map((r) => Math.round(r.value * 100) / 100);
    tiles.push(buildTile(spec, b.value, current.value, trend, assumptions));
  }
  return { as_of: new Date().toISOString(), baseline_frozen_at: frozenAt.toISOString(), is_demo: demoMode, hero: computeHero(tiles, frozenAt), tiles };
}

export async function freezeBaseline(input: FreezeBaselineRequest, actorId: string): Promise<DashboardResponse> {
  for (const spec of METRIC_SPECS) {
    const current = await repo.getLatestSnapshot(spec.key);
    if (!current) continue;
    await repo.upsertBaseline({ key: spec.key, value: current.value, unit: spec.unit, notes: input.notes ?? null, frozenAt: new Date(), frozenBy: actorId });
  }
  await repo.setFlag('analytics.demoMode', 'false');
  return getDashboard();
}

export async function listAssumptions(): Promise<{ assumptions: CostAssumption[] }> {
  const rows = await repo.getAssumptions();
  return { assumptions: rows.map((r) => ({ key: r.key, value: r.value, unit: r.unit, updated_at: r.updatedAt.toISOString() })) };
}
export async function updateAssumption(key: string, value: number): Promise<CostAssumption> {
  const existing = await repo.getAssumptions();
  const cur = existing.find((r) => r.key === key);
  if (!cur) { const e = new Error(`assumption "${key}" not found`) as any; e.statusCode = 404; throw e; }
  const u = await repo.upsertAssumption(key, value, cur.unit);
  return { key: u.key, value: u.value, unit: u.unit, updated_at: u.updatedAt.toISOString() };
}
EOF

W services/api/src/modules/analytics/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { DashboardResponseSchema, FreezeBaselineRequestSchema, CostAssumptionsResponseSchema, UpdateCostAssumptionSchema, CostAssumptionSchema } from '@tera/contracts';
import * as s from './service.js';
export const analyticsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/dashboard', { schema: { response: { 200: DashboardResponseSchema as any } } }, async () => s.getDashboard());
  app.post('/baseline/freeze', { schema: { body: FreezeBaselineRequestSchema as any, response: { 200: DashboardResponseSchema as any } } },
    async (req: any) => s.freezeBaseline(req.body ?? {}, req.user?.sub ?? 'admin'));
  app.get('/cost-assumptions', { schema: { response: { 200: CostAssumptionsResponseSchema as any } } }, async () => s.listAssumptions());
  app.patch('/cost-assumptions/:key', { schema: { body: UpdateCostAssumptionSchema as any, response: { 200: CostAssumptionSchema as any } } },
    async (req: any) => s.updateAssumption(req.params.key, req.body.value));
};
EOF
W services/api/src/modules/analytics/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { analyticsRoutes } from './routes.js';
export const analyticsPlugin: FastifyPluginAsync = async (app) => { await app.register(analyticsRoutes); };
export default analyticsPlugin;
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 6b — BACKEND: PAYMENTS (reconciliation)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 6b — payments backend"

W services/api/src/modules/payments/rules.ts <<'EOF'
export function canReconcile(input: { reconciledAt: string | null }) {
  if (input.reconciledAt !== null) return { allowed: false, reason: 'already reconciled' };
  return { allowed: true, reason: null };
}
EOF
W services/api/src/modules/payments/repository.ts <<'EOF'
import { db } from '@tera/db';
export function findUnreconciled(limit: number) { return db().payment.findMany({ where: { reconciledAt: null }, orderBy: { receivedAt: 'desc' }, take: limit }); }
export function findRouteStopsByIds(ids: string[]) { return db().routeStop.findMany({ where: { id: { in: ids } }, include: { routePlan: { select: { driverId: true, vehicleId: true } } } }); }
export function findById(id: string) { return db().payment.findUnique({ where: { id } }); }
export function reconcile(id: string, actorId: string, notes: string | null) {
  return db().payment.update({ where: { id }, data: { reconciledAt: new Date(), reconciledBy: actorId, reconcileNotes: notes } });
}
EOF
W services/api/src/modules/payments/service.ts <<'EOF'
import type { UnreconciledPaymentsResponse, ReconcileResponse } from '@tera/contracts';
import * as repo from './repository.js';
import { canReconcile } from './rules.js';
import { writeAudit } from '../../core/audit.js';
export async function listUnreconciled(limit = 100): Promise<UnreconciledPaymentsResponse> {
  const rows = await repo.findUnreconciled(limit);
  const stops = await repo.findRouteStopsByIds(Array.from(new Set(rows.map((r) => r.routeStopId))));
  const byId = new Map(stops.map((s) => [s.id, s]));
  return { total: rows.length, payments: rows.map((p) => {
    const s = byId.get(p.routeStopId);
    return { id: p.id, route_stop_id: p.routeStopId, driver_id: s?.routePlan.driverId ?? '?', vehicle_id: s?.routePlan.vehicleId ?? '?', distributor_name: s?.distributorName ?? '(unknown)', method: p.method as 'CASH'|'TELEBIRR', amount_etb: Number(p.amountEtb), telebirr_ref: p.telebirrRef, captured_at: p.capturedAt.toISOString() };
  }) };
}
export async function reconcile(id: string, actorId: string, notes: string | null): Promise<ReconcileResponse> {
  const payment = await repo.findById(id);
  if (!payment) { const e = new Error('not found') as any; e.statusCode = 404; throw e; }
  const gate = canReconcile({ reconciledAt: payment.reconciledAt?.toISOString() ?? null });
  if (!gate.allowed) { const e = new Error(gate.reason!) as any; e.statusCode = 400; throw e; }
  const updated = await repo.reconcile(id, actorId, notes);
  await writeAudit({ actorId, entity: 'payment', entityId: id, action: 'reconciled', reason: notes?.trim() || `${payment.method} payment reconciled`, meta: { amountEtb: Number(payment.amountEtb), method: payment.method } });
  return { ok: true, reconciled_at: updated.reconciledAt!.toISOString() };
}
EOF
W services/api/src/modules/payments/schemas.ts <<'EOF'
export { UnreconciledPaymentsResponseSchema, ReconcileRequestSchema, ReconcileResponseSchema } from '@tera/contracts';
EOF
W services/api/src/modules/payments/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { UnreconciledPaymentsResponseSchema, ReconcileRequestSchema, ReconcileResponseSchema } from './schemas.js';
import * as s from './service.js';
export const paymentsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/unreconciled', { schema: { response: { 200: UnreconciledPaymentsResponseSchema as any } } },
    async (req: any) => s.listUnreconciled(req.query?.limit ? parseInt(req.query.limit, 10) : 100));
  app.post('/:id/reconcile', { schema: { body: ReconcileRequestSchema as any, response: { 200: ReconcileResponseSchema as any } } },
    async (req: any) => s.reconcile(req.params.id, req.user?.sub ?? 'finance', req.body?.notes ?? null));
};
EOF
W services/api/src/modules/payments/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { paymentsRoutes } from './routes.js';
export const paymentsPlugin: FastifyPluginAsync = async (app) => { await app.register(paymentsRoutes); };
export default paymentsPlugin;
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 6c — BACKEND: PORTAL (distributor self-service)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 6c — portal backend"

W services/api/src/modules/portal/cart.ts <<'EOF'
export interface CartLine { skuId: string; quantity: number; unitPrice: number; weightKg: number; volumeM3: number; }
export function computeCartTotals(lines: CartLine[]) {
  let q = 0, s = 0, w = 0, v = 0;
  for (const l of lines) { q += l.quantity; s += l.quantity * l.unitPrice; w += l.quantity * l.weightKg; v += l.quantity * l.volumeM3; }
  return { lineCount: lines.length, totalQuantity: q, subtotalEtb: Math.round(s * 100) / 100, totalWeightKg: Math.round(w * 100) / 100, totalVolumeM3: Math.round(v * 1000) / 1000 };
}
export function computeHeadroom(input: { limitEtb: number; exposureEtb: number; cartSubtotalEtb: number }) {
  const headroom = Math.max(0, input.limitEtb - input.exposureEtb);
  const after = headroom - input.cartSubtotalEtb;
  return { headroomEtb: Math.round(headroom * 100) / 100, afterOrderEtb: Math.round(after * 100) / 100, wouldExceed: after < 0 };
}
EOF
W services/api/src/modules/portal/repository.ts <<'EOF'
import { db } from '@tera/db';
export const findDistributorWithCredit = (id: string) => db().distributor.findUnique({ where: { id }, include: { creditAccounts: true } });
export const findActiveSkus = () => db().sku.findMany({ where: { active: true }, orderBy: { code: 'asc' } });
export const findSkuByIds = (ids: string[]) => db().sku.findMany({ where: { id: { in: ids } } });
export const findOrdersByDistributor = (id: string) => db().order.findMany({ where: { distributorId: id }, include: { lines: true }, orderBy: { createdAt: 'desc' }, take: 50 });
export const findOrderByIdAndDistributor = (orderId: string, distId: string) => db().order.findFirst({ where: { id: orderId, distributorId: distId }, include: { lines: true } });
export const findRouteStopByOrderId = (orderId: string) => db().routeStop.findFirst({ where: { orderId }, include: { routePlan: { select: { driverId: true, vehicleId: true, status: true } } } });
export const findRecentDeliveries = (distId: string, limit: number) => db().routeStop.findMany({ where: { distributorId: distId, status: 'DELIVERED' }, include: { routePlan: { select: { vehicleId: true } } }, orderBy: { statusUpdatedAt: 'desc' }, take: limit });
export const findDisputes = (distId: string) => db().dispute.findMany({ where: { distributorId: distId }, orderBy: { createdAt: 'desc' } });
export const findLatestProofForOrder = (orderId: string) => db().proofOfDelivery.findFirst({ where: { orderId }, orderBy: { capturedAt: 'desc' } });
export async function createOrderWithLines(input: any) {
  const now = new Date();
  return db().order.create({ data: {
    distributorId: input.distributorId, distributorName: input.distributorName,
    lat: input.lat, lng: input.lng, weightKg: input.weightKg, volumeM3: input.volumeM3,
    priority: 5, timeWindowStart: new Date(now.getTime() + 3600_000), timeWindowEnd: new Date(now.getTime() + 86_400_000),
    status: 'PENDING', totalQuantity: input.totalQuantity,
    lines: { create: input.lines },
  }, include: { lines: true } });
}
export const createDispute = (input: any) => db().dispute.create({ data: input });
EOF
W services/api/src/modules/portal/service.ts <<'EOF'
import type { PortalProfile, CatalogItem, PlaceOrderRequest, PlaceOrderResponse, PortalOrdersResponse, PortalOrderSummary, PortalOrderDetail, StatementResponse, DisputeRow, RaiseDisputeRequest } from '@tera/contracts';
import * as repo from './repository.js';
import { computeCartTotals, computeHeadroom, type CartLine } from './cart.js';

const r2 = (n: number) => Math.round(n * 100) / 100;
const DEFAULT_LAT = 9.0108; const DEFAULT_LNG = 38.7613;

export async function getProfile(distId: string): Promise<PortalProfile> {
  const d = await repo.findDistributorWithCredit(distId);
  if (!d) { const e = new Error('distributor not found') as any; e.statusCode = 404; throw e; }
  const a = d.creditAccounts[0];
  const limit = a ? Number(a.limitEtb) : 0; const exposure = a ? Number(a.exposureEtb) : 0;
  return { distributor_id: d.id, name: d.name, region: d.region, credit_limit_etb: r2(limit), exposure_etb: r2(exposure), headroom_etb: r2(Math.max(0, limit - exposure)), utilization_pct: limit > 0 ? r2((exposure / limit) * 100) : 0 };
}
export async function getCatalog(): Promise<{ items: CatalogItem[] }> {
  const skus = await repo.findActiveSkus();
  return { items: skus.map((s) => ({ sku_id: s.id, code: s.code, name: s.name, unit: s.unit, weight_kg: Number(s.weightKg), volume_m3: Number(s.volumeM3), unit_price_etb: Number(s.unitPriceEtb), stock_on_hand: s.stockOnHand })) };
}
export async function placeOrder(distId: string, input: PlaceOrderRequest): Promise<PlaceOrderResponse> {
  const profile = await getProfile(distId);
  const skus = await repo.findSkuByIds(input.lines.map((l) => l.sku_id));
  const byId = new Map(skus.map((s) => [s.id, s]));
  const cartLines: CartLine[] = [];
  for (const l of input.lines) {
    const sku = byId.get(l.sku_id);
    if (!sku) { const e = new Error(`unknown SKU ${l.sku_id}`) as any; e.statusCode = 400; throw e; }
    if (sku.stockOnHand <= 0) { const e = new Error(`${sku.name} is out of stock`) as any; e.statusCode = 400; throw e; }
    if (l.quantity > sku.stockOnHand) { const e = new Error(`${sku.name}: only ${sku.stockOnHand} in stock`) as any; e.statusCode = 400; throw e; }
    cartLines.push({ skuId: sku.id, quantity: l.quantity, unitPrice: Number(sku.unitPriceEtb), weightKg: Number(sku.weightKg), volumeM3: Number(sku.volumeM3) });
  }
  const totals = computeCartTotals(cartLines);
  const headroom = computeHeadroom({ limitEtb: profile.credit_limit_etb, exposureEtb: profile.exposure_etb, cartSubtotalEtb: totals.subtotalEtb });
  if (headroom.wouldExceed) { const e = new Error(`Order exceeds credit headroom. Cart: ${totals.subtotalEtb} ETB, Headroom: ${headroom.headroomEtb} ETB`) as any; e.statusCode = 400; throw e; }
  const d = await repo.findDistributorWithCredit(distId);
  const lat = d?.lat ? Number(d.lat) : DEFAULT_LAT; const lng = d?.lng ? Number(d.lng) : DEFAULT_LNG;
  const order = await repo.createOrderWithLines({
    distributorId: distId, distributorName: profile.name, lat, lng,
    weightKg: totals.totalWeightKg, volumeM3: totals.totalVolumeM3, totalQuantity: totals.totalQuantity,
    lines: cartLines.map((c) => { const s = byId.get(c.skuId)!; return { skuId: c.skuId, skuCode: s.code, skuName: s.name, quantity: c.quantity, unitPrice: c.unitPrice, lineTotal: r2(c.quantity * c.unitPrice) }; }),
  });
  return { order_id: order.id, status: order.status, total_etb: totals.subtotalEtb, total_quantity: totals.totalQuantity, eta: null };
}
function mapStatus(oStatus: string, stopStatus: string | null | undefined): PortalOrderSummary['status'] {
  if (oStatus === 'DELIVERED') return 'DELIVERED';
  if (stopStatus === 'DELIVERED') return 'DELIVERED';
  if (stopStatus === 'FAILED') return 'FAILED';
  if (stopStatus) return 'ROUTED';
  return 'PENDING';
}
export async function listOrders(distId: string): Promise<PortalOrdersResponse> {
  const rows = await repo.findOrdersByDistributor(distId);
  const active: PortalOrderSummary[] = []; const recent: PortalOrderSummary[] = [];
  for (const o of rows) {
    const total = o.lines.reduce((s, l) => s + Number(l.lineTotal), 0);
    const stop = await repo.findRouteStopByOrderId(o.id);
    const s: PortalOrderSummary = { order_id: o.id, status: mapStatus(o.status, stop?.status), created_at: o.createdAt.toISOString(), total_etb: r2(total), total_quantity: o.totalQuantity, line_count: o.lines.length, eta: stop ? stop.plannedEta.toISOString() : null, vehicle_id: stop?.routePlan.vehicleId ?? null, last_stop_status: stop?.status ?? null };
    if (s.status === 'PENDING' || s.status === 'ROUTED') active.push(s); else recent.push(s);
  }
  return { active, recent };
}
export async function getOrderDetail(distId: string, orderId: string): Promise<PortalOrderDetail> {
  const o = await repo.findOrderByIdAndDistributor(orderId, distId);
  if (!o) { const e = new Error('order not found') as any; e.statusCode = 404; throw e; }
  const stop = await repo.findRouteStopByOrderId(orderId);
  return { order_id: o.id, status: mapStatus(o.status, stop?.status), created_at: o.createdAt.toISOString(), total_etb: r2(o.lines.reduce((s, l) => s + Number(l.lineTotal), 0)), total_quantity: o.totalQuantity, line_count: o.lines.length, eta: stop ? stop.plannedEta.toISOString() : null, vehicle_id: stop?.routePlan.vehicleId ?? null, driver_id: stop?.routePlan.driverId ?? null, route_stop_id: stop?.id ?? null, last_stop_status: stop?.status ?? null, lines: o.lines.map((l) => ({ sku_id: l.skuId, sku_code: l.skuCode, sku_name: l.skuName, quantity: l.quantity, unit_price_etb: Number(l.unitPrice), line_total_etb: Number(l.lineTotal) })) };
}
export async function getStatement(distId: string): Promise<StatementResponse> {
  const d = await repo.findDistributorWithCredit(distId);
  if (!d) { const e = new Error('distributor not found') as any; e.statusCode = 404; throw e; }
  const a = d.creditAccounts[0];
  const limit = a ? Number(a.limitEtb) : 0; const exposure = a ? Number(a.exposureEtb) : 0;
  const oldest = a?.oldestUnpaidAt ?? null;
  const days = oldest ? Math.floor((Date.now() - oldest.getTime()) / 86_400_000) : null;
  const deliveries = await repo.findRecentDeliveries(distId, 10);
  return { as_of: new Date().toISOString(), balance_etb: r2(exposure), limit_etb: r2(limit), grace_days: a?.graceDays ?? 14, days_since_oldest_unpaid: days, recent_payments: [], recent_deliveries: deliveries.map((s) => ({ order_id: s.orderId ?? s.id, delivered_at: s.statusUpdatedAt.toISOString(), total_quantity: s.quantityOrdered, vehicle_id: s.routePlan.vehicleId })) };
}
export async function raiseDispute(distId: string, input: RaiseDisputeRequest): Promise<DisputeRow> {
  const o = await repo.findOrderByIdAndDistributor(input.order_id, distId);
  if (!o) { const e = new Error('order not found for this distributor') as any; e.statusCode = 404; throw e; }
  const proof = await repo.findLatestProofForOrder(input.order_id);
  const d = await repo.createDispute({ orderId: input.order_id, distributorId: distId, type: input.type, description: input.description, proofId: proof?.id ?? null });
  return { id: d.id, order_id: d.orderId, type: d.type as any, description: d.description, status: d.status as any, created_at: d.createdAt.toISOString(), resolution_notes: d.resolutionNotes };
}
export async function listDisputes(distId: string): Promise<{ disputes: DisputeRow[] }> {
  const rows = await repo.findDisputes(distId);
  return { disputes: rows.map((d) => ({ id: d.id, order_id: d.orderId, type: d.type as any, description: d.description, status: d.status as any, created_at: d.createdAt.toISOString(), resolution_notes: d.resolutionNotes })) };
}
EOF
W services/api/src/modules/portal/context.ts <<'EOF'
export function getDistributorId(req: any): string {
  const id = req.headers['x-distributor-id'];
  if (!id || typeof id !== 'string') { const e = new Error('X-Distributor-Id header required') as any; e.statusCode = 401; throw e; }
  return id;
}
EOF
W services/api/src/modules/portal/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { PortalProfileSchema, CatalogResponseSchema, PlaceOrderRequestSchema, PlaceOrderResponseSchema, PortalOrdersResponseSchema, PortalOrderDetailSchema, StatementResponseSchema, RaiseDisputeRequestSchema, DisputesListResponseSchema } from '@tera/contracts';
import * as s from './service.js';
import { getDistributorId } from './context.js';
export const portalRoutes: FastifyPluginAsync = async (app) => {
  app.get('/me', { schema: { response: { 200: PortalProfileSchema as any } } }, async (req: any) => s.getProfile(getDistributorId(req)));
  app.get('/catalog', { schema: { response: { 200: CatalogResponseSchema as any } } }, async () => s.getCatalog());
  app.post('/orders', { schema: { body: PlaceOrderRequestSchema as any, response: { 200: PlaceOrderResponseSchema as any } } }, async (req: any) => s.placeOrder(getDistributorId(req), req.body));
  app.get('/orders', { schema: { response: { 200: PortalOrdersResponseSchema as any } } }, async (req: any) => s.listOrders(getDistributorId(req)));
  app.get('/orders/:id', { schema: { response: { 200: PortalOrderDetailSchema as any } } }, async (req: any) => s.getOrderDetail(getDistributorId(req), req.params.id));
  app.get('/statements', { schema: { response: { 200: StatementResponseSchema as any } } }, async (req: any) => s.getStatement(getDistributorId(req)));
  app.post('/disputes', { schema: { body: RaiseDisputeRequestSchema as any, response: { 200: DisputesListResponseSchema as any } } }, async (req: any) => { await s.raiseDispute(getDistributorId(req), req.body); return s.listDisputes(getDistributorId(req)); });
  app.get('/disputes', { schema: { response: { 200: DisputesListResponseSchema as any } } }, async (req: any) => s.listDisputes(getDistributorId(req)));
};
EOF
W services/api/src/modules/portal/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { portalRoutes } from './routes.js';
export const portalPlugin: FastifyPluginAsync = async (app) => { await app.register(portalRoutes); };
export default portalPlugin;
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 6d — BACKEND: AUDIT + NOTIFY
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 6d — audit + notify backends"

W services/api/src/modules/audit/repository.ts <<'EOF'
import { db } from '@tera/db';
export function findEntries(input: { entity?: string; actor?: string; limit: number }) {
  return db().auditLog.findMany({ where: { ...(input.entity ? { entity: input.entity } : {}), ...(input.actor ? { actorId: input.actor } : {}) }, orderBy: { createdAt: 'desc' }, take: input.limit });
}
EOF
W services/api/src/modules/audit/service.ts <<'EOF'
import type { AuditListResponse, AuditLogEntry } from '@tera/contracts';
import * as repo from './repository.js';
export async function listAudit(input: { entity?: string; actor?: string; limit: number }): Promise<AuditListResponse> {
  const rows = await repo.findEntries(input);
  return { total: rows.length, entries: rows.map(toEntry) };
}
function toEntry(row: any): AuditLogEntry {
  return { id: row.id, actor_id: row.actorId, entity: row.entity, entity_id: row.entityId, action: row.action, reason: row.reason, meta: row.metaJson as any, created_at: row.createdAt.toISOString() };
}
EOF
W services/api/src/modules/audit/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { AuditListResponseSchema } from '@tera/contracts';
import * as s from './service.js';
export const auditRoutes: FastifyPluginAsync = async (app) => {
  app.get('/log', { schema: { response: { 200: AuditListResponseSchema as any } } }, async (req: any) => s.listAudit({ entity: req.query?.entity, actor: req.query?.actor, limit: req.query?.limit ? parseInt(req.query.limit, 10) : 100 }));
};
EOF
W services/api/src/modules/audit/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { auditRoutes } from './routes.js';
export const auditPlugin: FastifyPluginAsync = async (app) => { await app.register(auditRoutes); };
export default auditPlugin;
EOF

W services/api/src/modules/notify/templates.ts <<'EOF'
export interface NotificationTemplate { key: string; labelKey: string; channelHint: 'sms'|'telegram'|'email'|'any'; body: string; }
export const TEMPLATES: NotificationTemplate[] = [
  { key: 'test', labelKey: 'notify.template.test', channelHint: 'any', body: 'Tera OMS test notification at {time}. If you can read this, the {channel} adapter works.' },
  { key: 'eta_alert', labelKey: 'notify.template.eta_alert', channelHint: 'sms', body: 'Hi {name}, your delivery {order_id} is on the way and should arrive around {eta}.' },
  { key: 'order_confirmed', labelKey: 'notify.template.order_confirmed', channelHint: 'sms', body: 'Order {order_id} confirmed: {n} items, {total} ETB.' },
  { key: 'delivery_completed', labelKey: 'notify.template.delivery_completed', channelHint: 'sms', body: 'Delivery {order_id} completed at {time}.' },
];
export const findTemplate = (k: string) => TEMPLATES.find((t) => t.key === k) ?? null;
export function renderTemplate(body: string, vars: Record<string, string>): string {
  return body.replace(/\{(\w+)\}/g, (_, k) => (k in vars ? vars[k]! : `{${k}}`));
}
EOF
W services/api/src/modules/notify/adapters.ts <<'EOF'
export type Channel = 'sms' | 'telegram' | 'email';
export interface SendResult { ok: boolean; providerRef: string | null; error: string | null; stub: boolean; }
function fakeRef(p: string) { return `${p}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`; }
async function sendSms(r: string, b: string): Promise<SendResult> { console.log(`[SMS STUB] → ${r}\n  ${b}`); return { ok: true, providerRef: fakeRef('sms'), error: null, stub: true }; }
async function sendTg(r: string, b: string): Promise<SendResult> { console.log(`[TELEGRAM STUB] → ${r}\n  ${b}`); return { ok: true, providerRef: fakeRef('tg'), error: null, stub: true }; }
async function sendEmail(r: string, b: string): Promise<SendResult> { console.log(`[EMAIL STUB] → ${r}\n  ${b}`); return { ok: true, providerRef: fakeRef('email'), error: null, stub: true }; }
export async function sendViaChannel(c: Channel, r: string, b: string): Promise<SendResult> {
  switch (c) { case 'sms': return sendSms(r, b); case 'telegram': return sendTg(r, b); case 'email': return sendEmail(r, b); }
}
EOF
W services/api/src/modules/notify/repository.ts <<'EOF'
import { db } from '@tera/db';
export const createLog = (i: any) => db().notificationLog.create({ data: i });
export function findLogs(input: { channel?: string; status?: string; limit: number }) {
  return db().notificationLog.findMany({ where: { ...(input.channel ? { channel: input.channel } : {}), ...(input.status ? { status: input.status } : {}) }, orderBy: { sentAt: 'desc' }, take: input.limit });
}
EOF
W services/api/src/modules/notify/service.ts <<'EOF'
import type { NotificationLogEntry, NotificationListResponse, SendNotificationRequest, SendNotificationResponse, TestSendRequest } from '@tera/contracts';
import * as repo from './repository.js';
import { TEMPLATES, findTemplate, renderTemplate } from './templates.js';
import { sendViaChannel, type Channel } from './adapters.js';
import { writeAudit } from '../../core/audit.js';
export async function sendNotification(input: SendNotificationRequest, actorId: string): Promise<SendNotificationResponse> {
  const t = findTemplate(input.template_key);
  if (!t) { const e = new Error(`unknown template "${input.template_key}"`) as any; e.statusCode = 400; throw e; }
  const body = renderTemplate(t.body, { ...input.vars, channel: input.channel });
  let r; try { r = await sendViaChannel(input.channel as Channel, input.recipient, body); } catch (err) { r = { ok: false, providerRef: null, error: err instanceof Error ? err.message : String(err), stub: true }; }
  const status = r.ok ? (r.stub ? 'STUB' : 'SENT') : 'FAILED';
  const log = await repo.createLog({ channel: input.channel, recipient: input.recipient, templateKey: input.template_key, renderedBody: body, status, providerRef: r.providerRef, error: r.error });
  await writeAudit({ actorId, entity: 'notification', entityId: log.id, action: 'sent', reason: `${input.channel} → ${input.recipient} (${input.template_key})`, meta: { status, providerRef: r.providerRef } });
  return { id: log.id, status: status as any, provider_ref: r.providerRef };
}
export async function sendTest(input: TestSendRequest, actorId: string) {
  return sendNotification({ channel: input.channel, recipient: input.recipient, template_key: 'test', vars: { time: new Date().toLocaleString(), channel: input.channel } }, actorId);
}
export async function listNotifications(input: { channel?: string; status?: string; limit: number }): Promise<NotificationListResponse> {
  const rows = await repo.findLogs(input);
  return { total: rows.length, entries: rows.map((r) => ({ id: r.id, channel: r.channel as any, recipient: r.recipient, template_key: r.templateKey, rendered_body: r.renderedBody, status: r.status as any, provider_ref: r.providerRef, error: r.error, sent_at: r.sentAt.toISOString() })) };
}
export function listTemplates() { return { templates: TEMPLATES.map((t) => ({ key: t.key, label_key: t.labelKey, channel_hint: t.channelHint })) }; }
EOF
W services/api/src/modules/notify/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { NotificationListResponseSchema, SendNotificationRequestSchema, SendNotificationResponseSchema, TestSendRequestSchema } from '@tera/contracts';
import * as s from './service.js';
export const notifyRoutes: FastifyPluginAsync = async (app) => {
  app.get('/log', { schema: { response: { 200: NotificationListResponseSchema as any } } }, async (req: any) => s.listNotifications({ channel: req.query?.channel, status: req.query?.status, limit: req.query?.limit ? parseInt(req.query.limit, 10) : 100 }));
  app.get('/templates', async () => s.listTemplates());
  app.post('/send', { schema: { body: SendNotificationRequestSchema as any, response: { 200: SendNotificationResponseSchema as any } } }, async (req: any) => s.sendNotification(req.body, req.user?.sub ?? 'admin'));
  app.post('/test', { schema: { body: TestSendRequestSchema as any, response: { 200: SendNotificationResponseSchema as any } } }, async (req: any) => s.sendTest(req.body, req.user?.sub ?? 'admin'));
};
EOF
W services/api/src/modules/notify/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { notifyRoutes } from './routes.js';
export const notifyPlugin: FastifyPluginAsync = async (app) => { await app.register(notifyRoutes); };
export default notifyPlugin;
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 6e — BACKEND: ADMIN JOBS + MONITORING
# ═══════════════════════════════════════════════════════════════════
echo "▸ Phase 6e — admin/jobs + monitoring backends"

W services/api/src/modules/admin/jobs/queue.ts <<'EOF'
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
const NAME = 'worker-jobs';
let redis: IORedis | null = null; let q: Queue | null = null;
function getRedis() { if (!redis) { redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null, enableReadyCheck: false }); } return redis; }
export function getQueue(): Queue { if (!q) q = new Queue(NAME, { connection: getRedis() }); return q; }
export async function enqueueJob(jobKey: string, triggeredBy: string): Promise<void> {
  await getQueue().add(jobKey, { triggeredBy }, { removeOnComplete: { age: 3600, count: 100 }, removeOnFail: { age: 86_400, count: 100 } });
}
EOF
W services/api/src/modules/admin/jobs/repository.ts <<'EOF'
import { db } from '@tera/db';
export const findRecentRuns = (limit: number) => db().jobRun.findMany({ orderBy: { startedAt: 'desc' }, take: limit });
export const findLatestForJob = (jobKey: string) => db().jobRun.findFirst({ where: { jobKey }, orderBy: { startedAt: 'desc' } });
EOF
W services/api/src/modules/admin/jobs/service.ts <<'EOF'
import type { JobRun, JobRunsResponse, JobScheduleEntry, JobScheduleResponse, JobKey } from '@tera/contracts';
import * as repo from './repository.js';
import { enqueueJob } from './queue.js';
const SCHEDULE: { key: JobKey; labelKey: string; schedule: string }[] = [
  { key: 'metric_snapshot', labelKey: 'jobs.job.metric_snapshot', schedule: '0 22 * * *' },
  { key: 'credit_rebuild', labelKey: 'jobs.job.credit_rebuild', schedule: '15 22 * * *' },
  { key: 'fuel_variance', labelKey: 'jobs.job.fuel_variance', schedule: '30 22 * * *' },
];
export async function listRuns(limit = 50): Promise<JobRunsResponse> {
  const rows = await repo.findRecentRuns(limit);
  return { total: rows.length, runs: rows.map(toRun) };
}
export async function listSchedule(): Promise<JobScheduleResponse> {
  const jobs: JobScheduleEntry[] = [];
  for (const s of SCHEDULE) {
    const last = await repo.findLatestForJob(s.key);
    jobs.push({ job_key: s.key, label_key: s.labelKey, schedule: s.schedule, next_run_at: computeNextRun(s.schedule), last_run: last ? toRun(last) : null });
  }
  return { jobs };
}
export async function runNow(key: JobKey, actorId: string): Promise<void> { await enqueueJob(key, `manual:${actorId}`); }
function toRun(row: any): JobRun {
  return { id: row.id, job_key: row.jobKey, status: row.status, started_at: row.startedAt.toISOString(), finished_at: row.finishedAt?.toISOString() ?? null, duration_ms: row.durationMs, processed_count: row.processedCount, skipped_count: row.skippedCount, triggered_by: row.triggeredBy, error: row.error };
}
function computeNextRun(cronExpr: string): string | null {
  const p = cronExpr.split(' '); if (p.length < 2) return null;
  const m = parseInt(p[0]!, 10); const h = parseInt(p[1]!, 10); if (!Number.isFinite(m) || !Number.isFinite(h)) return null;
  const now = new Date(); const next = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), h, m, 0));
  if (next.getTime() <= now.getTime()) next.setUTCDate(next.getUTCDate() + 1);
  return next.toISOString();
}
EOF
W services/api/src/modules/admin/jobs/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { JobRunsResponseSchema, JobScheduleResponseSchema, RunJobResponseSchema, JobKeyEnum } from '@tera/contracts';
import * as s from './service.js';
export const adminJobsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/runs', { schema: { response: { 200: JobRunsResponseSchema as any } } }, async (req: any) => s.listRuns(req.query?.limit ? parseInt(req.query.limit, 10) : 50));
  app.get('/schedule', { schema: { response: { 200: JobScheduleResponseSchema as any } } }, async () => s.listSchedule());
  app.post('/:key/run', { schema: { response: { 200: RunJobResponseSchema as any } } }, async (req: any) => {
    const key = JobKeyEnum.parse(req.params.key); await s.runNow(key, req.user?.sub ?? 'admin'); return { job_key: key, enqueued: true as const };
  });
};
EOF
W services/api/src/modules/admin/jobs/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { adminJobsRoutes } from './routes.js';
export const adminJobsPlugin: FastifyPluginAsync = async (app) => { await app.register(adminJobsRoutes); };
export default adminJobsPlugin;
EOF

# Monitoring
W services/api/src/modules/monitoring/histogram.ts <<'EOF'
export interface HistogramState { counts: number[]; sum: number; count: number; }
export const emptyHistogram = (buckets: number[]): HistogramState => ({ counts: new Array(buckets.length).fill(0), sum: 0, count: 0 });
export function observeHistogram(s: HistogramState, buckets: number[], v: number): void {
  s.sum += v; s.count += 1;
  for (let i = 0; i < buckets.length; i++) if (v <= buckets[i]!) s.counts[i]! += 1;
}
export function computeQuantileFromValues(values: number[], q: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))]!;
}
EOF
W services/api/src/modules/monitoring/metrics-state.ts <<'EOF'
import { emptyHistogram, observeHistogram, type HistogramState } from './histogram.js';
export const HTTP_BUCKETS = [0.01, 0.05, 0.1, 0.5, 1, 5];
export const httpCounters = new Map<string, number>();
export const httpHistograms = new Map<string, HistogramState>();
export function recordHttpRequest(method: string, route: string, status: string, dur: number): void {
  const key = `${method}|${route}|${status}`;
  httpCounters.set(key, (httpCounters.get(key) ?? 0) + 1);
  let h = httpHistograms.get(route);
  if (!h) { h = emptyHistogram(HTTP_BUCKETS); httpHistograms.set(route, h); }
  observeHistogram(h, HTTP_BUCKETS, dur);
}
export function httpTotals() { let t = 0, s5 = 0; for (const [k, v] of httpCounters) { t += v; if ((k.split('|')[2] ?? '').startsWith('5')) s5 += v; } return { total: t, s5xx: s5 }; }
export function _reset() { httpCounters.clear(); httpHistograms.clear(); }
EOF
W services/api/src/modules/monitoring/middleware.ts <<'EOF'
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
EOF
W services/api/src/modules/monitoring/prometheus-format.ts <<'EOF'
export interface Sample { labels: Record<string, string>; value: number; }
export interface Metric { name: string; help: string; type: 'counter' | 'gauge'; samples: Sample[]; }
export function renderPrometheus(metrics: Metric[]): string {
  const lines: string[] = []; const seen = new Set<string>();
  for (const m of metrics) {
    if (m.samples.length === 0) continue;
    if (!seen.has(m.name)) { lines.push(`# HELP ${m.name} ${m.help}`); lines.push(`# TYPE ${m.name} ${m.type}`); seen.add(m.name); }
    for (const s of m.samples) lines.push(`${m.name}${labels(s.labels)} ${num(s.value)}`);
  }
  return lines.join('\n') + '\n';
}
export interface HistSeries { labels: Record<string, string>; bounds: number[]; cumulative: number[]; total: number; sum: number; }
export function renderHistogram(name: string, help: string, series: HistSeries[]): string {
  const lines = [`# HELP ${name} ${help}`, `# TYPE ${name} histogram`];
  for (const s of series) {
    for (let i = 0; i < s.bounds.length; i++) lines.push(`${name}_bucket${labels({ ...s.labels, le: String(s.bounds[i]) })} ${s.cumulative[i]}`);
    lines.push(`${name}_bucket${labels({ ...s.labels, le: '+Inf' })} ${s.total}`);
    lines.push(`${name}_sum${labels(s.labels)} ${num(s.sum)}`);
    lines.push(`${name}_count${labels(s.labels)} ${s.total}`);
  }
  return lines.join('\n') + '\n';
}
function labels(l: Record<string, string>): string {
  const k = Object.keys(l); if (k.length === 0) return '';
  return `{${k.map((x) => `${x}="${l[x]!.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`).join(',')}}`;
}
function num(n: number): string { if (Number.isNaN(n)) return 'NaN'; if (!Number.isFinite(n)) return n > 0 ? '+Inf' : '-Inf'; return String(n); }
EOF
W services/api/src/modules/monitoring/db-gauges.ts <<'EOF'
import { computeQuantileFromValues } from './histogram.js';
import type { Metric } from './prometheus-format.js';
export interface Input {
  solveJobs: { status: string; count: number }[];
  solveDurationsMs: number[];
  pendingOrders: number; unreconciledPayments: number;
  staleSyncClients: number; highVarianceFuelLogs7d: number;
  jobRuns24h: { jobKey: string; status: string; count: number }[];
}
export function buildDbGauges(i: Input): Metric[] {
  const out: Metric[] = [];
  out.push({ name: 'tera_solve_jobs', help: 'Current solve jobs by status', type: 'gauge', samples: i.solveJobs.map((r) => ({ labels: { status: r.status }, value: r.count })) });
  if (i.solveDurationsMs.length > 0) {
    const avg = i.solveDurationsMs.reduce((s, x) => s + x, 0) / i.solveDurationsMs.length;
    const p95 = computeQuantileFromValues(i.solveDurationsMs, 0.95);
    out.push({ name: 'tera_solve_job_duration_seconds', help: 'Solve job duration', type: 'gauge', samples: [
      { labels: { quantile: 'avg' }, value: Math.round(avg / 10) / 100 },
      { labels: { quantile: 'p95' }, value: Math.round(p95 / 10) / 100 },
    ]});
  }
  out.push({ name: 'tera_pending_orders', help: 'Orders PENDING', type: 'gauge', samples: [{ labels: {}, value: i.pendingOrders }] });
  out.push({ name: 'tera_unreconciled_payments', help: 'Payments awaiting reconcile', type: 'gauge', samples: [{ labels: {}, value: i.unreconciledPayments }] });
  out.push({ name: 'tera_stale_sync_clients', help: 'Sync clients stale > 1h', type: 'gauge', samples: [{ labels: {}, value: i.staleSyncClients }] });
  out.push({ name: 'tera_high_variance_fuel_logs_7d', help: 'High-variance fuel last 7d', type: 'gauge', samples: [{ labels: {}, value: i.highVarianceFuelLogs7d }] });
  out.push({ name: 'tera_job_runs_24h', help: 'Job runs last 24h', type: 'gauge', samples: i.jobRuns24h.map((r) => ({ labels: { job: r.jobKey, status: r.status }, value: r.count })) });
  return out;
}
EOF
W services/api/src/modules/monitoring/repository.ts <<'EOF'
import { db } from '@tera/db';
export async function loadSolveJobsByStatus() { const r = await db().solveJob.groupBy({ by: ['status'], _count: { _all: true } }); return r.map((x) => ({ status: x.status, count: x._count._all })); }
export async function loadRecentDurations() { const r = await db().solveJob.findMany({ where: { status: 'DONE', durationMs: { not: null } }, select: { durationMs: true }, orderBy: { createdAt: 'desc' }, take: 100 }); return r.map((x) => x.durationMs!).filter(Number.isFinite); }
export const countPending = () => db().order.count({ where: { status: 'PENDING' } });
export const countUnreconciled = () => db().payment.count({ where: { reconciledAt: null } });
export function countStaleClients(h: number) { return db().syncClient.count({ where: { lastSeenAt: { lt: new Date(Date.now() - h * 3600_000) } } }); }
export function countHighVarFuel(d: number) { return db().fuelLog.count({ where: { varianceFlag: 'HIGH', capturedAt: { gte: new Date(Date.now() - d * 86_400_000) } } }); }
export async function loadJobRuns24h() { const r = await db().jobRun.groupBy({ by: ['jobKey', 'status'], where: { startedAt: { gte: new Date(Date.now() - 24 * 3600_000) } }, _count: { _all: true } }); return r.map((x) => ({ jobKey: x.jobKey, status: x.status, count: x._count._all })); }
EOF
W services/api/src/modules/monitoring/service.ts <<'EOF'
import { httpCounters, httpHistograms, httpTotals, HTTP_BUCKETS } from './metrics-state.js';
import { renderPrometheus, renderHistogram, type Metric, type HistSeries } from './prometheus-format.js';
import { buildDbGauges } from './db-gauges.js';
import * as repo from './repository.js';
const START = Date.now();
export async function getMetricsText(): Promise<string> {
  const metrics: Metric[] = [];
  const c: { labels: Record<string, string>; value: number }[] = [];
  for (const [k, v] of httpCounters) { const [m, r, s] = k.split('|'); c.push({ labels: { method: m!, route: r!, status: s! }, value: v }); }
  metrics.push({ name: 'tera_http_requests_total', help: 'Total HTTP requests', type: 'counter', samples: c });
  metrics.push(...buildDbGauges({
    solveJobs: await repo.loadSolveJobsByStatus(),
    solveDurationsMs: await repo.loadRecentDurations(),
    pendingOrders: await repo.countPending(),
    unreconciledPayments: await repo.countUnreconciled(),
    staleSyncClients: await repo.countStaleClients(1),
    highVarianceFuelLogs7d: await repo.countHighVarFuel(7),
    jobRuns24h: await repo.loadJobRuns24h(),
  }));
  const mem = process.memoryUsage();
  metrics.push({ name: 'tera_process_uptime_seconds', help: 'Uptime', type: 'gauge', samples: [{ labels: {}, value: Math.round((Date.now() - START) / 1000) }] });
  metrics.push({ name: 'tera_process_memory_bytes', help: 'Memory', type: 'gauge', samples: [
    { labels: { type: 'rss' }, value: mem.rss }, { labels: { type: 'heap_used' }, value: mem.heapUsed }, { labels: { type: 'heap_total' }, value: mem.heapTotal },
  ]});
  let out = renderPrometheus(metrics);
  const hs: HistSeries[] = [];
  for (const [route, s] of httpHistograms) if (s.count > 0) hs.push({ labels: { route }, bounds: HTTP_BUCKETS, cumulative: s.counts, total: s.count, sum: s.sum });
  if (hs.length > 0) out += renderHistogram('tera_http_request_duration_seconds', 'HTTP duration', hs);
  return out;
}
export function getUptimeSeconds() { return Math.round((Date.now() - START) / 1000); }
export function getHttpTotals() { return httpTotals(); }
EOF
W services/api/src/modules/monitoring/snapshot-service.ts <<'EOF'
import type { MonitoringSnapshot } from '@tera/contracts';
import { computeQuantileFromValues } from './histogram.js';
import { httpTotals } from './metrics-state.js';
import { getUptimeSeconds } from './service.js';
import * as repo from './repository.js';
export async function getSnapshot(): Promise<MonitoringSnapshot> {
  const [solveJobs, durations, pending, unrecon, stale, highFuel, jobRuns] = await Promise.all([
    repo.loadSolveJobsByStatus(), repo.loadRecentDurations(), repo.countPending(),
    repo.countUnreconciled(), repo.countStaleClients(1), repo.countHighVarFuel(7), repo.loadJobRuns24h(),
  ]);
  const { total, s5xx } = httpTotals();
  const byStatus: Record<string, number> = {}; for (const s of solveJobs) byStatus[s.status] = s.count;
  const avg = durations.length > 0 ? durations.reduce((s, x) => s + x, 0) / durations.length : 0;
  const p95 = computeQuantileFromValues(durations, 0.95);
  return {
    as_of: new Date().toISOString(), uptime_seconds: getUptimeSeconds(),
    http_requests_total: total, http_5xx_total: s5xx, http_error_rate_pct: total > 0 ? Math.round((s5xx / total) * 10000) / 100 : 0,
    solve_jobs_by_status: byStatus, solve_duration_avg_ms: Math.round(avg), solve_duration_p95_ms: Math.round(p95),
    pending_orders: pending, unreconciled_payments: unrecon, stale_sync_clients: stale, high_variance_fuel_logs_7d: highFuel,
    job_runs_24h: jobRuns.map((r) => ({ job: r.jobKey, status: r.status, count: r.count })),
  };
}
EOF
W services/api/src/modules/monitoring/routes.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { MonitoringSnapshotSchema } from '@tera/contracts';
import * as s from './service.js';
import * as snap from './snapshot-service.js';
export const monitoringRoutes: FastifyPluginAsync = async (app) => {
  app.get('/metrics', async (_req, reply) => { const b = await s.getMetricsText(); reply.header('Content-Type', 'text/plain; version=0.0.4'); return b; });
  app.get('/admin/monitoring/v1/snapshot', { schema: { response: { 200: MonitoringSnapshotSchema as any } } }, async () => snap.getSnapshot());
};
EOF
W services/api/src/modules/monitoring/index.ts <<'EOF'
import type { FastifyPluginAsync } from 'fastify';
import { monitoringRoutes } from './routes.js';
export const monitoringPlugin: FastifyPluginAsync = async (app) => { await app.register(monitoringRoutes); };
export default monitoringPlugin;
EOF

# ═══════════════════════════════════════════════════════════════════
# UPDATE API — register all new modules + monitoring hooks
# ═══════════════════════════════════════════════════════════════════
W services/api/src/app.ts <<'EOF'
import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { errorHandler } from './plugins/errorHandler.js';
import { authPlugin } from './plugins/auth.js';
import { onRequestHook, onResponseHook } from './modules/monitoring/middleware.js';

import credit from './modules/credit/index.js';
import configMod from './modules/config/index.js';
import geo from './modules/geo/index.js';
import routing from './modules/routing/index.js';
import orders from './modules/orders/index.js';
import dispatch from './modules/dispatch/index.js';
import masterdata from './modules/masterdata/index.js';
import analytics from './modules/analytics/index.js';
import payments from './modules/payments/index.js';
import portal from './modules/portal/index.js';
import audit from './modules/audit/index.js';
import notify from './modules/notify/index.js';
import adminJobs from './modules/admin/jobs/index.js';
import monitoring from './modules/monitoring/index.js';

export async function buildApp() {
  const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
  await app.register(cors, { origin: true });
  app.addHook('onRequest', onRequestHook);
  app.addHook('onResponse', onResponseHook);
  await app.register(sensible);
  await app.register(swagger, { openapi: { info: { title: 'Tera OMS API', version: '0.1.0' } } });
  await app.register(swaggerUi, { routePrefix: '/docs' });
  app.setErrorHandler(errorHandler);
  await app.register(authPlugin);

  await app.register(configMod,  { prefix: '/config/v1' });
  await app.register(credit,     { prefix: '/credit/v1' });
  await app.register(geo,        { prefix: '/geo/v1' });
  await app.register(routing,    { prefix: '/routing/v1' });
  await app.register(orders,     { prefix: '/orders/v1' });
  await app.register(dispatch,   { prefix: '/dispatch/v1' });
  await app.register(masterdata, { prefix: '/masterdata/v1' });
  await app.register(analytics,  { prefix: '/analytics/v1' });
  await app.register(payments,   { prefix: '/payments/v1' });
  await app.register(portal,     { prefix: '/portal/v1' });
  await app.register(audit,      { prefix: '/audit/v1' });
  await app.register(notify,     { prefix: '/notify/v1' });
  await app.register(adminJobs,  { prefix: '/admin/jobs/v1' });
  await app.register(monitoring);

  app.get('/health', async () => ({ ok: true }));
  return app;
}
EOF

# ═══════════════════════════════════════════════════════════════════
# OPTIMIZER SERVICE (VRP worker — BullMQ consumer)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Optimizer service"

W services/optimizer/package.json <<'EOF'
{
  "name": "@tera/optimizer", "version": "0.1.0", "private": true, "type": "module",
  "scripts": { "dev": "tsx watch src/main.ts", "build": "tsc -b", "start": "node dist/main.js", "lint": "tsc --noEmit", "test": "vitest run" },
  "dependencies": { "@tera/db": "workspace:*", "@tera/solver": "workspace:*", "bullmq": "^5.8.0", "ioredis": "^5.4.0", "pino": "^9.0.0" },
  "devDependencies": { "@types/node": "^20.12.0", "tsx": "^4.7.0", "typescript": "^5.4.0", "vitest": "^1.6.0" }
}
EOF
W services/optimizer/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true, "noEmit": false }, "include": ["src"] }
EOF
W services/optimizer/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { environment: 'node', globals: true } });
EOF
W services/optimizer/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
RUN corepack enable
COPY package.json ./
RUN pnpm install --prod=false
COPY src ./src
CMD ["pnpm", "tsx", "src/main.ts"]
EOF
W services/optimizer/src/solver-worker.ts <<'EOF'
import { db } from '@tera/db';
import { solve } from '@tera/solver';
const MAX = 500;
export async function processSolveJob(dbJobId: string): Promise<void> {
  const job = await db().solveJob.findUnique({ where: { id: dbJobId } });
  if (!job) throw new Error(`solve job ${dbJobId} not found`);
  if (job.status !== 'QUEUED') { console.log(`[opt] ${dbJobId} already ${job.status} — skip`); return; }
  const startedAt = new Date();
  await db().solveJob.update({ where: { id: dbJobId }, data: { status: 'RUNNING', startedAt } });
  try {
    const ids = job.orderIdsJson as string[];
    if (!Array.isArray(ids) || ids.length < 2) throw new Error('need ≥2 orders');
    if (ids.length > MAX) throw new Error(`too many (${ids.length})`);
    const [orders, vehicle, zones] = await Promise.all([
      db().order.findMany({ where: { id: { in: ids } } }),
      db().vehicle.findUnique({ where: { id: job.vehicleId } }),
      db().curfewZone.findMany({ where: { active: true } }),
    ]);
    if (!vehicle) throw new Error(`vehicle ${job.vehicleId} not found`);
    if (orders.length < 2) throw new Error('fewer than 2 valid orders');
    const result = solve(
      orders.map((o) => ({ id: o.id, distributor_name: o.distributorName, lat: Number(o.lat), lng: Number(o.lng), weight_kg: Number(o.weightKg), volume_m3: Number(o.volumeM3), priority: o.priority, time_window_start: o.timeWindowStart.toISOString(), time_window_end: o.timeWindowEnd.toISOString() })),
      { id: vehicle.id, lat: Number(vehicle.startLat), lng: Number(vehicle.startLng), capacity_kg: Number(vehicle.capacityKg), capacity_m3: Number(vehicle.capacityM3), shift_start_h: vehicle.shiftStartH, shift_end_h: vehicle.shiftEndH },
      { curfew_zones: zones.map((z) => ({ id: z.id, name: z.name, polygon: z.polygonJson as any, start_hour: z.startHour, end_hour: z.endHour })) },
    );
    const finishedAt = new Date();
    await db().solveJob.update({ where: { id: dbJobId }, data: { status: 'DONE', resultJson: result as any, finishedAt, durationMs: finishedAt.getTime() - startedAt.getTime() } });
  } catch (err) {
    const finishedAt = new Date();
    const msg = err instanceof Error ? err.message : String(err);
    await db().solveJob.update({ where: { id: dbJobId }, data: { status: 'FAILED', error: msg, finishedAt, durationMs: finishedAt.getTime() - startedAt.getTime() } });
    throw err;
  }
}
EOF
W services/optimizer/src/main.ts <<'EOF'
import { Worker, type Job } from 'bullmq';
import IORedis from 'ioredis';
import { processSolveJob } from './solver-worker.js';

const QUEUE = 'route-solve'; const CONCURRENCY = Number(process.env.OPT_CONCURRENCY ?? 2);
const redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null, enableReadyCheck: false });
redis.on('connect', () => console.log('[opt] redis connected'));
redis.on('error', (e) => console.error('[opt] redis error', e.message));

const worker = new Worker<{ dbJobId: string }>(QUEUE, async (job: Job<{ dbJobId: string }>) => {
  console.log(`[opt] picked ${job.id}`);
  await processSolveJob(job.data.dbJobId);
  console.log(`[opt] finished ${job.id}`);
}, { connection: redis, concurrency: CONCURRENCY });

worker.on('completed', (j) => console.log(`[opt] ✓ ${j.id}`));
worker.on('failed', (j, e) => console.error(`[opt] ✗ ${j?.id}: ${e.message}`));

console.log(`[opt] ready · queue=${QUEUE} concurrency=${CONCURRENCY}`);
process.on('SIGTERM', async () => { await worker.close(); await redis.quit(); process.exit(0); });
process.on('SIGINT', async () => { await worker.close(); await redis.quit(); process.exit(0); });
EOF
W services/optimizer/src/__tests__/state.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
type S = 'QUEUED' | 'RUNNING' | 'DONE' | 'FAILED' | 'TIMEOUT';
const shouldProcess = (s: S) => s === 'QUEUED';
describe('solve job state', () => { it('only QUEUED jobs are processed', () => {
  expect(shouldProcess('QUEUED')).toBe(true);
  expect(shouldProcess('RUNNING')).toBe(false);
  expect(shouldProcess('DONE')).toBe(false);
}); });
EOF

# ═══════════════════════════════════════════════════════════════════
# WORKER SERVICE (nightly jobs)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Worker service"

W services/worker/package.json <<'EOF'
{
  "name": "@tera/worker", "version": "0.1.0", "private": true, "type": "module",
  "scripts": { "dev": "tsx watch src/main.ts", "build": "tsc -b", "start": "node dist/main.js", "lint": "tsc --noEmit", "test": "vitest run" },
  "dependencies": { "@tera/db": "workspace:*", "bullmq": "^5.8.0", "ioredis": "^5.4.0", "node-cron": "^3.0.3", "pino": "^9.0.0" },
  "devDependencies": { "@types/node": "^20.12.0", "@types/node-cron": "^3.0.11", "tsx": "^4.7.0", "typescript": "^5.4.0", "vitest": "^1.6.0" }
}
EOF
W services/worker/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true, "noEmit": false }, "include": ["src"] }
EOF
W services/worker/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { environment: 'node', globals: true } });
EOF
W services/worker/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
RUN corepack enable
COPY package.json ./
RUN pnpm install --prod=false
COPY src ./src
CMD ["pnpm", "tsx", "src/main.ts"]
EOF
W services/worker/src/jobs/repository.ts <<'EOF'
import { db } from '@tera/db';
export const createJobRun = (k: string, t: string) => db().jobRun.create({ data: { jobKey: k, triggeredBy: t, status: 'RUNNING' } });
export async function finishJobRun(id: string, i: { status: string; processedCount: number; skippedCount: number; error?: string | null }) {
  const fin = new Date();
  const row = await db().jobRun.update({ where: { id }, data: { status: i.status, finishedAt: fin, processedCount: i.processedCount, skippedCount: i.skippedCount, error: i.error ?? null } });
  await db().jobRun.update({ where: { id }, data: { durationMs: fin.getTime() - row.startedAt.getTime() } });
}
export const upsertSnapshot = (date: Date, key: string, value: number) => db().metricSnapshot.upsert({ where: { date_key: { date, key } }, create: { date, key, value }, update: { value } });
export const loadAssumptions = () => db().costAssumption.findMany();
export const loadActiveVehicles = () => db().vehicle.findMany({ where: { active: true, baselineLPer100Km: { not: null } } });
export const loadFuelFillsForVehicle = (id: string, since: Date) => db().fuelLog.findMany({ where: { vehicleId: id, capturedAt: { gte: since } }, select: { liters: true, odometerKm: true, capturedAt: true }, orderBy: { capturedAt: 'asc' } });
export const loadAllCreditAccounts = () => db().creditAccount.findMany();
export const loadUnreconciledPaymentsForDistributor = (distId: string) => db().payment.findMany({ where: { reconciledAt: null, routeStop: { distributorId: distId } }, select: { capturedAt: true, amountEtb: true } });
export const loadDeliveredStopsForDistributor = (distId: string) => db().routeStop.findMany({ where: { distributorId: distId, status: 'DELIVERED' }, select: { id: true, statusUpdatedAt: true } });
export const loadReconciledStopsForDistributor = (distId: string) => db().payment.findMany({ where: { reconciledAt: { not: null }, routeStop: { distributorId: distId } }, select: { routeStopId: true } });
export const updateCreditAccount = (id: string, i: { oldestUnpaidAt: Date | null; exposureEtb: number }) => db().creditAccount.update({ where: { id }, data: i });
export const createAudit = (i: any) => db().auditLog.create({ data: { actorId: i.actorId, entity: i.entity, entityId: i.entityId, action: i.action, reason: i.reason, metaJson: i.meta as any } });
export const loadRoutePlans = (since: Date) => db().routePlan.findMany({ where: { date: { gte: since } } });
export const loadDeliveredStops = (since: Date) => db().routeStop.findMany({ where: { status: 'DELIVERED', statusUpdatedAt: { gte: since } }, select: { statusUpdatedAt: true, plannedEta: true } });
export const loadFuelCost = (since: Date) => db().fuelLog.aggregate({ where: { capturedAt: { gte: since } }, _sum: { amountEtb: true } });
export const loadFuelVariance = (since: Date) => db().fuelLog.findMany({ where: { capturedAt: { gte: since } }, select: { varianceFlag: true } });
export const loadProofCount = (since: Date) => db().proofOfDelivery.count({ where: { capturedAt: { gte: since } } });
export const loadCreditDecisions = (since: Date) => db().creditDecision.findMany({ where: { createdAt: { gte: since } }, select: { outcome: true, orderId: true } });
export const loadDispatchedRoutes = (orderIds: string[]) => db().routePlan.findMany({ where: { stops: { some: { orderId: { in: orderIds } } } }, select: { stops: { select: { orderId: true } } } });
export const loadConfirmedSlots = (since: Date) => db().dispatchDockSlot.findMany({ where: { status: 'CONFIRMED', confirmedAt: { gte: since, not: null } }, select: { startAt: true, confirmedAt: true } });
export const loadActiveVehicleIds = (since: Date) => db().routePlan.findMany({ where: { date: { gte: since } }, select: { vehicleId: true } });
export async function countStockoutSkus(): Promise<number> { const s = await db().sku.findMany({ where: { active: true }, select: { stockOnHand: true, safetyStock: true } }); return s.filter((x) => x.stockOnHand < x.safetyStock).length > 0 ? 1 : 0; }
EOF
W services/worker/src/jobs/metric-computers.ts <<'EOF'
export interface SourceData {
  routePlans: { plannedKm: number; plannedMin: number; status: string }[];
  deliveredStops: { statusUpdatedAt: Date; plannedEta: Date }[];
  fuelCostEtb: number; highVar: number; routeCount: number; proofCount: number;
  blocked: number; blockedDispatched: number; stockoutDays: number;
  confirmedSlots: { startAt: Date; confirmedAt: Date }[];
  vehicles: number; days: number; wearRate: number;
}
const r2 = (n: number) => Math.round(n * 100) / 100;
const avg = (xs: number[]) => (xs.length === 0 ? 0 : xs.reduce((s, x) => s + x, 0) / xs.length);
const med = (xs: number[]) => { if (!xs.length) return 0; const s = [...xs].sort((a, b) => a - b); const m = Math.floor(s.length / 2); return s.length % 2 === 0 ? (s[m - 1]! + s[m]!) / 2 : s[m]!; };
export const computeVariableCostEtb = (d: SourceData) => (d.routePlans.length === 0 && d.fuelCostEtb === 0 ? null : Math.round(d.fuelCostEtb + d.routePlans.reduce((s, r) => s + r.plannedKm, 0) * d.wearRate));
export const computeKmPerDelivery = (d: SourceData) => (d.deliveredStops.length === 0 ? null : r2(d.routePlans.reduce((s, r) => s + r.plannedKm, 0) / d.deliveredStops.length));
export const computeMedianDeliveryHours = (d: SourceData) => { const m = d.routePlans.filter((r) => r.status !== 'PLANNED').map((r) => r.plannedMin); return m.length === 0 ? null : r2(med(m) / 60); };
export const computeOnTimeSlaPct = (d: SourceData) => (d.deliveredStops.length === 0 ? null : r2((d.deliveredStops.filter((s) => s.statusUpdatedAt <= s.plannedEta).length / d.deliveredStops.length) * 100));
export const computeStockoutSkuDays = (d: SourceData) => d.stockoutDays;
export const computeDockTurnaroundMinutes = (d: SourceData) => (d.confirmedSlots.length === 0 ? null : r2(avg(d.confirmedSlots.map((s) => (s.confirmedAt.getTime() - s.startAt.getTime()) / 60_000))));
export const computeReserveViolations = (d: SourceData) => (d.routeCount === 0 ? null : r2((d.highVar / d.routeCount) * 100));
export const computeDeliveriesPerVehiclePerDay = (d: SourceData) => (d.vehicles === 0 || d.days === 0 ? null : r2(d.deliveredStops.length / d.vehicles / d.days));
export const computeCleanEpodRatePct = (d: SourceData) => (d.deliveredStops.length === 0 ? null : r2(Math.min(100, (d.proofCount / d.deliveredStops.length) * 100)));
export const computeCreditBlockedPreDispatchPct = (d: SourceData) => (d.blocked === 0 ? 100 : r2(((d.blocked - d.blockedDispatched) / d.blocked) * 100));
EOF
W services/worker/src/jobs/metric-snapshot.ts <<'EOF'
import * as repo from './repository.js';
import { computeVariableCostEtb, computeKmPerDelivery, computeMedianDeliveryHours, computeOnTimeSlaPct, computeStockoutSkuDays, computeDockTurnaroundMinutes, computeReserveViolations, computeDeliveriesPerVehiclePerDay, computeCleanEpodRatePct, computeCreditBlockedPreDispatchPct, type SourceData } from './metric-computers.js';
const WINDOW = 30;
export async function runMetricSnapshot(triggeredBy: string): Promise<{ processed: number; skipped: number }> {
  const run = await repo.createJobRun('metric_snapshot', triggeredBy);
  const since = new Date(Date.now() - WINDOW * 86_400_000);
  const today = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()));
  try {
    const [routes, stops, fuelCost, fuelVar, proofCount, decisions, slots, vehicles, stockout, assumptions] = await Promise.all([
      repo.loadRoutePlans(since), repo.loadDeliveredStops(since), repo.loadFuelCost(since), repo.loadFuelVariance(since), repo.loadProofCount(since), repo.loadCreditDecisions(since), repo.loadConfirmedSlots(since), repo.loadActiveVehicleIds(since), repo.countStockoutSkus(), repo.loadAssumptions(),
    ]);
    const blockedIds = decisions.filter((d) => d.outcome === 'BLOCKED' && d.orderId).map((d) => d.orderId!);
    const dispatched = blockedIds.length > 0 ? await repo.loadDispatchedRoutes(blockedIds) : [];
    const dispatchedSet = new Set(dispatched.flatMap((r) => r.stops.map((s) => s.orderId)));
    const assumptionMap = new Map(assumptions.map((a) => [a.key, a.value]));
    const data: SourceData = {
      routePlans: routes.map((r) => ({ plannedKm: Number(r.plannedKm), plannedMin: r.plannedMin, status: r.status })),
      deliveredStops: stops.map((s) => ({ statusUpdatedAt: s.statusUpdatedAt, plannedEta: s.plannedEta })),
      fuelCostEtb: Number(fuelCost._sum.amountEtb ?? 0),
      highVar: fuelVar.filter((f) => f.varianceFlag === 'HIGH').length,
      routeCount: routes.length, proofCount,
      blocked: decisions.filter((d) => d.outcome === 'BLOCKED').length,
      blockedDispatched: blockedIds.filter((id) => dispatchedSet.has(id)).length,
      stockoutDays: stockout,
      confirmedSlots: slots.map((s) => ({ startAt: s.startAt, confirmedAt: s.confirmedAt! })),
      vehicles: new Set(vehicles.map((v) => v.vehicleId)).size,
      days: WINDOW, wearRate: assumptionMap.get('vehicle_wear_etb_per_km') ?? 3.5,
    };
    const computations = [
      { key: 'variable_cost_per_month_etb', value: computeVariableCostEtb(data) },
      { key: 'km_per_delivery', value: computeKmPerDelivery(data) },
      { key: 'median_delivery_hours', value: computeMedianDeliveryHours(data) },
      { key: 'on_time_sla_pct', value: computeOnTimeSlaPct(data) },
      { key: 'stockout_sku_days_per_month', value: computeStockoutSkuDays(data) },
      { key: 'dock_turnaround_minutes', value: computeDockTurnaroundMinutes(data) },
      { key: 'reserve_violations_per_100_routes', value: computeReserveViolations(data) },
      { key: 'deliveries_per_vehicle_per_day', value: computeDeliveriesPerVehiclePerDay(data) },
      { key: 'clean_epod_rate_pct', value: computeCleanEpodRatePct(data) },
      { key: 'credit_blocked_pre_dispatch_pct', value: computeCreditBlockedPreDispatchPct(data) },
    ];
    let processed = 0, skipped = 0;
    for (const c of computations) { if (c.value === null) { skipped++; continue; } await repo.upsertSnapshot(today, c.key, c.value); processed++; }
    await repo.finishJobRun(run.id, { status: 'DONE', processedCount: processed, skippedCount: skipped });
    return { processed, skipped };
  } catch (err) {
    await repo.finishJobRun(run.id, { status: 'FAILED', processedCount: 0, skippedCount: 0, error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
EOF
W services/worker/src/jobs/fuel-variance.ts <<'EOF'
import * as repo from './repository.js';
const WINDOW = 30;
function computeL100(fills: { liters: number; odometerKm: number; capturedAt: Date }[]): { l100: number; at: Date }[] {
  const sorted = [...fills].sort((a, b) => a.capturedAt.getTime() - b.capturedAt.getTime());
  const out: { l100: number; at: Date }[] = [];
  for (let i = 1; i < sorted.length; i++) { const d = sorted[i]!.odometerKm - sorted[i - 1]!.odometerKm; if (d <= 0) continue; out.push({ l100: (sorted[i]!.liters / d) * 100, at: sorted[i]!.capturedAt }); }
  return out;
}
export async function runFuelVariance(triggeredBy: string): Promise<{ processed: number; skipped: number }> {
  const run = await repo.createJobRun('fuel_variance', triggeredBy);
  const since = new Date(Date.now() - WINDOW * 86_400_000);
  try {
    const vehicles = await repo.loadActiveVehicles();
    let processed = 0, skipped = 0;
    for (const v of vehicles) {
      const fills = await repo.loadFuelFillsForVehicle(v.id, since);
      if (fills.length < 4) { skipped++; continue; }
      const l = computeL100(fills.map((f) => ({ liters: Number(f.liters), odometerKm: Number(f.odometerKm), capturedAt: f.capturedAt })));
      if (l.length < 3) { skipped++; continue; }
      const mean = l.reduce((s, x) => s + x.l100, 0) / l.length;
      const variance = l.reduce((s, x) => s + (x.l100 - mean) ** 2, 0) / l.length;
      const stdev = Math.sqrt(variance);
      const outliers = l.filter((x) => x.l100 < mean - 2 * stdev || x.l100 > mean + 2 * stdev);
      if (outliers.length > 0) {
        await repo.createAudit({ actorId: 'worker/fuel_variance', entity: 'vehicle', entityId: v.id, action: 'variance_flagged',
          reason: `${v.plate}: ${outliers.length} outlier(s) (mean ${mean.toFixed(1)}, σ ${stdev.toFixed(2)})`,
          meta: { plate: v.plate, mean, stdev, outliers: outliers.length } });
      }
      processed++;
    }
    await repo.finishJobRun(run.id, { status: 'DONE', processedCount: processed, skippedCount: skipped });
    return { processed, skipped };
  } catch (err) {
    await repo.finishJobRun(run.id, { status: 'FAILED', processedCount: 0, skippedCount: 0, error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
EOF
W services/worker/src/jobs/credit-rebuild.ts <<'EOF'
import * as repo from './repository.js';
export async function runCreditRebuild(triggeredBy: string): Promise<{ processed: number; skipped: number }> {
  const run = await repo.createJobRun('credit_rebuild', triggeredBy);
  try {
    const accounts = await repo.loadAllCreditAccounts();
    let processed = 0, skipped = 0;
    for (const a of accounts) {
      const [unrec, delivered, reconciledStops] = await Promise.all([
        repo.loadUnreconciledPaymentsForDistributor(a.distributorId),
        repo.loadDeliveredStopsForDistributor(a.distributorId),
        repo.loadReconciledStopsForDistributor(a.distributorId),
      ]);
      const recSet = new Set(reconciledStops.map((p) => p.routeStopId));
      const candidates: Date[] = [...unrec.map((p) => p.capturedAt)];
      for (const s of delivered) if (!recSet.has(s.id)) candidates.push(s.statusUpdatedAt);
      const oldest = candidates.length === 0 ? null : candidates.reduce((o, d) => (d < o ? d : o));
      const exposure = Math.round(unrec.reduce((s, p) => s + Number(p.amountEtb), 0) * 100) / 100;
      const prevOldest = a.oldestUnpaidAt?.getTime() ?? null;
      const prevExposure = Number(a.exposureEtb);
      await repo.updateCreditAccount(a.id, { oldestUnpaidAt: oldest, exposureEtb: exposure });
      processed++;
      if ((oldest?.getTime() ?? null) !== prevOldest || Math.abs(prevExposure - exposure) > 1) {
        await repo.createAudit({ actorId: 'worker/credit_rebuild', entity: 'credit_account', entityId: a.id, action: 'rebuilt',
          reason: `Exposure ${prevExposure} → ${exposure}; oldest ${a.oldestUnpaidAt?.toISOString() ?? 'none'} → ${oldest?.toISOString() ?? 'none'}`,
          meta: { previous_exposure: prevExposure, new_exposure: exposure } });
      }
    }
    await repo.finishJobRun(run.id, { status: 'DONE', processedCount: processed, skippedCount: skipped });
    return { processed, skipped };
  } catch (err) {
    await repo.finishJobRun(run.id, { status: 'FAILED', processedCount: 0, skippedCount: 0, error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
EOF
W services/worker/src/main.ts <<'EOF'
import { Queue, Worker as BullWorker, type Job } from 'bullmq';
import IORedis from 'ioredis';
import cron from 'node-cron';
import { runMetricSnapshot } from './jobs/metric-snapshot.js';
import { runFuelVariance } from './jobs/fuel-variance.js';
import { runCreditRebuild } from './jobs/credit-rebuild.js';

const QUEUE = 'worker-jobs';
const redis = new IORedis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: null, enableReadyCheck: false });
redis.on('connect', () => console.log('[worker] redis connected'));
redis.on('error', (e) => console.error('[worker] redis error', e.message));
const queue = new Queue(QUEUE, { connection: redis });

async function process(job: Job<{ triggeredBy?: string }>) {
  const t = job.data?.triggeredBy ?? 'schedule';
  switch (job.name) {
    case 'metric_snapshot': { const r = await runMetricSnapshot(t); console.log(`[worker] metric_snapshot ${r.processed}/${r.skipped}`); break; }
    case 'fuel_variance': { const r = await runFuelVariance(t); console.log(`[worker] fuel_variance ${r.processed}/${r.skipped}`); break; }
    case 'credit_rebuild': { const r = await runCreditRebuild(t); console.log(`[worker] credit_rebuild ${r.processed}/${r.skipped}`); break; }
    default: throw new Error(`unknown job: ${job.name}`);
  }
}
const worker = new BullWorker<{ triggeredBy?: string }>(QUEUE, async (job) => process(job), { connection: redis, concurrency: 2 });
worker.on('completed', (j) => console.log(`[worker] ✓ ${j.name}`));
worker.on('failed', (j, e) => console.error(`[worker] ✗ ${j?.name}: ${e.message}`));

cron.schedule('0 22 * * *', async () => { await queue.add('metric_snapshot', { triggeredBy: 'schedule' }); });
cron.schedule('15 22 * * *', async () => { await queue.add('credit_rebuild', { triggeredBy: 'schedule' }); });
cron.schedule('30 22 * * *', async () => { await queue.add('fuel_variance', { triggeredBy: 'schedule' }); });
console.log('[worker] ready');
process.on('SIGTERM', async () => { await worker.close(); await queue.close(); await redis.quit(); process.exit(0); });
process.on('SIGINT', async () => { await worker.close(); await queue.close(); await redis.quit(); process.exit(0); });
EOF
W services/worker/src/jobs/__tests__/metric-computers.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { computeVariableCostEtb, computeKmPerDelivery, computeOnTimeSlaPct, computeCreditBlockedPreDispatchPct } from '../metric-computers.js';
const base = { routePlans: [], deliveredStops: [], fuelCostEtb: 0, highVar: 0, routeCount: 0, proofCount: 0, blocked: 0, blockedDispatched: 0, stockoutDays: 0, confirmedSlots: [], vehicles: 0, days: 0, wearRate: 3.5 };
describe('metric computers', () => {
  it('variable cost null on empty', () => expect(computeVariableCostEtb(base)).toBeNull());
  it('variable cost = fuel + wear', () => expect(computeVariableCostEtb({ ...base, fuelCostEtb: 100_000, routePlans: [{ plannedKm: 500, plannedMin: 240, status: 'DISPATCHED' }] })).toBe(101_750));
  it('km per delivery', () => expect(computeKmPerDelivery({ ...base, routePlans: [{ plannedKm: 100, plannedMin: 60, status: 'DISPATCHED' }], deliveredStops: [{ statusUpdatedAt: new Date(), plannedEta: new Date() }, { statusUpdatedAt: new Date(), plannedEta: new Date() }] })).toBe(50));
  it('on-time SLA', () => { const eta = new Date('2026-04-12T10:00:00Z'); expect(computeOnTimeSlaPct({ ...base, deliveredStops: [{ statusUpdatedAt: new Date('2026-04-12T09:55:00Z'), plannedEta: eta }, { statusUpdatedAt: new Date('2026-04-12T10:30:00Z'), plannedEta: eta }] })).toBe(50); });
  it('credit 100 when no blocks', () => expect(computeCreditBlockedPreDispatchPct(base)).toBe(100));
});
EOF

# ═══════════════════════════════════════════════════════════════════
# ADMIN-WEB — add 4 new tabs (Audit, Notifications, Jobs, Monitoring)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Admin tabs"

# Audit
W apps/admin-web/src/modules/audit/types.ts <<'EOF'
export type { AuditLogEntry, AuditListResponse } from '@tera/contracts';
EOF
W apps/admin-web/src/modules/audit/api.ts <<'EOF'
import { api } from '../../api/client';
import type { AuditListResponse } from './types';
export const auditKeys = { all: ['audit'] as const, list: (e: string, a: string) => [...auditKeys.all, 'list', e, a] as const };
export function fetchAuditLog(f: { entity?: string; actor?: string; limit?: number }) {
  const p = new URLSearchParams(); if (f.entity) p.set('entity', f.entity); if (f.actor) p.set('actor', f.actor); p.set('limit', String(f.limit ?? 100));
  return api<AuditListResponse>({ path: `/audit/v1/log?${p}` });
}
EOF
W apps/admin-web/src/modules/audit/hooks.ts <<'EOF'
import { useQuery } from '@tanstack/react-query';
import { auditKeys, fetchAuditLog } from './api';
export const useAuditLog = (f: { entity?: string; actor?: string }) => useQuery({ queryKey: auditKeys.list(f.entity ?? '', f.actor ?? ''), queryFn: () => fetchAuditLog(f) });
EOF
W apps/admin-web/src/modules/audit/AuditPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useAuditLog } from './hooks';
const ENTITIES = ['', 'route', 'dock_slot', 'payment', 'credit_override', 'notification'];
export function AuditPage() {
  const { t } = useI18n();
  const [entity, setEntity] = useState(''); const [actor, setActor] = useState('');
  const q = useAuditLog({ entity: entity || undefined, actor: actor || undefined });
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('audit.title')}</h1><p className="text-sm text-muted mt-1">{t('audit.subtitle')}</p></header>
      <div className="flex flex-wrap items-end gap-3 mb-4">
        <label className="text-sm"><span className="text-muted block mb-1">{t('audit.filter.entity')}</span>
          <select value={entity} onChange={(e) => setEntity(e.target.value)} className="rounded-md border border-border bg-surface px-3 py-2 min-w-[160px]">
            {ENTITIES.map((e) => <option key={e} value={e}>{e || t('audit.filter.entity_all')}</option>)}
          </select>
        </label>
        <label className="text-sm"><span className="text-muted block mb-1">{t('audit.filter.actor')}</span>
          <input value={actor} onChange={(e) => setActor(e.target.value)} className="rounded-md border border-border bg-surface px-3 py-2 min-w-[180px]" /></label>
        <button onClick={() => q.refetch()} className="ml-auto text-sm px-3 py-2 rounded-md border border-border bg-surface hover:bg-bg">{t('common.retry')}</button>
      </div>
      {q.isLoading && <Spinner label={t('common.loading')} />}
      {q.data && q.data.entries.length === 0 && <EmptyState title={t('audit.empty')} hint={t('audit.empty_hint')} />}
      {q.data && q.data.entries.length > 0 && (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.when')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.actor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.action')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.entity')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('audit.table.reason')}</th>
          </tr></thead><tbody>{q.data.entries.map((e) => (
            <tr key={e.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 text-xs text-muted whitespace-nowrap">{new Date(e.created_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-xs font-mono">{e.actor_id}</td>
              <td className="px-4 py-3"><StatusPill tone={e.action === 'dispatched' || e.action === 'reconciled' ? 'success' : e.action === 'create' ? 'warn' : 'neutral'}>{e.action}</StatusPill></td>
              <td className="px-4 py-3 text-xs"><div className="font-medium">{e.entity}</div><div className="text-muted font-mono">{e.entity_id}</div></td>
              <td className="px-4 py-3 text-sm max-w-md">{e.reason}</td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/audit/index.ts <<'EOF'
export { AuditPage } from './AuditPage';
export type { AuditLogEntry } from './types';
EOF

# Notifications
W apps/admin-web/src/modules/notifications/types.ts <<'EOF'
export type { NotificationLogEntry, NotificationChannel } from '@tera/contracts';
EOF
W apps/admin-web/src/modules/notifications/api.ts <<'EOF'
import { api } from '../../api/client';
import type { NotificationLogEntry, NotificationChannel } from './types';
export const notifyKeys = { all: ['notifications'] as const, log: (c: string) => [...notifyKeys.all, 'log', c] as const };
export function fetchNotifications(f: { channel?: string }) { const p = new URLSearchParams(); if (f.channel) p.set('channel', f.channel); p.set('limit', '100'); return api<{ total: number; entries: NotificationLogEntry[] }>({ path: `/notify/v1/log?${p}` }); }
export function sendTest(channel: NotificationChannel, recipient: string) { return api<{ id: string; status: string; provider_ref: string | null }>({ method: 'POST', path: '/notify/v1/test', body: { channel, recipient } }); }
EOF
W apps/admin-web/src/modules/notifications/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { notifyKeys, fetchNotifications, sendTest } from './api';
import type { NotificationChannel } from './types';
export const useNotifications = (f: { channel?: string }) => useQuery({ queryKey: notifyKeys.log(f.channel ?? ''), queryFn: () => fetchNotifications(f) });
export function useSendTest() { const qc = useQueryClient(); return useMutation({ mutationFn: (i: { channel: NotificationChannel; recipient: string }) => sendTest(i.channel, i.recipient), onSuccess: () => qc.invalidateQueries({ queryKey: notifyKeys.all }) }); }
EOF
W apps/admin-web/src/modules/notifications/NotificationsPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useNotifications, useSendTest } from './hooks';
import type { NotificationChannel } from './types';
const CHANNELS: { id: NotificationChannel; label: string }[] = [{ id: 'sms', label: 'SMS' }, { id: 'telegram', label: 'Telegram' }, { id: 'email', label: 'Email' }];
export function NotificationsPage() {
  const { t } = useI18n();
  const [filter, setFilter] = useState(''); const [tc, setTc] = useState<NotificationChannel>('sms'); const [tr, setTr] = useState('+251911000001');
  const q = useNotifications({ channel: filter || undefined }); const testMut = useSendTest();
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('notify.title')}</h1><p className="text-sm text-muted mt-1">{t('notify.subtitle')}</p></header>
      <div className="rounded-lg border border-primary/30 bg-primary/5 p-4 mb-6">
        <p className="text-sm font-medium mb-3">{t('notify.test.title')}</p>
        <div className="flex flex-wrap items-end gap-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('notify.test.channel')}</span>
            <select value={tc} onChange={(e) => setTc(e.target.value as NotificationChannel)} className="rounded-md border border-border bg-surface px-3 py-2">
              {CHANNELS.map((c) => <option key={c.id} value={c.id}>{c.label}</option>)}
            </select></label>
          <label className="text-sm flex-1 min-w-[200px]"><span className="text-muted block mb-1">{t('notify.test.recipient')}</span>
            <input value={tr} onChange={(e) => setTr(e.target.value)} className="w-full rounded-md border border-border bg-surface px-3 py-2" /></label>
          <Button onClick={() => testMut.mutate({ channel: tc, recipient: tr.trim() })} loading={testMut.isPending}>{t('notify.test.send')}</Button>
        </div>
        {testMut.data && <p className="text-sm text-success mt-2">✓ {t('notify.test.success', { status: testMut.data.status, ref: testMut.data.provider_ref ?? '—' })}</p>}
      </div>
      <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
        <p className="text-sm text-muted">{q.data?.total ?? 0} {t('notify.log.total')}</p>
        <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
          <button onClick={() => setFilter('')} className={`px-3 py-1.5 text-sm rounded ${filter === '' ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>{t('notify.log.all')}</button>
          {CHANNELS.map((c) => <button key={c.id} onClick={() => setFilter(c.id)} className={`px-3 py-1.5 text-sm rounded ${filter === c.id ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>{c.label}</button>)}
        </div>
      </div>
      {q.isLoading && <Spinner label={t('common.loading')} />}
      {q.data && q.data.entries.length === 0 && <EmptyState title={t('notify.log.empty')} />}
      {q.data && q.data.entries.length > 0 && (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.when')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.channel')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.recipient')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('notify.log.body')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
          </tr></thead><tbody>{q.data.entries.map((e) => (
            <tr key={e.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 text-xs text-muted whitespace-nowrap">{new Date(e.sent_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-xs font-medium uppercase">{e.channel}</td>
              <td className="px-4 py-3 text-xs font-mono">{e.recipient}</td>
              <td className="px-4 py-3 text-sm max-w-md"><div className="text-xs text-muted">{e.template_key}</div><div>{e.rendered_body}</div></td>
              <td className="px-4 py-3 text-right"><StatusPill tone={e.status === 'SENT' ? 'success' : e.status === 'STUB' ? 'warn' : 'danger'}>{e.status}</StatusPill></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/notifications/index.ts <<'EOF'
export { NotificationsPage } from './NotificationsPage';
EOF

# Jobs
W apps/admin-web/src/modules/jobs/types.ts <<'EOF'
export type { JobRun, JobKey, JobStatus, JobScheduleEntry } from '@tera/contracts';
EOF
W apps/admin-web/src/modules/jobs/api.ts <<'EOF'
import { api } from '../../api/client';
import type { JobRun, JobScheduleEntry, JobKey } from './types';
export const jobsKeys = { all: ['jobs'] as const, runs: () => [...jobsKeys.all, 'runs'] as const, schedule: () => [...jobsKeys.all, 'schedule'] as const };
export const fetchRuns = () => api<{ total: number; runs: JobRun[] }>({ path: '/admin/jobs/v1/runs?limit=50' });
export const fetchSchedule = () => api<{ jobs: JobScheduleEntry[] }>({ path: '/admin/jobs/v1/schedule' });
export const runJob = (key: JobKey) => api<{ job_key: JobKey; enqueued: true }>({ method: 'POST', path: `/admin/jobs/v1/${key}/run` });
EOF
W apps/admin-web/src/modules/jobs/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { jobsKeys, fetchRuns, fetchSchedule, runJob } from './api';
import type { JobKey } from './types';
export const useRuns = () => useQuery({ queryKey: jobsKeys.runs(), queryFn: () => fetchRuns(), refetchInterval: 15_000 });
export const useSchedule = () => useQuery({ queryKey: jobsKeys.schedule(), queryFn: () => fetchSchedule(), refetchInterval: 30_000 });
export function useRunJob() { const qc = useQueryClient(); return useMutation({ mutationFn: (k: JobKey) => runJob(k), onSuccess: () => qc.invalidateQueries({ queryKey: jobsKeys.all }) }); }
EOF
W apps/admin-web/src/modules/jobs/JobsPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useRuns, useSchedule, useRunJob } from './hooks';
import type { JobKey, JobStatus } from './types';
function tone(s: JobStatus): 'success' | 'warn' | 'danger' | 'neutral' { if (s === 'DONE') return 'success'; if (s === 'RUNNING') return 'warn'; if (s === 'FAILED') return 'danger'; return 'neutral'; }
export function JobsPage() {
  const { t } = useI18n();
  const scheduleQ = useSchedule(); const runsQ = useRuns(); const runMut = useRunJob();
  const [pending, setPending] = useState<JobKey | null>(null);
  const run = (k: JobKey) => { setPending(k); runMut.mutate(k, { onSettled: () => setPending(null) }); };
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('jobs.title')}</h1><p className="text-sm text-muted mt-1">{t('jobs.subtitle')}</p></header>
      {scheduleQ.isLoading && <Spinner label={t('common.loading')} />}
      {scheduleQ.data && scheduleQ.data.jobs.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-6">
          {scheduleQ.data.jobs.map((s) => (
            <div key={s.job_key} className="border border-border rounded-md bg-surface p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">{t(s.label_key)}</span>
                {s.last_run ? <StatusPill tone={tone(s.last_run.status)}>{s.last_run.status}</StatusPill> : <StatusPill tone="neutral">{t('jobs.never_run')}</StatusPill>}
              </div>
              <div className="text-xs text-muted font-mono">{s.schedule}</div>
              <div className="text-xs text-muted">{t('jobs.next_run')}: {s.next_run_at ? new Date(s.next_run_at).toLocaleString() : '—'}</div>
              {s.last_run && <div className="text-xs text-muted">{s.last_run.processed_count} ✓{s.last_run.skipped_count > 0 && `, ${s.last_run.skipped_count} skipped`}{s.last_run.duration_ms !== null && ` · ${s.last_run.duration_ms}ms`}</div>}
              <Button size="sm" variant="secondary" onClick={() => run(s.job_key)} loading={pending === s.job_key}>{t('jobs.run_now')}</Button>
            </div>
          ))}
        </div>
      )}
      <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('jobs.history')}</h2>
      {runsQ.isLoading && <Spinner label={t('common.loading')} />}
      {runsQ.data && runsQ.data.runs.length === 0 && <EmptyState title={t('jobs.history.empty')} />}
      {runsQ.data && runsQ.data.runs.length > 0 && (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('jobs.table.when')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('jobs.table.job')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-2 font-medium text-muted">{t('jobs.table.processed')}</th>
            <th className="text-right px-4 py-2 font-medium text-muted">{t('jobs.table.duration')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('jobs.table.triggered_by')}</th>
          </tr></thead><tbody>{runsQ.data.runs.map((r) => (
            <tr key={r.id} className="border-b border-border last:border-0">
              <td className="px-4 py-2 text-xs text-muted whitespace-nowrap">{new Date(r.started_at).toLocaleString()}</td>
              <td className="px-4 py-2 font-mono text-xs">{r.job_key}</td>
              <td className="px-4 py-2"><StatusPill tone={tone(r.status)}>{r.status}</StatusPill></td>
              <td className="px-4 py-2 text-right tabular-nums">{r.processed_count}{r.skipped_count > 0 && <span className="text-xs text-muted"> (+{r.skipped_count})</span>}</td>
              <td className="px-4 py-2 text-right tabular-nums text-muted text-xs">{r.duration_ms !== null ? `${r.duration_ms}ms` : '—'}</td>
              <td className="px-4 py-2 text-xs text-muted font-mono">{r.triggered_by}</td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
EOF
W apps/admin-web/src/modules/jobs/index.ts <<'EOF'
export { JobsPage } from './JobsPage';
EOF

# Monitoring
W apps/admin-web/src/modules/monitoring/types.ts <<'EOF'
export type { MonitoringSnapshot } from '@tera/contracts';
EOF
W apps/admin-web/src/modules/monitoring/api.ts <<'EOF'
import { api } from '../../api/client';
import type { MonitoringSnapshot } from './types';
export const monitoringKeys = { all: ['monitoring'] as const, snapshot: () => [...monitoringKeys.all, 'snapshot'] as const };
export const fetchSnapshot = (signal?: AbortSignal) => api<MonitoringSnapshot>({ path: '/admin/monitoring/v1/snapshot', signal });
EOF
W apps/admin-web/src/modules/monitoring/hooks.ts <<'EOF'
import { useQuery } from '@tanstack/react-query';
import { monitoringKeys, fetchSnapshot } from './api';
export const useSnapshot = () => useQuery({ queryKey: monitoringKeys.snapshot(), queryFn: ({ signal }) => fetchSnapshot(signal), refetchInterval: 10_000 });
EOF
W apps/admin-web/src/modules/monitoring/MonitoringPage.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useSnapshot } from './hooks';
export function MonitoringPage() {
  const { t } = useI18n(); const q = useSnapshot();
  if (q.isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">{t('common.error')}</div></div>;
  const s = q.data; const tone = s.http_error_rate_pct > 5 ? 'danger' : s.http_error_rate_pct > 1 ? 'warn' : 'success';
  return (
    <div className="max-w-6xl mx-auto">
      <header className="mb-6 flex items-start justify-between flex-wrap gap-4">
        <div><h1 className="text-2xl font-bold">{t('monitoring.title')}</h1><p className="text-sm text-muted mt-1">{t('monitoring.subtitle')}</p>
          <p className="text-xs text-muted mt-1">{t('monitoring.as_of')}: {new Date(s.as_of).toLocaleTimeString()} · {t('monitoring.uptime')}: {s.uptime_seconds}s</p></div>
        <a href="/metrics" target="_blank" rel="noopener noreferrer" className="text-sm text-primary hover:underline">{t('monitoring.open_prometheus')} ↗</a>
      </header>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <Stat label={t('monitoring.requests_total')} value={s.http_requests_total.toLocaleString()} />
        <Stat label={t('monitoring.requests_5xx')} value={s.http_5xx_total.toLocaleString()} tone={s.http_5xx_total > 0 ? 'danger' : undefined} />
        <Stat label={t('monitoring.error_rate')} value={`${s.http_error_rate_pct.toFixed(2)}%`} pillTone={tone} />
        <Stat label={t('monitoring.uptime')} value={`${s.uptime_seconds}s`} />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <Stat label={t('monitoring.pending_orders')} value={String(s.pending_orders)} />
        <Stat label={t('monitoring.unreconciled')} value={String(s.unreconciled_payments)} />
        <Stat label={t('monitoring.stale_clients')} value={String(s.stale_sync_clients)} tone={s.stale_sync_clients > 3 ? 'warn' : undefined} />
        <Stat label={t('monitoring.high_variance_fuel')} value={String(s.high_variance_fuel_logs_7d)} />
      </div>
      <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('monitoring.jobs_24h')}</h2>
      {s.job_runs_24h.length === 0 ? <EmptyState title={t('monitoring.no_jobs_24h')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('monitoring.job')}</th>
            <th className="text-left px-4 py-2 font-medium text-muted">{t('admin.md.status')}</th>
            <th className="text-right px-4 py-2 font-medium text-muted">{t('monitoring.runs')}</th>
          </tr></thead><tbody>{s.job_runs_24h.map((r, i) => (
            <tr key={`${r.job}-${r.status}-${i}`} className="border-b border-border last:border-0">
              <td className="px-4 py-2 font-mono text-xs">{r.job}</td>
              <td className="px-4 py-2"><StatusPill tone={r.status === 'DONE' ? 'success' : r.status === 'FAILED' ? 'danger' : 'warn'}>{r.status}</StatusPill></td>
              <td className="px-4 py-2 text-right tabular-nums">{r.count}</td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
function Stat({ label, value, tone, pillTone }: { label: string; value: string; tone?: 'danger' | 'warn'; pillTone?: 'success' | 'warn' | 'danger' }) {
  return <div className="border border-border rounded-md bg-surface px-4 py-3">
    <p className="text-xs text-muted uppercase tracking-wide">{label}</p>
    <div className="flex items-center gap-2 mt-1"><p className={`text-xl font-bold tabular-nums ${tone === 'danger' ? 'text-danger' : tone === 'warn' ? 'text-warn' : ''}`}>{value}</p>
      {pillTone && <StatusPill tone={pillTone}>{pillTone === 'success' ? 'OK' : pillTone === 'warn' ? 'watch' : 'high'}</StatusPill>}</div>
  </div>;
}
EOF
W apps/admin-web/src/modules/monitoring/index.ts <<'EOF'
export { MonitoringPage } from './MonitoringPage';
EOF

# Update admin AppLayout + routes
W apps/admin-web/src/app/AppLayout.tsx <<'EOF'
import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';
const NAV = [
  { to: '/masterdata', key: 'admin.nav.masterdata' },
  { to: '/constraints', key: 'admin.nav.constraints' },
  { to: '/audit', key: 'admin.nav.audit' },
  { to: '/notifications', key: 'admin.nav.notifications' },
  { to: '/jobs', key: 'admin.nav.jobs' },
  { to: '/monitoring', key: 'admin.nav.monitoring' },
];
export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="h-full flex">
      <aside className="w-60 shrink-0 border-r border-border bg-surface flex flex-col">
        <div className="px-5 py-4 border-b border-border"><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('admin.title')}</p></div>
        <nav className="flex-1 p-2">{NAV.map((n) => <NavLink key={n.to} to={n.to} className={({ isActive }) => `block px-3 py-2 rounded-md text-sm ${isActive ? 'bg-bg text-text font-medium' : 'text-muted hover:bg-bg'}`}>{t(n.key)}</NavLink>)}</nav>
      </aside>
      <main className="flex-1 min-w-0 overflow-auto p-6"><Outlet /></main>
    </div>
  );
}
EOF
W apps/admin-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { MasterdataPage } from '../modules/masterdata';
import { ConstraintsPage } from '../modules/constraints';
import { AuditPage } from '../modules/audit';
import { NotificationsPage } from '../modules/notifications';
import { JobsPage } from '../modules/jobs';
import { MonitoringPage } from '../modules/monitoring';
const router = createBrowserRouter([{ path: '/', element: <AppLayout />, children: [
  { index: true, element: <Navigate to="/masterdata" replace /> },
  { path: 'masterdata', element: <MasterdataPage /> },
  { path: 'constraints', element: <ConstraintsPage /> },
  { path: 'audit', element: <AuditPage /> },
  { path: 'notifications', element: <NotificationsPage /> },
  { path: 'jobs', element: <JobsPage /> },
  { path: 'monitoring', element: <MonitoringPage /> },
] }]);
export function AppRouter() { return <RouterProvider router={router} />; }
EOF

# ═══════════════════════════════════════════════════════════════════
# Docker-compose final + i18n additions
# ═══════════════════════════════════════════════════════════════════
node <<'NODE'
const fs = require('fs');
const en = JSON.parse(fs.readFileSync('packages/i18n/src/locales/en.json', 'utf8'));
const am = JSON.parse(fs.readFileSync('packages/i18n/src/locales/am.json', 'utf8'));

Object.assign(en, {
  'admin.nav.audit': 'Audit', 'admin.nav.notifications': 'Notifications', 'admin.nav.jobs': 'Jobs', 'admin.nav.monitoring': 'Monitoring',
  'audit.title': 'Audit log', 'audit.subtitle': 'Every consequential action in one chronological record.',
  'audit.filter.entity': 'Entity', 'audit.filter.entity_all': 'All entities', 'audit.filter.actor': 'Actor',
  'audit.empty': 'No audit entries yet', 'audit.empty_hint': 'Actions will appear here automatically.',
  'audit.table.when': 'When', 'audit.table.actor': 'Actor', 'audit.table.action': 'Action', 'audit.table.entity': 'Entity', 'audit.table.reason': 'Reason',
  'notify.title': 'Notifications', 'notify.subtitle': 'Every SMS, Telegram, and email attempt — logged with status.',
  'notify.test.title': 'Send a test notification', 'notify.test.channel': 'Channel', 'notify.test.recipient': 'Recipient', 'notify.test.send': 'Send test',
  'notify.test.success': 'Sent · status {status} · provider ref {ref}',
  'notify.log.total': 'notifications logged', 'notify.log.all': 'All', 'notify.log.empty': 'No notifications yet',
  'notify.log.when': 'When', 'notify.log.channel': 'Channel', 'notify.log.recipient': 'Recipient', 'notify.log.body': 'Body',
  'jobs.title': 'Scheduled jobs', 'jobs.subtitle': 'Nightly jobs for ROI metrics, fuel variance, credit rebuild.',
  'jobs.never_run': 'never run', 'jobs.next_run': 'Next', 'jobs.last_run': 'Last', 'jobs.run_now': 'Run now',
  'jobs.history': 'Run history', 'jobs.history.empty': 'No job runs yet',
  'jobs.table.when': 'When', 'jobs.table.job': 'Job', 'jobs.table.processed': 'Processed', 'jobs.table.duration': 'Duration', 'jobs.table.triggered_by': 'Triggered by',
  'jobs.job.metric_snapshot': 'Metric snapshot', 'jobs.job.credit_rebuild': 'Credit rebuild', 'jobs.job.fuel_variance': 'Fuel variance',
  'monitoring.title': 'Monitoring', 'monitoring.subtitle': 'Live system health — requests, solves, gauges, job runs.',
  'monitoring.as_of': 'As of', 'monitoring.uptime': 'Uptime', 'monitoring.open_prometheus': 'Open /metrics',
  'monitoring.requests_total': 'HTTP requests', 'monitoring.requests_5xx': '5xx errors', 'monitoring.error_rate': 'Error rate',
  'monitoring.pending_orders': 'Pending orders', 'monitoring.unreconciled': 'Unreconciled payments',
  'monitoring.stale_clients': 'Stale sync clients', 'monitoring.high_variance_fuel': 'High-variance fuel (7d)',
  'monitoring.jobs_24h': 'Job runs (last 24h)', 'monitoring.job': 'Job', 'monitoring.runs': 'Runs', 'monitoring.no_jobs_24h': 'No job runs in the last 24h',
});
Object.assign(am, {
  'admin.nav.audit': 'ኦዲት', 'admin.nav.notifications': 'ማሳወቂያዎች', 'admin.nav.jobs': 'ሥራዎች', 'admin.nav.monitoring': 'ክትትል',
  'audit.title': 'የኦዲት መዝገብ', 'audit.subtitle': 'እያንዳንዱ ጠቃሚ እርምጃ',
  'audit.filter.entity': 'አካል', 'audit.filter.entity_all': 'ሁሉም አካላት', 'audit.filter.actor': 'ተዋናይ',
  'audit.empty': 'እስካሁን መዝገብ የለም', 'audit.empty_hint': 'እርምጃዎች በራስ-ሰር ይታያሉ',
  'audit.table.when': 'መቼ', 'audit.table.actor': 'ተዋናይ', 'audit.table.action': 'እርምጃ', 'audit.table.entity': 'አካል', 'audit.table.reason': 'ምክንያት',
  'notify.title': 'ማሳወቂያዎች', 'notify.subtitle': 'እያንዳንዱ የSMS፣ የቴሌግራም እና የኢሜይል ሙከራ',
  'notify.test.title': 'የሙከራ ማሳወቂያ ላክ', 'notify.test.channel': 'ሰርጥ', 'notify.test.recipient': 'ተቀባይ', 'notify.test.send': 'ሙከራ ላክ',
  'notify.test.success': 'ተልኳል · ሁኔታ {status} · ማጣቀሻ {ref}',
  'notify.log.total': 'ማሳወቂያዎች', 'notify.log.all': 'ሁሉም', 'notify.log.empty': 'ማሳወቂያ የለም',
  'notify.log.when': 'መቼ', 'notify.log.channel': 'ሰርጥ', 'notify.log.recipient': 'ተቀባይ', 'notify.log.body': 'ይዘት',
  'jobs.title': 'የተያዙ ሥራዎች', 'jobs.subtitle': 'የሌሊት ሥራዎች',
  'jobs.never_run': 'አልተሠራም', 'jobs.next_run': 'ቀጣይ', 'jobs.last_run': 'የመጨረሻ', 'jobs.run_now': 'አሁን አሂድ',
  'jobs.history': 'የሥራ ታሪክ', 'jobs.history.empty': 'እስካሁን ሩጫ የለም',
  'jobs.table.when': 'መቼ', 'jobs.table.job': 'ሥራ', 'jobs.table.processed': 'የተሠራ', 'jobs.table.duration': 'ቆይታ', 'jobs.table.triggered_by': 'ያስነሳው',
  'jobs.job.metric_snapshot': 'የመለኪያ ቅጽበታዊ እይታ', 'jobs.job.credit_rebuild': 'የክሬዲት ግንባታ', 'jobs.job.fuel_variance': 'የነዳጅ ልዩነት',
  'monitoring.title': 'ክትትል', 'monitoring.subtitle': 'የቀጥታ ስርዓት ጤና',
  'monitoring.as_of': 'እንደ', 'monitoring.uptime': 'የሥራ ጊዜ', 'monitoring.open_prometheus': '/metrics ክፈት',
  'monitoring.requests_total': 'HTTP ጥያቄዎች', 'monitoring.requests_5xx': '5xx ስህተቶች', 'monitoring.error_rate': 'የስህተት መጠን',
  'monitoring.pending_orders': 'በመጠባበቅ ትዕዛዞች', 'monitoring.unreconciled': 'ያልተስተካከሉ ክፍያዎች',
  'monitoring.stale_clients': 'ያረጁ ደንበኞች', 'monitoring.high_variance_fuel': 'ከፍተኛ-ልዩነት ነዳጅ',
  'monitoring.jobs_24h': 'የሥራ ሩጫዎች (24ሰ)', 'monitoring.job': 'ሥራ', 'monitoring.runs': 'ሩጫዎች', 'monitoring.no_jobs_24h': 'ሩጫ የለም',
});

// Exec/finance/portal keys for backend readiness
Object.assign(en, {
  'exec.tile.variable_cost': 'Variable cost / month', 'exec.tile.km': 'Km per delivery', 'exec.tile.delivery_time': 'Median delivery time',
  'exec.tile.on_time': 'On-time SLA', 'exec.tile.stockout': 'Stockout SKU-days', 'exec.tile.dock': 'Dock turnaround',
  'exec.tile.fuel_risk': 'Fuel reserve violations', 'exec.tile.fleet': 'Deliveries/vehicle/day', 'exec.tile.accuracy': 'Clean e-POD', 'exec.tile.credit': 'Credit pre-screen',
  'notify.template.test': 'Test', 'notify.template.eta_alert': 'ETA alert', 'notify.template.order_confirmed': 'Order confirmed', 'notify.template.delivery_completed': 'Delivery completed',
});
Object.assign(am, {
  'exec.tile.variable_cost': 'ተለዋዋጭ ወጪ', 'exec.tile.km': 'ኪሜ በማድረስ', 'exec.tile.delivery_time': 'የማድረስ ጊዜ',
  'exec.tile.on_time': 'በሰዓቱ SLA', 'exec.tile.stockout': 'ከመጋዘን ያለፈ', 'exec.tile.dock': 'የመጫኛ ጊዜ',
  'exec.tile.fuel_risk': 'የነዳጅ ጥሰቶች', 'exec.tile.fleet': 'ማድረሶች/ተሽከርካሪ/ቀን', 'exec.tile.accuracy': 'e-POD መዝገቦች', 'exec.tile.credit': 'ክሬዲት ምርመራ',
  'notify.template.test': 'ሙከራ', 'notify.template.eta_alert': 'ETA ማንቂያ', 'notify.template.order_confirmed': 'ትዕዛዝ ተረጋግጧል', 'notify.template.delivery_completed': 'ማድረስ ተጠናቅቋል',
});

fs.writeFileSync('packages/i18n/src/locales/en.json', JSON.stringify(en, null, 2) + '\n');
fs.writeFileSync('packages/i18n/src/locales/am.json', JSON.stringify(am, null, 2) + '\n');
console.log('  i18n keys updated (audit + notify + jobs + monitoring + exec tiles)');
NODE

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Part 3a complete — backend completion + optimizer + worker + 4 admin tabs"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "What's runnable NOW:"
echo ""
echo "  Backend (7 new modules):"
echo "    • analytics (/analytics/v1/dashboard, /baseline/freeze, /cost-assumptions)"
echo "    • payments (/payments/v1/unreconciled, /:id/reconcile)"
echo "    • portal (/portal/v1/me, /catalog, /orders, /statements, /disputes)"
echo "    • audit (/audit/v1/log)"
echo "    • notify (/notify/v1/log, /templates, /send, /test)"
echo "    • admin/jobs (/admin/jobs/v1/runs, /schedule, /:key/run)"
echo "    • monitoring (/metrics + /admin/monitoring/v1/snapshot)"
echo ""
echo "  Services:"
echo "    • services/optimizer — real BullMQ consumer for route-solve queue"
echo "    • services/worker — 3 nightly jobs (metric_snapshot, credit_rebuild, fuel_variance)"
echo ""
echo "  Admin-web (4 new tabs):"
echo "    • Audit — filterable table with meta JSON"
echo "    • Notifications — send test + log viewer"
echo "    • Jobs — 3 cards + Run now + history table"
echo "    • Monitoring — 8 stat cards + jobs 24h"
echo ""
echo "Setup (5 terminals):"
echo "  pnpm install"
echo "  docker compose up -d mysql redis"
echo "  pnpm db:generate && pnpm db:migrate && pnpm db:seed"
echo ""
echo "  pnpm --filter @tera/api dev              # terminal 1: :8000"
echo "  pnpm --filter @tera/optimizer dev        # terminal 2: VRP worker"
echo "  pnpm --filter @tera/worker dev           # terminal 3: nightly jobs"
echo "  pnpm --filter admin-web dev              # terminal 4: :5175"
echo "  pnpm --filter dispatcher-web dev         # terminal 5: :5173"
echo ""
echo "Try the new tabs at http://localhost:5175:"
echo ""
echo "  AUDIT tab:"
echo "  1. Shows 4 seeded entries (override, dispatch, confirmed, reconciled)"
echo "  2. Filter entity='route' → 1 row"
echo "  3. Every dispatcher dispatch or finance reconcile adds a new entry"
echo ""
echo "  NOTIFICATIONS tab:"
echo "  4. Test panel at top: SMS/Telegram/Email + recipient"
echo "  5. Click 'Send test' → success banner + new row appears in log below"
echo "  6. Server console shows '[SMS STUB] → +251911000001'"
echo "  7. Filter by channel → narrows log"
echo ""
echo "  JOBS tab:"
echo "  8. 3 job cards (Metric snapshot, Credit rebuild, Fuel variance)"
echo "     Each shows schedule (0 22 * * *) + next run + never run"
echo "  9. Click 'Run now' on Metric snapshot"
echo " 10. Worker console: '[worker] ✓ metric_snapshot' + '10 processed, 0 skipped'"
echo " 11. Card updates to DONE with duration + count"
echo " 12. History table shows the run"
echo " 13. Now open exec-web /dashboard (Part 3b) → numbers are real, from worker"
echo ""
echo "  MONITORING tab:"
echo " 14. 4 cards: HTTP requests, 5xx, error rate (0%), uptime"
echo " 15. 4 cards: pending orders (10), unreconciled, stale clients, high-variance fuel"
echo " 16. Job runs 24h table shows any completed runs"
echo " 17. Click 'Open /metrics' → raw Prometheus format"
echo "     Try: curl http://localhost:8000/metrics | head -30"
echo ""
echo "  END-TO-END:"
echo " 18. Open dispatcher-web → dispatch a V-102 route"
echo " 19. Open admin-web → Audit tab → new 'dispatched' entry appears"
echo " 20. Open finance-web (Part 3b) → reconcile a payment"
echo " 21. Audit tab → 'reconciled' entry appears"
echo ""
echo "  ASYNC SOLVE:"
echo " 22. dispatcher-web /builder → select 3 orders + vehicle → Solve"
echo "     → 'Waiting for solver…' → 'Solving route…' → result in ~1s"
echo "     (optimizer process must be running in terminal 2)"
echo " 23. If optimizer not running: 15s stall warning + 'Try sync solve'"
echo ""
echo "Tests:"
echo "  pnpm --filter @tera/api test             # + analytics + payments = 27+"
echo "  pnpm --filter @tera/optimizer test       # 1 state test"
echo "  pnpm --filter @tera/worker test          # 5 metric computer tests"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📌 Build progress:"
echo "  ✓ Part 1a — Phase 0: Foundation"
echo "  ✓ Part 1b — Phases 1-2: Backend (credit/geo/orders/routing)"
echo "  ✓ Part 1c — Phase 2 FE: Dispatcher"
echo "  ✓ Part 2a — Phase 3: Offline sync + Driver"
echo "  ✓ Part 2b — Phases 4-5: Warehouse + Admin"
echo "  ✓ Part 3a — Phases 6 (backend) + 7 (services) + 8 (admin tabs) ← YOU ARE HERE"
echo ""
echo "📌 Next: Part 3b — FINAL"
echo "  • Phase 6 FE: exec-web + finance-web + distributor-portal (3 apps)"
echo "  • Phase 9: final i18n consolidation + smoke-test.sh + docs"
echo "  • Docker compose verification"
echo ""
echo "After Part 3b, the ENTIRE system is complete."
echo "All 8 frontends + 3 backend services + smoke test + docs."
echo ""
echo "Reply 'yes' to finish with Part 3b."
echo "════════════════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════
# PHASE 6 FE — EXEC WEB
# ═══════════════════════════════════════════════════════════════════
echo "▸ Exec web"

W apps/exec-web/package.json <<'EOF'
{
  "name": "exec-web", "private": true, "version": "0.1.0", "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build", "test": "vitest run", "lint": "tsc --noEmit" },
  "dependencies": {
    "react": "^18.3.0", "react-dom": "^18.3.0", "react-router-dom": "^6.24.0", "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*", "@tera/i18n": "workspace:*", "@tera/contracts": "workspace:*"
  },
  "devDependencies": {
    "vite": "^5.3.0", "@vitejs/plugin-react": "^4.3.0", "typescript": "^5.4.0", "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0", "autoprefixer": "^10.4.0", "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0", "@testing-library/jest-dom": "^6.4.0", "jsdom": "^24.1.0",
    "@types/react": "^18.3.0", "@types/react-dom": "^18.3.0"
  }
}
EOF
W apps/exec-web/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "composite": true, "outDir": "dist", "noEmit": true, "types": ["vite/client"] }, "include": ["src"] }
EOF
W apps/exec-web/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], server: { port: 5176 } });
EOF
W apps/exec-web/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], globals: true, css: false } });
EOF
W apps/exec-web/tailwind.config.ts <<'EOF'
import type { Config } from 'tailwindcss';
import preset from '@tera/ui/tailwind-preset';
export default { presets: [preset], content: ['./index.html', './src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'] } satisfies Config;
EOF
W apps/exec-web/postcss.config.cjs <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF
W apps/exec-web/index.html <<'EOF'
<!doctype html>
<html lang="am"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
<link rel="preconnect" href="https://fonts.googleapis.com" /><link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Ethiopic:wght@400;500;600;700&display=swap" rel="stylesheet" />
<title>ተራ OMS · አስፈጻሚ</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
W apps/exec-web/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base { html, body, #root { height: 100%; } body { background-color: theme('colors.bg'); color: theme('colors.text'); font-family: theme('fontFamily.sans'); -webkit-font-smoothing: antialiased; } }
EOF
W apps/exec-web/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_BASE_URL: string; readonly VITE_DEFAULT_LOCALE: string; }
interface ImportMeta { readonly env: ImportMetaEnv; }
EOF
W apps/exec-web/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
W apps/exec-web/src/api/client.ts <<'EOF'
const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); }
}
export async function api<T>({ method = 'GET', path, body, signal }: { method?: string; path: string; body?: unknown; signal?: AbortSignal }): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: body !== undefined ? JSON.stringify(body) : undefined, signal });
  if (!res.ok) { const p = await res.json().catch(() => ({})); throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p); }
  return res.status === 204 ? (undefined as T) : res.json();
}
EOF
W apps/exec-web/src/api/queryClient.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2) } } });
EOF
W apps/exec-web/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { AppRouter } from './app/routes';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AppProviders><AppRouter /></AppProviders></React.StrictMode>);
EOF
W apps/exec-web/src/app/AppProviders.tsx <<'EOF'
import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';
const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';
export function AppProviders({ children }: { children: ReactNode }) {
  return <I18nProvider initialLocale={locale}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></I18nProvider>;
}
EOF
W apps/exec-web/src/app/AppLayout.tsx <<'EOF'
import { Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';
export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="min-h-full bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3">
        <div className="max-w-6xl mx-auto flex items-center gap-4">
          <div className="flex-1"><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('exec.title')}</p></div>
          <p className="text-sm text-muted">{t('exec.tagline')}</p>
        </div>
      </header>
      <main className="p-6"><div className="max-w-6xl mx-auto"><Outlet /></div></main>
    </div>
  );
}
EOF
W apps/exec-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { DashboardPage } from '../modules/money-saved';
const router = createBrowserRouter([{ path: '/', element: <AppLayout />, children: [
  { index: true, element: <Navigate to="/dashboard" replace /> },
  { path: 'dashboard', element: <DashboardPage /> },
] }]);
export function AppRouter() { return <RouterProvider router={router} />; }
EOF

# module: money-saved
W apps/exec-web/src/modules/money-saved/types.ts <<'EOF'
export type { DashboardResponse, Tile, Hero, CostAssumption, MetricKey } from '@tera/contracts';
EOF
W apps/exec-web/src/modules/money-saved/api.ts <<'EOF'
import { api } from '../../api/client';
import type { DashboardResponse, CostAssumption } from './types';
export const dashKeys = { all: ['dashboard'] as const, dashboard: () => [...dashKeys.all, 'dashboard'] as const, assumptions: () => [...dashKeys.all, 'assumptions'] as const };
export function fetchDashboard(signal?: AbortSignal) { return api<DashboardResponse>({ path: '/analytics/v1/dashboard', signal }); }
export function freezeBaseline(notes?: string) { return api<DashboardResponse>({ method: 'POST', path: '/analytics/v1/baseline/freeze', body: notes ? { notes } : {} }); }
export function fetchAssumptions(signal?: AbortSignal) { return api<{ assumptions: CostAssumption[] }>({ path: '/analytics/v1/cost-assumptions', signal }); }
export function updateAssumption(key: string, value: number) { return api<CostAssumption>({ method: 'PATCH', path: `/analytics/v1/cost-assumptions/${key}`, body: { value } }); }
EOF
W apps/exec-web/src/modules/money-saved/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { dashKeys, fetchDashboard, freezeBaseline, fetchAssumptions, updateAssumption } from './api';
export const useDashboard = () => useQuery({ queryKey: dashKeys.dashboard(), queryFn: ({ signal }) => fetchDashboard(signal) });
export function useFreezeBaseline() { const qc = useQueryClient(); return useMutation({ mutationFn: (n?: string) => freezeBaseline(n), onSuccess: () => qc.invalidateQueries({ queryKey: dashKeys.all }) }); }
export const useAssumptions = () => useQuery({ queryKey: dashKeys.assumptions(), queryFn: ({ signal }) => fetchAssumptions(signal) });
export function useUpdateAssumption() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ key, value }: { key: string; value: number }) => updateAssumption(key, value), onSuccess: () => { void qc.invalidateQueries({ queryKey: dashKeys.assumptions() }); void qc.invalidateQueries({ queryKey: dashKeys.dashboard() }); } }); }
EOF
W apps/exec-web/src/modules/money-saved/components/Sparkline.tsx <<'EOF'
export function Sparkline({ data, color, width = 120, height = 28 }: { data: number[]; color: string; width?: number; height?: number }) {
  if (data.length < 2) return <div style={{ width, height }} className="bg-bg rounded" />;
  const min = Math.min(...data); const max = Math.max(...data); const range = max - min || 1; const pad = 2;
  const points = data.map((v, i) => `${((i / (data.length - 1)) * width).toFixed(1)},${(height - pad - ((v - min) / range) * (height - 2 * pad)).toFixed(1)}`).join(' ');
  return <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} role="img"><polyline points={points} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" /></svg>;
}
EOF
W apps/exec-web/src/modules/money-saved/components/HeroTile.tsx <<'EOF'
import { useI18n, formatETB } from '@tera/i18n';
import type { Hero } from '../types';
export function HeroTile({ hero }: { hero: Hero }) {
  const { t } = useI18n();
  return (
    <div className="rounded-lg border border-primary/30 bg-gradient-to-br from-primary/5 to-primary/10 p-8">
      <p className="text-sm font-medium text-primary uppercase tracking-wide mb-2">{t('exec.hero.label')}</p>
      <div className="flex items-baseline gap-3 flex-wrap">
        <p className="text-5xl font-bold text-primary tabular-nums">{formatETB(hero.monthly_savings_etb)}</p>
        <p className="text-sm text-muted">{t('exec.hero.per_month')}</p>
      </div>
      <div className="grid grid-cols-2 gap-4 mt-6 max-w-lg">
        <div><p className="text-xs text-muted uppercase">{t('exec.hero.cumulative')}</p>
          <p className="text-xl font-semibold tabular-nums">{formatETB(hero.cumulative_savings_etb)}</p>
          <p className="text-xs text-muted">{hero.days_since_baseline} {t('exec.hero.days')}</p></div>
        <div><p className="text-xs text-muted uppercase">{t('exec.hero.annualized')}</p>
          <p className="text-xl font-semibold tabular-nums">{formatETB(hero.annualized_savings_etb)}</p>
          <p className="text-xs text-muted">{t('exec.hero.per_year')}</p></div>
      </div>
    </div>
  );
}
EOF
W apps/exec-web/src/modules/money-saved/components/DriverTile.tsx <<'EOF'
import { useI18n, formatETB } from '@tera/i18n';
import { StatusPill } from '@tera/ui';
import { Sparkline } from './Sparkline';
import type { Tile } from '../types';

export function DriverTile({ tile }: { tile: Tile }) {
  const { t } = useI18n();
  const tone: 'success' | 'warn' | 'neutral' = tile.fully_in_target ? 'success' : tile.in_target ? 'warn' : 'neutral';
  const badge = tile.fully_in_target ? t('exec.tile.fully_in_target') : tile.in_target ? t('exec.tile.in_target') : t('exec.tile.below_target');
  const arrow = tile.improvement_pct >= 0 ? '↑' : '↓';
  const sparkColor = tile.fully_in_target ? '#166534' : tile.in_target ? '#b45309' : '#6b6b6b';
  return (
    <div className="rounded-lg border border-border bg-surface p-4 flex flex-col gap-3">
      <div className="flex items-start justify-between gap-2"><p className="text-sm font-medium leading-tight">{t(tile.label_key)}</p><StatusPill tone={tone}>{badge}</StatusPill></div>
      <div className="flex items-baseline gap-2"><p className="text-2xl font-bold tabular-nums">{formatValue(tile.current, tile.unit)}</p><p className="text-xs text-muted">{tile.unit}</p></div>
      <div className="flex items-center justify-between gap-2">
        <div className="text-xs text-muted">{formatValue(tile.baseline, tile.unit)} → {formatValue(tile.current, tile.unit)}
          <span className={`ml-2 font-medium ${tile.improvement_pct >= 0 ? 'text-success' : 'text-danger'}`}>{arrow} {Math.abs(tile.improvement_pct).toFixed(1)}%</span></div>
        <Sparkline data={tile.trend_7d} color={sparkColor} />
      </div>
      {tile.etb_impact !== null && <div className="text-xs text-primary border-t border-border pt-2">≈ {formatETB(tile.etb_impact)} {t('exec.tile.etb_impact')}</div>}
    </div>
  );
}
function formatValue(v: number, unit: string): string {
  if (unit === 'ETB') return new Intl.NumberFormat('en-ET', { maximumFractionDigits: 0 }).format(v);
  if (unit === '%') return `${v.toFixed(1)}%`;
  if (unit === 'SKU-days') return String(Math.round(v));
  return v.toFixed(1);
}
EOF
W apps/exec-web/src/modules/money-saved/components/DemoBanner.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
export function DemoBanner({ onStartRealBaseline, isStarting }: { onStartRealBaseline: () => void; isStarting: boolean }) {
  const { t } = useI18n();
  return (
    <div className="rounded-lg border border-warn/40 bg-warnBg p-4 flex items-start gap-4">
      <div className="text-2xl">⚠</div>
      <div className="flex-1"><p className="font-medium text-warn">{t('exec.demo.title')}</p><p className="text-sm text-muted mt-1">{t('exec.demo.body')}</p></div>
      <Button variant="secondary" onClick={onStartRealBaseline} loading={isStarting}>{t('exec.demo.start')}</Button>
    </div>
  );
}
EOF
W apps/exec-web/src/modules/money-saved/components/AssumptionsPanel.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import { useAssumptions, useUpdateAssumption } from '../hooks';
import type { CostAssumption } from '../types';

const LABELS: Record<string, string> = {
  monthly_deliveries: 'exec.assumption.monthly_deliveries', monthly_routes: 'exec.assumption.monthly_routes',
  daily_vehicles: 'exec.assumption.daily_vehicles', vehicle_wear_etb_per_km: 'exec.assumption.vehicle_wear',
  margin_per_sku_day_etb: 'exec.assumption.margin_sku', cost_per_fuel_incident_etb: 'exec.assumption.fuel_incident',
  avg_margin_per_delivery_etb: 'exec.assumption.margin_delivery',
};
export function AssumptionsPanel() {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const list = useAssumptions(); const update = useUpdateAssumption();
  if (!open) return <button onClick={() => setOpen(true)} className="text-sm text-muted hover:text-text underline">{t('exec.assumptions.configure')}</button>;
  return (
    <div className="rounded-lg border border-border bg-surface p-4">
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm font-semibold">{t('exec.assumptions.title')}</p>
        <button onClick={() => setOpen(false)} className="text-sm text-muted hover:text-text">{t('common.cancel')}</button>
      </div>
      {list.data && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {list.data.assumptions.map((a) => <Row key={a.key} assumption={a} onChange={(v) => update.mutate({ key: a.key, value: v })} isSaving={update.isPending && update.variables?.key === a.key} />)}
        </div>
      )}
    </div>
  );
}
function Row({ assumption, onChange, isSaving }: { assumption: CostAssumption; onChange: (v: number) => void; isSaving: boolean }) {
  const { t } = useI18n();
  const [value, setValue] = useState(String(assumption.value));
  const dirty = parseFloat(value) !== assumption.value;
  return (
    <div className="text-sm"><p className="text-muted mb-1">{t(LABELS[assumption.key] ?? assumption.key)}</p>
      <div className="flex gap-2"><input type="number" value={value} onChange={(e) => setValue(e.target.value)} className="flex-1 rounded-md border border-border bg-bg px-2 py-1" />
        <span className="text-xs text-muted self-center">{assumption.unit}</span>
        {dirty && <Button size="sm" onClick={() => onChange(parseFloat(value))} loading={isSaving}>{t('common.confirm')}</Button>}
      </div></div>
  );
}
EOF
W apps/exec-web/src/modules/money-saved/DashboardPage.tsx <<'EOF'
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner } from '@tera/ui';
import { HeroTile } from './components/HeroTile';
import { DriverTile } from './components/DriverTile';
import { DemoBanner } from './components/DemoBanner';
import { AssumptionsPanel } from './components/AssumptionsPanel';
import { useDashboard, useFreezeBaseline } from './hooks';

export function DashboardPage() {
  const { t } = useI18n();
  const dashQ = useDashboard(); const freezeMut = useFreezeBaseline();
  if (dashQ.isLoading) return <div className="p-8"><Spinner label={t('common.loading')} /></div>;
  if (dashQ.isError || !dashQ.data) return <div className="p-6"><div className="border border-danger/30 bg-dangerBg rounded-md p-4 text-sm text-danger">{t('common.error')}</div></div>;
  const { hero, tiles, is_demo, baseline_frozen_at } = dashQ.data;
  if (!baseline_frozen_at) return <EmptyState title={t('exec.empty.no_baseline')} hint={t('exec.empty.no_baseline_hint')} />;
  return (
    <div className="flex flex-col gap-6">
      <header className="flex items-end justify-between gap-4 flex-wrap">
        <div><h1 className="text-2xl font-bold">{t('exec.heading')}</h1><p className="text-sm text-muted mt-1">{t('exec.as_of')}: {new Date(dashQ.data.as_of).toLocaleString()}</p></div>
        <AssumptionsPanel />
      </header>
      {is_demo && <DemoBanner onStartRealBaseline={() => freezeMut.mutate(undefined, { onSuccess: () => void dashQ.refetch() })} isStarting={freezeMut.isPending} />}
      {hero && <HeroTile hero={hero} />}
      <section>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('exec.tiles.heading')}</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">{tiles.map((tile) => <DriverTile key={tile.metric_key} tile={tile} />)}</div>
      </section>
    </div>
  );
}
EOF
W apps/exec-web/src/modules/money-saved/index.ts <<'EOF'
export { DashboardPage } from './DashboardPage';
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 6 FE — FINANCE WEB
# ═══════════════════════════════════════════════════════════════════
echo "▸ Finance web"

W apps/finance-web/package.json <<'EOF'
{
  "name": "finance-web", "private": true, "version": "0.1.0", "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build", "test": "vitest run", "lint": "tsc --noEmit" },
  "dependencies": {
    "react": "^18.3.0", "react-dom": "^18.3.0", "react-router-dom": "^6.24.0", "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*", "@tera/i18n": "workspace:*", "@tera/contracts": "workspace:*"
  },
  "devDependencies": {
    "vite": "^5.3.0", "@vitejs/plugin-react": "^4.3.0", "typescript": "^5.4.0", "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0", "autoprefixer": "^10.4.0", "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0", "@testing-library/jest-dom": "^6.4.0", "jsdom": "^24.1.0",
    "@types/react": "^18.3.0", "@types/react-dom": "^18.3.0"
  }
}
EOF
W apps/finance-web/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "composite": true, "outDir": "dist", "noEmit": true, "types": ["vite/client"] }, "include": ["src"] }
EOF
W apps/finance-web/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], server: { port: 5177 } });
EOF
W apps/finance-web/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], globals: true, css: false } });
EOF
W apps/finance-web/tailwind.config.ts <<'EOF'
import type { Config } from 'tailwindcss';
import preset from '@tera/ui/tailwind-preset';
export default { presets: [preset], content: ['./index.html', './src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'] } satisfies Config;
EOF
W apps/finance-web/postcss.config.cjs <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF
W apps/finance-web/index.html <<'EOF'
<!doctype html>
<html lang="am"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
<link rel="preconnect" href="https://fonts.googleapis.com" /><link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Ethiopic:wght@400;500;600;700&display=swap" rel="stylesheet" />
<title>ተራ OMS · ፋይናንስ</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
W apps/finance-web/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base { html, body, #root { height: 100%; } body { background-color: theme('colors.bg'); color: theme('colors.text'); font-family: theme('fontFamily.sans'); -webkit-font-smoothing: antialiased; } }
EOF
W apps/finance-web/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_BASE_URL: string; readonly VITE_DEFAULT_LOCALE: string; }
interface ImportMeta { readonly env: ImportMetaEnv; }
EOF
W apps/finance-web/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
W apps/finance-web/src/api/client.ts <<'EOF'
const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); }
}
export async function api<T>({ method = 'GET', path, body, signal }: { method?: string; path: string; body?: unknown; signal?: AbortSignal }): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: body !== undefined ? JSON.stringify(body) : undefined, signal });
  if (!res.ok) { const p = await res.json().catch(() => ({})); throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p); }
  return res.status === 204 ? (undefined as T) : res.json();
}
EOF
W apps/finance-web/src/api/queryClient.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 10_000, retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2) } } });
EOF
W apps/finance-web/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { AppRouter } from './app/routes';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AppProviders><AppRouter /></AppProviders></React.StrictMode>);
EOF
W apps/finance-web/src/app/AppProviders.tsx <<'EOF'
import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';
const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';
export function AppProviders({ children }: { children: ReactNode }) {
  return <I18nProvider initialLocale={locale}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></I18nProvider>;
}
EOF
W apps/finance-web/src/app/AppLayout.tsx <<'EOF'
import { Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';
export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="min-h-full bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3"><div className="max-w-6xl mx-auto flex items-center gap-4">
        <div><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('finance.title')}</p></div>
        <p className="text-sm text-muted ml-auto">{t('finance.tagline')}</p>
      </div></header>
      <main className="p-6"><div className="max-w-6xl mx-auto"><Outlet /></div></main>
    </div>
  );
}
EOF
W apps/finance-web/src/app/routes.tsx <<'EOF'
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { FinancePage } from '../modules/finance';
const router = createBrowserRouter([{ path: '/', element: <AppLayout />, children: [
  { index: true, element: <Navigate to="/finance" replace /> },
  { path: 'finance', element: <FinancePage /> },
] }]);
export function AppRouter() { return <RouterProvider router={router} />; }
EOF

# Finance module
W apps/finance-web/src/modules/finance/tabs/credit-dashboard/api.ts <<'EOF'
import { api } from '../../../../api/client';
import type { ExposureResponse } from '@tera/contracts';
export const exposureKeys = { all: ['credit-exposure'] as const, data: () => [...exposureKeys.all, 'data'] as const };
export const fetchExposure = (signal?: AbortSignal) => api<ExposureResponse>({ path: '/credit/v1/exposure', signal });
EOF
W apps/finance-web/src/modules/finance/tabs/credit-dashboard/hooks.ts <<'EOF'
import { useQuery } from '@tanstack/react-query';
import { exposureKeys, fetchExposure } from './api';
export const useExposure = () => useQuery({ queryKey: exposureKeys.data(), queryFn: ({ signal }) => fetchExposure(signal) });
EOF
W apps/finance-web/src/modules/finance/tabs/credit-dashboard/CreditDashboardTab.tsx <<'EOF'
import { useI18n, formatETB } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useExposure } from './hooks';
import type { AgingBucket, ExposureAccount } from '@tera/contracts';

const BUCKET_TONE: Record<AgingBucket['label'], 'success' | 'warn' | 'danger' | 'neutral'> = { current: 'success', watch: 'warn', overdue: 'danger', critical: 'danger' };

export function CreditDashboardTab() {
  const { t } = useI18n(); const q = useExposure();
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const d = q.data; const maxBucket = Math.max(...d.aging_buckets.map((b) => b.exposure_etb), 1);
  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Stat label={t('finance.credit.total_exposure')} value={formatETB(d.total_exposure_etb)} />
        <Stat label={t('finance.credit.total_limit')} value={formatETB(d.total_limit_etb)} />
        <Stat label={t('finance.credit.utilization')} value={`${d.utilization_pct.toFixed(1)}%`} danger={d.utilization_pct > 80} />
        <Stat label={t('finance.credit.over_limit')} value={String(d.accounts_over_limit)} danger={d.accounts_over_limit > 0} />
      </div>
      <div>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('finance.credit.aging_buckets')}</h2>
        <div className="rounded-lg border border-border bg-surface p-4 flex flex-col gap-3">
          {d.aging_buckets.map((b) => (
            <div key={b.label} className="flex items-center gap-3">
              <div className="w-24 shrink-0"><StatusPill tone={BUCKET_TONE[b.label]}>{t(`finance.credit.bucket.${b.label}`)}</StatusPill></div>
              <div className="text-xs text-muted w-24">{b.days_range}</div>
              <div className="flex-1 bg-bg rounded-full h-3 relative overflow-hidden"><div className={`h-full rounded-full ${b.label === 'current' ? 'bg-success' : b.label === 'watch' ? 'bg-warn' : 'bg-danger'}`} style={{ width: `${(b.exposure_etb / maxBucket) * 100}%` }} /></div>
              <div className="w-32 text-right tabular-nums text-sm font-medium">{formatETB(b.exposure_etb)}</div>
              <div className="w-16 text-right text-xs text-muted">{b.account_count} {t('finance.credit.accounts')}</div>
            </div>
          ))}
        </div>
      </div>
      {d.near_limit_accounts.length > 0 && (
        <div>
          <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('finance.credit.near_limit')} ({d.near_limit_accounts.length})</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">{d.near_limit_accounts.map((a) => <NearLimitCard key={a.distributor_id} account={a} />)}</div>
        </div>
      )}
      <div>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('finance.credit.all_accounts')} ({d.all_accounts.length})</h2>
        {d.all_accounts.length === 0 ? <EmptyState title={t('finance.credit.no_accounts')} /> : (
          <div className="border border-border rounded-md bg-surface overflow-hidden">
            <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('credit.table.distributor')}</th>
              <th className="text-left px-4 py-3 font-medium text-muted">{t('credit.table.region')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.exposure')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.limit')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.utilization')}</th>
              <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.credit.days_overdue')}</th>
            </tr></thead><tbody>{d.all_accounts.map((a) => (
              <tr key={a.distributor_id} className="border-b border-border last:border-0">
                <td className="px-4 py-3 font-medium">{a.distributor_name}</td>
                <td className="px-4 py-3 text-muted">{a.region}</td>
                <td className="px-4 py-3 text-right tabular-nums">{formatETB(a.exposure_etb)}</td>
                <td className="px-4 py-3 text-right tabular-nums text-muted">{formatETB(a.limit_etb)}</td>
                <td className={`px-4 py-3 text-right tabular-nums ${a.utilization_pct > 100 ? 'text-danger font-medium' : a.utilization_pct > 80 ? 'text-warn font-medium' : ''}`}>{a.utilization_pct.toFixed(1)}%</td>
                <td className={`px-4 py-3 text-right tabular-nums ${a.days_overdue > 30 ? 'text-danger font-medium' : a.days_overdue > 0 ? 'text-warn font-medium' : 'text-muted'}`}>{a.days_overdue}</td>
              </tr>
            ))}</tbody></table>
          </div>
        )}
      </div>
    </div>
  );
}
function Stat({ label, value, danger }: { label: string; value: string; danger?: boolean }) {
  return <div className="rounded-lg border border-border bg-surface px-4 py-3"><p className="text-xs text-muted uppercase">{label}</p><p className={`text-xl font-bold tabular-nums mt-1 ${danger ? 'text-danger' : ''}`}>{value}</p></div>;
}
function NearLimitCard({ account }: { account: ExposureAccount }) {
  const { t } = useI18n();
  const tone = account.utilization_pct > 100 ? 'text-danger' : 'text-warn'; const bar = account.utilization_pct > 100 ? 'bg-danger' : 'bg-warn';
  return (
    <div className="rounded-lg border border-border bg-surface p-4">
      <div className="flex items-center justify-between mb-2"><span className="font-medium text-sm">{account.distributor_name}</span><span className={`text-sm font-semibold tabular-nums ${tone}`}>{account.utilization_pct.toFixed(0)}%</span></div>
      <div className="text-xs text-muted mb-2">{formatETB(account.exposure_etb)} / {formatETB(account.limit_etb)}</div>
      <div className="w-full bg-bg rounded-full h-2 overflow-hidden"><div className={`h-full ${bar}`} style={{ width: `${Math.min(account.utilization_pct, 100)}%` }} /></div>
      {account.days_overdue > 0 && <p className="text-xs text-danger mt-2">{account.days_overdue} {t('finance.credit.days_overdue_suffix')}</p>}
    </div>
  );
}
EOF
W apps/finance-web/src/modules/finance/tabs/overrides/api.ts <<'EOF'
import { api } from '../../../../api/client';
import type { OverridesListResponse } from '@tera/contracts';
export const overridesKeys = { all: ['overrides'] as const, list: () => [...overridesKeys.all, 'list'] as const };
export const fetchOverrides = (signal?: AbortSignal) => api<OverridesListResponse>({ path: '/credit/v1/overrides/list', signal });
EOF
W apps/finance-web/src/modules/finance/tabs/overrides/hooks.ts <<'EOF'
import { useQuery } from '@tanstack/react-query';
import { overridesKeys, fetchOverrides } from './api';
export const useOverrides = () => useQuery({ queryKey: overridesKeys.list(), queryFn: ({ signal }) => fetchOverrides(signal) });
EOF
W apps/finance-web/src/modules/finance/tabs/overrides/OverridesTab.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useOverrides } from './hooks';
type Filter = 'all' | 'active' | 'expired';
export function OverridesTab() {
  const { t } = useI18n(); const [filter, setFilter] = useState<Filter>('active'); const q = useOverrides();
  const rows = useMemo(() => { const all = q.data?.overrides ?? []; if (filter === 'active') return all.filter((r) => !r.expired); if (filter === 'expired') return all.filter((r) => r.expired); return all; }, [q.data, filter]);
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <p className="text-sm text-muted">{q.data?.total ?? 0} {t('finance.overrides.total')}</p>
        <div className="inline-flex rounded-md border border-border bg-surface p-1 gap-1">
          {(['active', 'expired', 'all'] as const).map((f) => <button key={f} onClick={() => setFilter(f)} className={`px-3 py-1.5 text-sm rounded ${filter === f ? 'bg-bg font-medium' : 'text-muted hover:bg-bg'}`}>{t(`finance.overrides.filter.${f}`)}</button>)}
        </div>
      </div>
      {rows.length === 0 ? <EmptyState title={t('finance.overrides.empty')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('credit.table.distributor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.reason')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.actor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.created')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.overrides.expires')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">{t('admin.md.status')}</th>
          </tr></thead><tbody>{rows.map((o) => (
            <tr key={o.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3 font-medium">{o.distributor_name}</td>
              <td className="px-4 py-3 text-muted italic max-w-xs truncate">"{o.reason}"</td>
              <td className="px-4 py-3 text-xs text-muted font-mono">{o.actor_id}</td>
              <td className="px-4 py-3 text-xs text-muted">{new Date(o.created_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-xs text-muted">{new Date(o.expires_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-right"><StatusPill tone={o.expired ? 'neutral' : 'success'}>{o.expired ? t('finance.overrides.status.expired') : t('finance.overrides.status.active')}</StatusPill></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
    </div>
  );
}
EOF
W apps/finance-web/src/modules/finance/tabs/reconciliation/api.ts <<'EOF'
import { api } from '../../../../api/client';
import type { UnreconciledPaymentsResponse } from '@tera/contracts';
export const reconciliationKeys = { all: ['reconciliation'] as const, list: () => [...reconciliationKeys.all, 'unreconciled'] as const };
export const fetchUnreconciled = (signal?: AbortSignal) => api<UnreconciledPaymentsResponse>({ path: '/payments/v1/unreconciled', signal });
export function reconcilePayment(id: string, notes?: string) { return api<{ ok: true; reconciled_at: string }>({ method: 'POST', path: `/payments/v1/${id}/reconcile`, body: notes ? { notes } : {} }); }
EOF
W apps/finance-web/src/modules/finance/tabs/reconciliation/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { reconciliationKeys, fetchUnreconciled, reconcilePayment } from './api';
export const useUnreconciled = () => useQuery({ queryKey: reconciliationKeys.list(), queryFn: ({ signal }) => fetchUnreconciled(signal) });
export function useReconcile() { const qc = useQueryClient(); return useMutation({ mutationFn: ({ id, notes }: { id: string; notes?: string }) => reconcilePayment(id, notes), onSuccess: () => qc.invalidateQueries({ queryKey: reconciliationKeys.all }) }); }
EOF
W apps/finance-web/src/modules/finance/tabs/reconciliation/ReconciliationTab.tsx <<'EOF'
import { useState } from 'react';
import { useI18n, formatETB } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useUnreconciled, useReconcile } from './hooks';
export function ReconciliationTab() {
  const { t } = useI18n(); const q = useUnreconciled(); const reconcile = useReconcile(); const [pending, setPending] = useState<string | null>(null);
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const payments = q.data?.payments ?? [];
  return (
    <div className="flex flex-col gap-4">
      <header className="flex items-center justify-between flex-wrap gap-3">
        <div><h2 className="text-lg font-semibold">{t('finance.recon.title')}</h2><p className="text-sm text-muted">{t('finance.recon.subtitle')}</p></div>
        <p className="text-sm text-muted">{payments.length} {t('finance.recon.pending')}</p>
      </header>
      {reconcile.isError && <div className="text-sm text-danger border border-danger/30 bg-dangerBg rounded px-3 py-2">{(reconcile.error as Error).message}</div>}
      {payments.length === 0 ? <EmptyState title={t('finance.recon.empty')} /> : (
        <div className="border border-border rounded-md bg-surface overflow-hidden">
          <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.distributor')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.vehicle')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.method')}</th>
            <th className="text-right px-4 py-3 font-medium text-muted">{t('finance.recon.amount')}</th>
            <th className="text-left px-4 py-3 font-medium text-muted">{t('finance.recon.captured')}</th>
            <th className="text-right px-4 py-3"></th>
          </tr></thead><tbody>{payments.map((p) => (
            <tr key={p.id} className="border-b border-border last:border-0">
              <td className="px-4 py-3"><div className="font-medium">{p.distributor_name}</div><div className="text-xs text-muted">{p.driver_id}</div></td>
              <td className="px-4 py-3 text-sm">{p.vehicle_id}</td>
              <td className="px-4 py-3"><StatusPill tone={p.method === 'TELEBIRR' ? 'success' : 'neutral'}>{p.method}</StatusPill>{p.telebirr_ref && <div className="text-xs text-muted font-mono mt-1">{p.telebirr_ref}</div>}</td>
              <td className="px-4 py-3 text-right tabular-nums font-medium">{formatETB(p.amount_etb)}</td>
              <td className="px-4 py-3 text-xs text-muted">{new Date(p.captured_at).toLocaleString()}</td>
              <td className="px-4 py-3 text-right"><Button size="sm" loading={reconcile.isPending && pending === p.id} onClick={() => { setPending(p.id); reconcile.mutate({ id: p.id }, { onSettled: () => setPending(null) }); }}>{t('finance.recon.reconcile')}</Button></td>
            </tr>
          ))}</tbody></table>
        </div>
      )}
      <div className="text-xs text-muted rounded-md border border-border bg-surface p-3">{t('finance.recon.hint')}</div>
    </div>
  );
}
EOF
W apps/finance-web/src/modules/finance/FinancePage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { CreditDashboardTab } from './tabs/credit-dashboard/CreditDashboardTab';
import { OverridesTab } from './tabs/overrides/OverridesTab';
import { ReconciliationTab } from './tabs/reconciliation/ReconciliationTab';
type Tab = 'credit' | 'overrides' | 'reconciliation';
const TABS: { id: Tab; key: string }[] = [{ id: 'credit', key: 'finance.tab.credit' }, { id: 'overrides', key: 'finance.tab.overrides' }, { id: 'reconciliation', key: 'finance.tab.reconciliation' }];
export function FinancePage() {
  const { t } = useI18n(); const [tab, setTab] = useState<Tab>('credit');
  return (
    <div>
      <header className="mb-6"><h1 className="text-2xl font-bold">{t('finance.heading')}</h1><p className="text-sm text-muted mt-1">{t('finance.heading_hint')}</p></header>
      <div className="border-b border-border mb-6"><nav className="flex gap-1 -mb-px">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </nav></div>
      {tab === 'credit' && <CreditDashboardTab />}
      {tab === 'overrides' && <OverridesTab />}
      {tab === 'reconciliation' && <ReconciliationTab />}
    </div>
  );
}
EOF
W apps/finance-web/src/modules/finance/index.ts <<'EOF'
export { FinancePage } from './FinancePage';
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 6 FE — DISTRIBUTOR PORTAL
# ═══════════════════════════════════════════════════════════════════
echo "▸ Distributor portal"

W apps/distributor-portal/package.json <<'EOF'
{
  "name": "distributor-portal", "private": true, "version": "0.1.0", "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build", "test": "vitest run", "lint": "tsc --noEmit" },
  "dependencies": {
    "react": "^18.3.0", "react-dom": "^18.3.0", "react-router-dom": "^6.24.0", "@tanstack/react-query": "^5.50.0",
    "@tera/ui": "workspace:*", "@tera/i18n": "workspace:*", "@tera/contracts": "workspace:*"
  },
  "devDependencies": {
    "vite": "^5.3.0", "@vitejs/plugin-react": "^4.3.0", "typescript": "^5.4.0", "vitest": "^1.6.0",
    "tailwindcss": "^3.4.0", "autoprefixer": "^10.4.0", "postcss": "^8.4.0",
    "@testing-library/react": "^16.0.0", "@testing-library/jest-dom": "^6.4.0", "jsdom": "^24.1.0",
    "@types/react": "^18.3.0", "@types/react-dom": "^18.3.0"
  }
}
EOF
W apps/distributor-portal/tsconfig.json <<'EOF'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "composite": true, "outDir": "dist", "noEmit": true, "types": ["vite/client"] }, "include": ["src"] }
EOF
W apps/distributor-portal/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], server: { port: 5178 } });
EOF
W apps/distributor-portal/vitest.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({ plugins: [react()], test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], globals: true, css: false } });
EOF
W apps/distributor-portal/tailwind.config.ts <<'EOF'
import type { Config } from 'tailwindcss';
import preset from '@tera/ui/tailwind-preset';
export default { presets: [preset], content: ['./index.html', './src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'] } satisfies Config;
EOF
W apps/distributor-portal/postcss.config.cjs <<'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF
W apps/distributor-portal/index.html <<'EOF'
<!doctype html>
<html lang="am"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
<link rel="preconnect" href="https://fonts.googleapis.com" /><link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Ethiopic:wght@400;500;600;700&display=swap" rel="stylesheet" />
<title>ተራ OMS · አከፋፋይ</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
W apps/distributor-portal/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base { html, body, #root { height: 100%; } body { background-color: theme('colors.bg'); color: theme('colors.text'); font-family: theme('fontFamily.sans'); -webkit-font-smoothing: antialiased; } }
EOF
W apps/distributor-portal/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_BASE_URL: string; readonly VITE_DEFAULT_LOCALE: string; }
interface ImportMeta { readonly env: ImportMetaEnv; }
EOF
W apps/distributor-portal/src/test/setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
EOF
W apps/distributor-portal/src/api/client.ts <<'EOF'
const BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
export const DISTRIBUTOR_KEY = 'tera_distributor_id';
export class ApiError extends Error { constructor(public status: number, public code: string, message: string, public details?: unknown) { super(message); } }
export function getCurrentDistributor(): string | null { return localStorage.getItem(DISTRIBUTOR_KEY); }
export function setCurrentDistributor(id: string): void { localStorage.setItem(DISTRIBUTOR_KEY, id); }
export async function api<T>({ method = 'GET', path, body, signal }: { method?: string; path: string; body?: unknown; signal?: AbortSignal }): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const id = getCurrentDistributor(); if (id) headers['X-Distributor-Id'] = id;
  const res = await fetch(`${BASE}${path}`, { method, headers, body: body !== undefined ? JSON.stringify(body) : undefined, signal });
  if (!res.ok) { const p = await res.json().catch(() => ({})); throw new ApiError(res.status, p.code ?? 'unknown', p.message ?? res.statusText, p); }
  return res.status === 204 ? (undefined as T) : res.json();
}
EOF
W apps/distributor-portal/src/api/queryClient.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './client';
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 10_000, retry: (n, e) => (e instanceof ApiError && e.status < 500 ? false : n < 2) } } });
EOF
W apps/distributor-portal/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { PortalPage } from './modules/portal/PortalPage';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AppProviders><PortalPage /></AppProviders></React.StrictMode>);
EOF
W apps/distributor-portal/src/app/AppProviders.tsx <<'EOF'
import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';
const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';
export function AppProviders({ children }: { children: ReactNode }) {
  return <I18nProvider initialLocale={locale}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></I18nProvider>;
}
EOF

# Portal module — 4 tabs
W apps/distributor-portal/src/modules/portal/types.ts <<'EOF'
export type { PortalProfile, CatalogItem, PlaceOrderRequest, PlaceOrderResponse, PortalOrderSummary, PortalOrdersResponse, PortalOrderDetail, StatementResponse, DisputeRow, RaiseDisputeRequest } from '@tera/contracts';
export type Tab = 'order' | 'track' | 'statements' | 'disputes';
EOF
W apps/distributor-portal/src/modules/portal/api.ts <<'EOF'
import { api } from '../../api/client';
import type { PortalProfile, CatalogItem, PlaceOrderRequest, PlaceOrderResponse, PortalOrdersResponse, StatementResponse, DisputeRow, RaiseDisputeRequest } from './types';
export const portalKeys = {
  all: ['portal'] as const, me: () => [...portalKeys.all, 'me'] as const, catalog: () => [...portalKeys.all, 'catalog'] as const,
  orders: () => [...portalKeys.all, 'orders'] as const, statements: () => [...portalKeys.all, 'statements'] as const, disputes: () => [...portalKeys.all, 'disputes'] as const,
};
export const fetchMe = (signal?: AbortSignal) => api<PortalProfile>({ path: '/portal/v1/me', signal });
export const fetchCatalog = (signal?: AbortSignal) => api<{ items: CatalogItem[] }>({ path: '/portal/v1/catalog', signal });
export const placeOrder = (body: PlaceOrderRequest) => api<PlaceOrderResponse>({ method: 'POST', path: '/portal/v1/orders', body });
export const fetchOrders = (signal?: AbortSignal) => api<PortalOrdersResponse>({ path: '/portal/v1/orders', signal });
export const fetchStatements = (signal?: AbortSignal) => api<StatementResponse>({ path: '/portal/v1/statements', signal });
export const raiseDispute = (body: RaiseDisputeRequest) => api<{ disputes: DisputeRow[] }>({ method: 'POST', path: '/portal/v1/disputes', body });
export const fetchDisputes = (signal?: AbortSignal) => api<{ disputes: DisputeRow[] }>({ path: '/portal/v1/disputes', signal });
EOF
W apps/distributor-portal/src/modules/portal/hooks.ts <<'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { portalKeys, fetchMe, fetchCatalog, placeOrder, fetchOrders, fetchStatements, raiseDispute, fetchDisputes } from './api';
import type { PlaceOrderRequest, RaiseDisputeRequest } from './types';
export const useMe = () => useQuery({ queryKey: portalKeys.me(), queryFn: ({ signal }) => fetchMe(signal) });
export const useCatalog = () => useQuery({ queryKey: portalKeys.catalog(), queryFn: ({ signal }) => fetchCatalog(signal) });
export function usePlaceOrder() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: PlaceOrderRequest) => placeOrder(b), onSuccess: () => { void qc.invalidateQueries({ queryKey: portalKeys.orders() }); void qc.invalidateQueries({ queryKey: portalKeys.me() }); void qc.invalidateQueries({ queryKey: portalKeys.statements() }); } }); }
export const useOrders = () => useQuery({ queryKey: portalKeys.orders(), queryFn: ({ signal }) => fetchOrders(signal), refetchInterval: 30_000 });
export const useStatements = () => useQuery({ queryKey: portalKeys.statements(), queryFn: ({ signal }) => fetchStatements(signal) });
export const useDisputes = () => useQuery({ queryKey: portalKeys.disputes(), queryFn: ({ signal }) => fetchDisputes(signal) });
export function useRaiseDispute() { const qc = useQueryClient(); return useMutation({ mutationFn: (b: RaiseDisputeRequest) => raiseDispute(b), onSuccess: () => qc.invalidateQueries({ queryKey: portalKeys.disputes() }) }); }
EOF
W apps/distributor-portal/src/modules/portal/components/DistributorSwitcher.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { getCurrentDistributor, setCurrentDistributor } from '../../../api/client';
const KNOWN = [
  { id: 'seed-dist-1', name: 'Abebe Distribution' }, { id: 'seed-dist-2', name: 'Bole Wholesale Co.' },
  { id: 'seed-dist-3', name: 'Kazanchis Distributors' }, { id: 'seed-dist-4', name: 'Sarbet Traders' }, { id: 'seed-dist-5', name: 'CMC Retailers' },
];
export function DistributorSwitcher() {
  const { t } = useI18n(); const current = getCurrentDistributor() ?? KNOWN[0]!.id; const [open, setOpen] = useState(false);
  const pick = (id: string) => { setCurrentDistributor(id); window.location.reload(); };
  return (
    <div className="relative">
      <button onClick={() => setOpen((v) => !v)} className="text-sm px-3 py-1.5 rounded-md border border-border bg-surface hover:bg-bg">{t('portal.switcher.label')} ▾</button>
      {open && <div className="absolute right-0 top-full mt-1 z-20 min-w-[220px] border border-border bg-surface rounded-md shadow-md">{KNOWN.map((d) => <button key={d.id} onClick={() => pick(d.id)} className={`block w-full text-left px-3 py-2 text-sm hover:bg-bg ${current === d.id ? 'font-medium bg-bg' : ''}`}>{d.name}</button>)}</div>}
    </div>
  );
}
EOF
W apps/distributor-portal/src/modules/portal/tabs/OrderTab.tsx <<'EOF'
import { useMemo, useState } from 'react';
import { useI18n, formatETB } from '@tera/i18n';
import { Button, EmptyState, Spinner } from '@tera/ui';
import { useCatalog, useMe, usePlaceOrder } from '../hooks';
import type { CatalogItem } from '../types';
export function OrderTab() {
  const { t } = useI18n();
  const catalogQ = useCatalog(); const meQ = useMe(); const placeMut = usePlaceOrder();
  const [cart, setCart] = useState<Map<string, number>>(new Map());
  const [success, setSuccess] = useState<{ orderId: string; total: number } | null>(null);
  const items = catalogQ.data?.items ?? []; const byId = useMemo(() => new Map(items.map((i) => [i.sku_id, i])), [items]);
  const cartLines = useMemo(() => { const out: { item: CatalogItem; qty: number; subtotal: number }[] = []; for (const [id, qty] of cart) { const it = byId.get(id); if (it) out.push({ item: it, qty, subtotal: qty * it.unit_price_etb }); } return out; }, [cart, byId]);
  const total = cartLines.reduce((s, l) => s + l.subtotal, 0); const headroom = meQ.data?.headroom_etb ?? 0;
  const exceeds = total > headroom; const count = cartLines.reduce((s, l) => s + l.qty, 0);
  const setQty = (id: string, q: number) => { const n = new Map(cart); if (q <= 0) n.delete(id); else n.set(id, q); setCart(n); setSuccess(null); };
  if (catalogQ.isLoading || meQ.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (catalogQ.isError || meQ.isError) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-6">
      <div>
        <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.order.catalog')}</h2>
        {items.length === 0 ? <EmptyState title={t('portal.order.no_skus')} /> : (
          <div className="flex flex-col gap-2">{items.map((it) => { const q = cart.get(it.sku_id) ?? 0; const tone = it.stock_on_hand === 0 ? 'text-danger' : it.stock_on_hand < 100 ? 'text-warn' : 'text-success';
            return <div key={it.sku_id} className="border border-border rounded-md bg-surface p-3 flex items-center gap-3">
              <div className="flex-1 min-w-0"><div className="font-medium">{it.name}</div>
                <div className="text-xs text-muted">{it.code} · {formatETB(it.unit_price_etb)} / {it.unit} · <span className={tone}>{it.stock_on_hand} {t('portal.order.in_stock')}</span></div></div>
              <div className="flex items-center gap-1">
                <Button size="sm" variant="ghost" onClick={() => setQty(it.sku_id, q - 1)} disabled={q === 0}>−</Button>
                <input type="number" min={0} max={it.stock_on_hand} value={q} onChange={(e) => setQty(it.sku_id, Math.min(it.stock_on_hand, Math.max(0, parseInt(e.target.value, 10) || 0)))} className="w-16 text-center rounded-md border border-border bg-bg px-2 py-1 text-sm tabular-nums" />
                <Button size="sm" variant="ghost" onClick={() => setQty(it.sku_id, Math.min(it.stock_on_hand, q + 1))}>+</Button>
              </div></div>; })}</div>
        )}
      </div>
      <aside className="lg:sticky lg:top-4 self-start flex flex-col gap-3">
        <div className="border border-border rounded-md bg-surface p-4">
          <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.order.cart')}</h2>
          {cartLines.length === 0 ? <p className="text-sm text-muted">{t('portal.order.cart_empty')}</p> : (
            <div className="flex flex-col gap-1.5 mb-3">{cartLines.map((l) => <div key={l.item.sku_id} className="flex justify-between text-sm"><span>{l.qty}× {l.item.name}</span><span className="tabular-nums">{formatETB(l.subtotal)}</span></div>)}</div>
          )}
          <div className="border-t border-border pt-2 flex justify-between font-medium"><span>{t('portal.order.total')}</span><span className="tabular-nums">{formatETB(total)}</span></div>
        </div>
        <div className={`rounded-md border p-4 ${exceeds ? 'border-danger/40 bg-dangerBg' : 'border-border bg-surface'}`}>
          <p className="text-xs text-muted uppercase">{t('portal.order.headroom')}</p>
          <p className={`text-xl font-bold tabular-nums ${exceeds ? 'text-danger' : ''}`}>{formatETB(headroom)}</p>
          {count > 0 && <p className={`text-xs mt-1 ${exceeds ? 'text-danger font-medium' : 'text-muted'}`}>{exceeds ? t('portal.order.exceeds', { over: formatETB(total - headroom) }) : t('portal.order.after', { remaining: formatETB(headroom - total) })}</p>}
        </div>
        <Button size="lg" className="w-full" disabled={count === 0 || exceeds} loading={placeMut.isPending}
          onClick={() => placeMut.mutate({ lines: cartLines.map((l) => ({ sku_id: l.item.sku_id, quantity: l.qty })) }, { onSuccess: (r) => { setSuccess({ orderId: r.order_id, total: r.total_etb }); setCart(new Map()); } })}>
          {t('portal.order.place', { n: count })}
        </Button>
        {placeMut.isError && <div className="text-sm text-danger border border-danger/30 bg-dangerBg rounded px-3 py-2">{(placeMut.error as Error).message}</div>}
        {success && <div className="text-sm text-success border border-success/30 bg-successBg rounded px-3 py-2">✓ {t('portal.order.success', { total: formatETB(success.total) })}</div>}
      </aside>
    </div>
  );
}
EOF
W apps/distributor-portal/src/modules/portal/tabs/TrackTab.tsx <<'EOF'
import { useI18n, formatETB } from '@tera/i18n';
import { EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useOrders } from '../hooks';
import type { PortalOrderSummary } from '../types';
function tone(s: PortalOrderSummary['status']): 'success' | 'warn' | 'danger' | 'neutral' { if (s === 'DELIVERED') return 'success'; if (s === 'ROUTED') return 'warn'; if (s === 'FAILED') return 'danger'; return 'neutral'; }
export function TrackTab() {
  const { t } = useI18n(); const q = useOrders();
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  return (
    <div className="flex flex-col gap-6">
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.track.active')} ({q.data.active.length})</h2>
        {q.data.active.length === 0 ? <EmptyState title={t('portal.track.no_active')} hint={t('portal.track.no_active_hint')} /> :
          <div className="flex flex-col gap-2">{q.data.active.map((o) => <Card key={o.order_id} order={o} />)}</div>}</section>
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.track.recent')} ({q.data.recent.length})</h2>
        {q.data.recent.length === 0 ? <EmptyState title={t('portal.track.no_recent')} /> :
          <div className="flex flex-col gap-2">{q.data.recent.map((o) => <Card key={o.order_id} order={o} compact />)}</div>}</section>
    </div>
  );
}
function Card({ order, compact }: { order: PortalOrderSummary; compact?: boolean }) {
  const { t } = useI18n();
  const eta = order.eta ? new Date(order.eta) : null;
  return (
    <div className={`border rounded-md bg-surface p-4 ${compact ? 'py-3' : ''}`}>
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div><div className="font-medium text-sm font-mono">{order.order_id}</div>
          <div className="text-xs text-muted mt-1">{new Date(order.created_at).toLocaleString()} · {order.line_count} {t('portal.track.lines')} · {order.total_quantity} {t('portal.track.items')}</div></div>
        <div className="flex items-center gap-3"><span className="tabular-nums font-medium">{formatETB(order.total_etb)}</span><StatusPill tone={tone(order.status)}>{order.status}</StatusPill></div>
      </div>
      {eta && !compact && <div className="mt-3 pt-3 border-t border-border flex items-center justify-between text-sm">
        <div><span className="text-muted">{t('portal.track.eta')}: </span><span className="font-medium">{eta.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
          {order.vehicle_id && <><span className="text-muted"> · {t('portal.track.vehicle')}: </span><span className="font-medium">{order.vehicle_id}</span></>}</div></div>}
    </div>
  );
}
EOF
W apps/distributor-portal/src/modules/portal/tabs/StatementsTab.tsx <<'EOF'
import { useI18n, formatETB } from '@tera/i18n';
import { EmptyState, Spinner } from '@tera/ui';
import { useStatements } from '../hooks';
export function StatementsTab() {
  const { t } = useI18n(); const q = useStatements();
  if (q.isLoading) return <div className="p-6"><Spinner label={t('common.loading')} /></div>;
  if (q.isError || !q.data) return <div className="text-sm text-danger p-4">{t('common.error')}</div>;
  const s = q.data; const pct = s.limit_etb > 0 ? (s.balance_etb / s.limit_etb) * 100 : 0;
  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Stat label={t('portal.statements.balance')} value={formatETB(s.balance_etb)} />
        <Stat label={t('portal.statements.limit')} value={formatETB(s.limit_etb)} />
        <Stat label={t('portal.statements.utilization')} value={`${pct.toFixed(0)}%`} danger={pct > 80} />
        <Stat label={t('portal.statements.oldest_unpaid')} value={s.days_since_oldest_unpaid !== null ? `${s.days_since_oldest_unpaid}d` : '—'} danger={s.days_since_oldest_unpaid !== null && s.days_since_oldest_unpaid > s.grace_days} />
      </div>
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.statements.recent_deliveries')}</h2>
        {s.recent_deliveries.length === 0 ? <EmptyState title={t('portal.statements.no_deliveries')} /> : (
          <div className="border border-border rounded-md bg-surface overflow-hidden">
            <table className="w-full text-sm"><thead className="bg-bg border-b border-border"><tr>
              <th className="text-left px-4 py-2 font-medium text-muted">{t('portal.statements.date')}</th>
              <th className="text-left px-4 py-2 font-medium text-muted">{t('portal.statements.order')}</th>
              <th className="text-left px-4 py-2 font-medium text-muted">{t('portal.statements.vehicle')}</th>
              <th className="text-right px-4 py-2 font-medium text-muted">{t('portal.statements.qty')}</th>
            </tr></thead><tbody>{s.recent_deliveries.map((d) => (
              <tr key={d.order_id} className="border-b border-border last:border-0">
                <td className="px-4 py-2 text-muted text-xs">{new Date(d.delivered_at).toLocaleString()}</td>
                <td className="px-4 py-2 text-xs font-mono">{d.order_id}</td>
                <td className="px-4 py-2">{d.vehicle_id}</td>
                <td className="px-4 py-2 text-right tabular-nums">{d.total_quantity}</td>
              </tr>
            ))}</tbody></table>
          </div>
        )}</section>
    </div>
  );
}
function Stat({ label, value, danger }: { label: string; value: string; danger?: boolean }) {
  return <div className="rounded-lg border border-border bg-surface px-4 py-3"><p className="text-xs text-muted uppercase">{label}</p><p className={`text-xl font-bold tabular-nums mt-1 ${danger ? 'text-danger' : ''}`}>{value}</p></div>;
}
EOF
W apps/distributor-portal/src/modules/portal/tabs/DisputesTab.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, EmptyState, Spinner, StatusPill } from '@tera/ui';
import { useOrders, useDisputes, useRaiseDispute } from '../hooks';
import type { RaiseDisputeRequest } from '../types';
type T = 'QUANTITY' | 'WRONG_ITEM' | 'NEVER_DELIVERED' | 'DAMAGED' | 'OTHER';
const TYPES: T[] = ['QUANTITY', 'WRONG_ITEM', 'NEVER_DELIVERED', 'DAMAGED', 'OTHER'];
export function DisputesTab() {
  const { t } = useI18n(); const ordersQ = useOrders(); const disputesQ = useDisputes(); const raiseMut = useRaiseDispute();
  const [orderId, setOrderId] = useState(''); const [type, setType] = useState<T>('QUANTITY'); const [desc, setDesc] = useState('');
  const all = [...(ordersQ.data?.active ?? []), ...(ordersQ.data?.recent ?? [])];
  const canSubmit = orderId && desc.trim().length >= 10;
  const submit = () => { if (!canSubmit) return; const b: RaiseDisputeRequest = { order_id: orderId, type, description: desc.trim() }; raiseMut.mutate(b, { onSuccess: () => { setOrderId(''); setDesc(''); } }); };
  return (
    <div className="flex flex-col gap-6">
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.disputes.raise')}</h2>
        <div className="border border-border rounded-md bg-surface p-4 flex flex-col gap-3">
          <label className="text-sm"><span className="text-muted block mb-1">{t('portal.disputes.order')}</span>
            <select value={orderId} onChange={(e) => setOrderId(e.target.value)} className="w-full rounded-md border border-border bg-bg px-3 py-2"><option value="">{t('portal.disputes.pick_order')}</option>
              {all.map((o) => <option key={o.order_id} value={o.order_id}>{o.order_id} ({o.status}) — {o.total_quantity} items</option>)}</select></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('portal.disputes.type')}</span>
            <select value={type} onChange={(e) => setType(e.target.value as T)} className="w-full rounded-md border border-border bg-bg px-3 py-2">
              {TYPES.map((tt) => <option key={tt} value={tt}>{t(`portal.disputes.type.${tt}`)}</option>)}</select></label>
          <label className="text-sm"><span className="text-muted block mb-1">{t('portal.disputes.description')}</span>
            <textarea value={desc} onChange={(e) => setDesc(e.target.value)} rows={3} className="w-full rounded-md border border-border bg-bg px-3 py-2" /></label>
          {raiseMut.isError && <p className="text-sm text-danger">{(raiseMut.error as Error).message}</p>}
          <div className="flex justify-end"><Button onClick={submit} disabled={!canSubmit} loading={raiseMut.isPending}>{t('portal.disputes.submit')}</Button></div>
        </div></section>
      <section><h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-3">{t('portal.disputes.past')} ({disputesQ.data?.disputes.length ?? 0})</h2>
        {disputesQ.isLoading && <Spinner label={t('common.loading')} />}
        {disputesQ.data && disputesQ.data.disputes.length === 0 && <EmptyState title={t('portal.disputes.empty')} />}
        {disputesQ.data && disputesQ.data.disputes.length > 0 && <div className="flex flex-col gap-2">{disputesQ.data.disputes.map((d) => (
          <div key={d.id} className="border border-border rounded-md bg-surface p-3">
            <div className="flex items-center justify-between mb-1"><span className="font-medium text-sm">{t(`portal.disputes.type.${d.type}`)}</span><StatusPill tone={d.status === 'OPEN' ? 'warn' : d.status === 'RESOLVED' ? 'success' : 'neutral'}>{d.status}</StatusPill></div>
            <div className="text-xs text-muted font-mono mb-1">{d.order_id}</div>
            <p className="text-sm">{d.description}</p>
            <p className="text-xs text-muted mt-1">{new Date(d.created_at).toLocaleString()}</p>
          </div>
        ))}</div>}
      </section>
    </div>
  );
}
EOF
W apps/distributor-portal/src/modules/portal/PortalPage.tsx <<'EOF'
import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Spinner } from '@tera/ui';
import { DistributorSwitcher } from './components/DistributorSwitcher';
import { OrderTab } from './tabs/OrderTab';
import { TrackTab } from './tabs/TrackTab';
import { StatementsTab } from './tabs/StatementsTab';
import { DisputesTab } from './tabs/DisputesTab';
import { useMe } from './hooks';
import { getCurrentDistributor, setCurrentDistributor } from '../../api/client';
import type { Tab } from './types';
const TABS: { id: Tab; key: string }[] = [
  { id: 'order', key: 'portal.tab.order' }, { id: 'track', key: 'portal.tab.track' },
  { id: 'statements', key: 'portal.tab.statements' }, { id: 'disputes', key: 'portal.tab.disputes' },
];
export function PortalPage() {
  const { t } = useI18n(); const [tab, setTab] = useState<Tab>('order');
  if (!getCurrentDistributor()) setCurrentDistributor('seed-dist-1');
  const meQ = useMe();
  return (
    <div className="min-h-full bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3"><div className="max-w-6xl mx-auto flex items-center gap-4 flex-wrap">
        <div><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('portal.title')}</p></div>
        <div className="ml-auto flex items-center gap-3">
          {meQ.data && <div className="text-sm text-right"><div className="font-medium">{meQ.data.name}</div><div className="text-xs text-muted">{t('portal.headroom_short')}: {meQ.data.headroom_etb.toLocaleString()} ETB</div></div>}
          <DistributorSwitcher />
        </div>
      </div></header>
      <div className="border-b border-border bg-surface px-6"><div className="max-w-6xl mx-auto flex gap-1">
        {TABS.map((tt) => <button key={tt.id} onClick={() => setTab(tt.id)} className={`px-4 py-3 text-sm font-medium border-b-2 transition ${tab === tt.id ? 'border-primary text-primary' : 'border-transparent text-muted hover:text-text'}`}>{t(tt.key)}</button>)}
      </div></div>
      <main className="p-6 max-w-6xl mx-auto">
        {meQ.isLoading ? <Spinner label={t('common.loading')} /> : (
          <>{tab === 'order' && <OrderTab />}{tab === 'track' && <TrackTab />}{tab === 'statements' && <StatementsTab />}{tab === 'disputes' && <DisputesTab />}</>
        )}
      </main>
    </div>
  );
}
EOF
W apps/distributor-portal/src/modules/portal/index.ts <<'EOF'
export { PortalPage } from './PortalPage';
EOF

# ═══════════════════════════════════════════════════════════════════
# PHASE 9 — FINAL i18n consolidation (exec/finance/portal keys)
# ═══════════════════════════════════════════════════════════════════
echo "▸ Final i18n + smoke test + docs"

node <<'NODE'
const fs = require('fs');
const en = JSON.parse(fs.readFileSync('packages/i18n/src/locales/en.json', 'utf8'));
const am = JSON.parse(fs.readFileSync('packages/i18n/src/locales/am.json', 'utf8'));

Object.assign(en, {
  'exec.title': 'Executive Dashboard', 'exec.tagline': '90-second read', 'exec.heading': 'ROI Dashboard', 'exec.as_of': 'As of',
  'exec.hero.label': 'Saved this month', 'exec.hero.per_month': 'per month',
  'exec.hero.cumulative': 'Since baseline', 'exec.hero.annualized': 'Annualized pace',
  'exec.hero.days': 'days', 'exec.hero.per_year': 'per year',
  'exec.tiles.heading': 'The ten drivers', 'exec.tile.fully_in_target': 'Max target', 'exec.tile.in_target': 'Min target', 'exec.tile.below_target': 'Below target',
  'exec.tile.etb_impact': 'monthly impact',
  'exec.demo.title': 'Demo data',
  'exec.demo.body': "These numbers come from synthetic demo data. When you're ready to start real tracking, freeze today's values as the baseline.",
  'exec.demo.start': 'Start real baseline',
  'exec.empty.no_baseline': 'No baseline frozen yet', 'exec.empty.no_baseline_hint': 'Press Start real baseline when ready.',
  'exec.assumptions.title': 'Cost assumptions', 'exec.assumptions.configure': 'Configure cost assumptions',
  'exec.assumption.monthly_deliveries': 'Monthly deliveries', 'exec.assumption.monthly_routes': 'Monthly routes',
  'exec.assumption.daily_vehicles': 'Daily vehicles', 'exec.assumption.vehicle_wear': 'Vehicle wear (ETB/km)',
  'exec.assumption.margin_sku': 'Margin per SKU-day (ETB)', 'exec.assumption.fuel_incident': 'Cost per fuel incident (ETB)',
  'exec.assumption.margin_delivery': 'Margin per delivery (ETB)',

  'finance.title': 'Finance', 'finance.tagline': 'Exposure · overrides · reconciliation',
  'finance.heading': 'Finance Console', 'finance.heading_hint': 'Cash protection and reconciliation',
  'finance.tab.credit': 'Credit', 'finance.tab.overrides': 'Overrides', 'finance.tab.reconciliation': 'Reconciliation',
  'finance.credit.total_exposure': 'Total exposure', 'finance.credit.total_limit': 'Total limit',
  'finance.credit.utilization': 'Utilization', 'finance.credit.over_limit': 'Over limit',
  'finance.credit.aging_buckets': 'Aging buckets',
  'finance.credit.bucket.current': 'Current', 'finance.credit.bucket.watch': 'Watch', 'finance.credit.bucket.overdue': 'Overdue', 'finance.credit.bucket.critical': 'Critical',
  'finance.credit.accounts': 'accts', 'finance.credit.near_limit': 'Near limit (≥80%)', 'finance.credit.all_accounts': 'All accounts',
  'finance.credit.no_accounts': 'No credit accounts yet',
  'finance.credit.exposure': 'Exposure', 'finance.credit.limit': 'Limit', 'finance.credit.days_overdue': 'Days overdue', 'finance.credit.days_overdue_suffix': 'days overdue',
  'finance.overrides.total': 'overrides recorded', 'finance.overrides.filter.active': 'Active', 'finance.overrides.filter.expired': 'Expired', 'finance.overrides.filter.all': 'All',
  'finance.overrides.empty': 'No overrides to show', 'finance.overrides.reason': 'Reason', 'finance.overrides.actor': 'Actor',
  'finance.overrides.created': 'Created', 'finance.overrides.expires': 'Expires',
  'finance.overrides.status.active': 'Active', 'finance.overrides.status.expired': 'Expired',
  'finance.recon.title': 'Unreconciled payments', 'finance.recon.subtitle': 'Cash and Telebirr payments awaiting reconciliation.',
  'finance.recon.pending': 'pending', 'finance.recon.empty': 'No payments awaiting reconciliation',
  'finance.recon.distributor': 'Distributor', 'finance.recon.vehicle': 'Vehicle', 'finance.recon.method': 'Method',
  'finance.recon.amount': 'Amount', 'finance.recon.captured': 'Captured', 'finance.recon.reconcile': 'Reconcile',
  'finance.recon.hint': 'Cash payments: verify driver count matches. Telebirr: match ref against the transaction log.',

  'portal.title': 'Distributor Portal', 'portal.headroom_short': 'Headroom', 'portal.switcher.label': 'Switch distributor',
  'portal.tab.order': 'Order', 'portal.tab.track': 'Track', 'portal.tab.statements': 'Statements', 'portal.tab.disputes': 'Disputes',
  'portal.order.catalog': 'Product catalog', 'portal.order.no_skus': 'No products available', 'portal.order.in_stock': 'in stock',
  'portal.order.cart': 'Your cart', 'portal.order.cart_empty': 'Cart is empty — add products on the left',
  'portal.order.total': 'Total', 'portal.order.headroom': 'Credit headroom',
  'portal.order.exceeds': 'Cart exceeds headroom by {over}', 'portal.order.after': '{remaining} will remain after order',
  'portal.order.place': 'Place order ({n})', 'portal.order.success': 'Order placed · {total}',
  'portal.track.active': 'Active orders', 'portal.track.no_active': 'No active orders', 'portal.track.no_active_hint': 'Place an order from the Order tab.',
  'portal.track.recent': 'Recent', 'portal.track.no_recent': 'No recent orders yet',
  'portal.track.lines': 'lines', 'portal.track.items': 'items', 'portal.track.eta': 'ETA', 'portal.track.vehicle': 'Vehicle',
  'portal.statements.balance': 'Balance', 'portal.statements.limit': 'Credit limit',
  'portal.statements.utilization': 'Utilization', 'portal.statements.oldest_unpaid': 'Oldest unpaid',
  'portal.statements.recent_deliveries': 'Recent deliveries', 'portal.statements.no_deliveries': 'No deliveries yet',
  'portal.statements.date': 'Date', 'portal.statements.order': 'Order', 'portal.statements.vehicle': 'Vehicle', 'portal.statements.qty': 'Qty',
  'portal.disputes.raise': 'Raise a dispute', 'portal.disputes.order': 'Order', 'portal.disputes.pick_order': 'Choose an order…',
  'portal.disputes.type': 'Issue type',
  'portal.disputes.type.QUANTITY': 'Wrong quantity', 'portal.disputes.type.WRONG_ITEM': 'Wrong item',
  'portal.disputes.type.NEVER_DELIVERED': 'Never delivered', 'portal.disputes.type.DAMAGED': 'Damaged', 'portal.disputes.type.OTHER': 'Other',
  'portal.disputes.description': 'Description', 'portal.disputes.submit': 'Submit dispute',
  'portal.disputes.past': 'Your disputes', 'portal.disputes.empty': 'No disputes raised yet',
});

Object.assign(am, {
  'exec.title': 'የአስፈጻሚ ዳሽቦርድ', 'exec.tagline': 'የ90 ሰከንድ ንባብ', 'exec.heading': 'ROI ዳሽቦርድ', 'exec.as_of': 'እንደ',
  'exec.hero.label': 'በዚህ ወር ቁጠባ', 'exec.hero.per_month': 'በወር', 'exec.hero.cumulative': 'ከመነሻ ጀምሮ', 'exec.hero.annualized': 'ዓመታዊ ፍጥነት',
  'exec.hero.days': 'ቀናት', 'exec.hero.per_year': 'በዓመት',
  'exec.tiles.heading': 'አሥሩ አንቀሳቃሾች', 'exec.tile.fully_in_target': 'ከፍተኛ ዒላማ', 'exec.tile.in_target': 'ዝቅተኛ ዒላማ', 'exec.tile.below_target': 'ከዒላማ በታች',
  'exec.tile.etb_impact': 'ወርሃዊ ተጽዕኖ',
  'exec.demo.title': 'የማሳያ ውሂብ', 'exec.demo.body': 'እነዚህ ቁጥሮች ከሰው ሰራሽ ውሂብ የመጡ ናቸው።',
  'exec.demo.start': 'እውነተኛ መነሻ ጀምር',
  'exec.empty.no_baseline': 'እስካሁን መነሻ አልተያዘም', 'exec.empty.no_baseline_hint': 'ዝግጁ ሲሆኑ ይጫኑ።',
  'exec.assumptions.title': 'የወጪ ግምቶች', 'exec.assumptions.configure': 'የወጪ ግምቶችን አዋቅር',
  'exec.assumption.monthly_deliveries': 'ወርሃዊ ማድረሶች', 'exec.assumption.monthly_routes': 'ወርሃዊ መንገዶች',
  'exec.assumption.daily_vehicles': 'ዕለታዊ ተሽከርካሪዎች', 'exec.assumption.vehicle_wear': 'የተሽከርካሪ ልብስ',
  'exec.assumption.margin_sku': 'ትርፍ በSKU-ቀን', 'exec.assumption.fuel_incident': 'ወጪ በነዳጅ ክስተት',
  'exec.assumption.margin_delivery': 'ትርፍ በማድረስ',

  'finance.title': 'ፋይናንስ', 'finance.tagline': 'ተጋላጭነት · ማለፍ · ማስታረቅ',
  'finance.heading': 'የፋይናንስ ኮንሶል', 'finance.heading_hint': 'የገንዘብ ጥበቃ',
  'finance.tab.credit': 'ክሬዲት', 'finance.tab.overrides': 'ማለፎች', 'finance.tab.reconciliation': 'ማስታረቅ',
  'finance.credit.total_exposure': 'ጠቅላላ ተጋላጭነት', 'finance.credit.total_limit': 'ጠቅላላ ጣሪያ',
  'finance.credit.utilization': 'አጠቃቀም', 'finance.credit.over_limit': 'ከጣሪያ በላይ',
  'finance.credit.aging_buckets': 'የእድሜ ቅርጫቶች',
  'finance.credit.bucket.current': 'የአሁን', 'finance.credit.bucket.watch': 'ክትትል', 'finance.credit.bucket.overdue': 'ያለፈ', 'finance.credit.bucket.critical': 'ወሳኝ',
  'finance.credit.accounts': 'ሒሳቦች', 'finance.credit.near_limit': 'ወደ ጣሪያ ቅርብ', 'finance.credit.all_accounts': 'ሁሉም ሒሳቦች',
  'finance.credit.no_accounts': 'ሒሳብ የለም',
  'finance.credit.exposure': 'ተጋላጭነት', 'finance.credit.limit': 'ጣሪያ', 'finance.credit.days_overdue': 'የተዘገዩ ቀናት', 'finance.credit.days_overdue_suffix': 'ቀናት ዘግይተዋል',
  'finance.overrides.total': 'ማለፎች', 'finance.overrides.filter.active': 'ንቁ', 'finance.overrides.filter.expired': 'ያለቀ', 'finance.overrides.filter.all': 'ሁሉም',
  'finance.overrides.empty': 'ማለፍ የለም', 'finance.overrides.reason': 'ምክንያት', 'finance.overrides.actor': 'ተዋናይ',
  'finance.overrides.created': 'የተፈጠረ', 'finance.overrides.expires': 'የሚያበቃ',
  'finance.overrides.status.active': 'ንቁ', 'finance.overrides.status.expired': 'ያለቀ',
  'finance.recon.title': 'ያልተስተካከሉ ክፍያዎች', 'finance.recon.subtitle': 'ማስታረቅ የሚጠብቁ ክፍያዎች',
  'finance.recon.pending': 'በመጠባበቅ ላይ', 'finance.recon.empty': 'ክፍያ የለም',
  'finance.recon.distributor': 'አከፋፋይ', 'finance.recon.vehicle': 'ተሽከርካሪ', 'finance.recon.method': 'ዘዴ',
  'finance.recon.amount': 'መጠን', 'finance.recon.captured': 'የተያዘ', 'finance.recon.reconcile': 'አስታርቅ',
  'finance.recon.hint': 'የጥሬ ገንዘብ ክፍያዎች፦ የሹፌሩ ቆጠራ መመሳሰሉን ያረጋግጡ።',

  'portal.title': 'የአከፋፋይ ፖርታል', 'portal.headroom_short': 'ቀሪ ክሬዲት', 'portal.switcher.label': 'አከፋፋይ ቀይር',
  'portal.tab.order': 'ትዕዛዝ', 'portal.tab.track': 'ክትትል', 'portal.tab.statements': 'መግለጫዎች', 'portal.tab.disputes': 'ክርክሮች',
  'portal.order.catalog': 'የምርት ካታሎግ', 'portal.order.no_skus': 'ምርት የለም', 'portal.order.in_stock': 'በመጋዘን',
  'portal.order.cart': 'የእርስዎ ጋሪ', 'portal.order.cart_empty': 'ጋሪው ባዶ ነው',
  'portal.order.total': 'ጠቅላላ', 'portal.order.headroom': 'ቀሪ ክሬዲት',
  'portal.order.exceeds': 'ጋሪው በ{over} ይበልጣል', 'portal.order.after': '{remaining} ይቀራል',
  'portal.order.place': 'ትዕዛዝ አስገባ ({n})', 'portal.order.success': 'ትዕዛዝ ገብቷል · {total}',
  'portal.track.active': 'ንቁ ትዕዛዞች', 'portal.track.no_active': 'ንቁ ትዕዛዝ የለም', 'portal.track.no_active_hint': 'ከትዕዛዝ ትር ትዕዛዝ ያስገቡ',
  'portal.track.recent': 'የቅርብ ጊዜ', 'portal.track.no_recent': 'ትዕዛዝ የለም',
  'portal.track.lines': 'መስመሮች', 'portal.track.items': 'ዕቃዎች', 'portal.track.eta': 'የመድረሻ ጊዜ', 'portal.track.vehicle': 'ተሽከርካሪ',
  'portal.statements.balance': 'ቀሪ ሂሳብ', 'portal.statements.limit': 'የክሬዲት ጣሪያ',
  'portal.statements.utilization': 'አጠቃቀም', 'portal.statements.oldest_unpaid': 'በጣም የቆየ',
  'portal.statements.recent_deliveries': 'የቅርብ ማድረሶች', 'portal.statements.no_deliveries': 'ማድረስ የለም',
  'portal.statements.date': 'ቀን', 'portal.statements.order': 'ትዕዛዝ', 'portal.statements.vehicle': 'ተሽከርካሪ', 'portal.statements.qty': 'ብዛት',
  'portal.disputes.raise': 'ክርክር አቅርብ', 'portal.disputes.order': 'ትዕዛዝ', 'portal.disputes.pick_order': 'ትዕዛዝ ይምረጡ…',
  'portal.disputes.type': 'የችግሩ ዓይነት',
  'portal.disputes.type.QUANTITY': 'የተሳሳተ ብዛት', 'portal.disputes.type.WRONG_ITEM': 'የተሳሳተ ዕቃ',
  'portal.disputes.type.NEVER_DELIVERED': 'አልደረሰም', 'portal.disputes.type.DAMAGED': 'ተበላሽቷል', 'portal.disputes.type.OTHER': 'ሌላ',
  'portal.disputes.description': 'መግለጫ', 'portal.disputes.submit': 'ክርክር አስገባ',
  'portal.disputes.past': 'የእርስዎ ክርክሮች', 'portal.disputes.empty': 'ክርክር አልቀረበም',
});

fs.writeFileSync('packages/i18n/src/locales/en.json', JSON.stringify(en, null, 2) + '\n');
fs.writeFileSync('packages/i18n/src/locales/am.json', JSON.stringify(am, null, 2) + '\n');
console.log('  i18n complete — exec + finance + portal keys added');
NODE

# ═══════════════════════════════════════════════════════════════════
# PHASE 9 — SMOKE TEST
# ═══════════════════════════════════════════════════════════════════
echo "▸ Smoke test"

W scripts/e2e/smoke-test.sh <<'SCRIPT'
#!/usr/bin/env bash
# Tera OMS — End-to-end smoke test
set -uo pipefail
API_URL="${API_URL:-http://localhost:8000}"
DIST_ID="${DIST_ID:-seed-dist-1}"
if [ -t 1 ]; then GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; BOLD='\033[1m'; NC='\033[0m'; else GREEN=''; RED=''; CYAN=''; GRAY=''; BOLD=''; NC=''; fi
P=0; F=0; FC=()
section() { echo -e "\n${BOLD}${CYAN}▸ $1${NC}"; }
check() {
  local n="$1"; shift; echo -n "  $n ... "
  if "$@" > /tmp/te 2>&1; then echo -e "${GREEN}✓${NC}"; P=$((P+1))
  else echo -e "${RED}✗${NC}"; F=$((F+1)); FC+=("$n"); sed 's/^/      /' /tmp/te | head -10; fi
}
require() {
  local n="$1"; shift
  if ! check "$n" "$@"; then
    echo -e "\n${RED}${BOLD}⛔ Aborted — $n failed${NC}"; echo -e "${GRAY}   Hint: pnpm db:migrate && pnpm db:seed${NC}"; summary
  fi
}
summary() { echo -e "\n${BOLD}Passed:${NC} ${GREEN}$P${NC} | ${BOLD}Failed:${NC} ${RED}$F${NC}"; [ $F -gt 0 ] && { echo -e "${RED}Failed:${NC}"; for c in "${FC[@]}"; do echo -e "  - $c"; done; exit 1; }; echo -e "\n${GREEN}${BOLD}✓ ALL CHECKS PASSED${NC}"; exit 0; }

get() { curl -sS --fail-with-body "$API_URL$1" -H 'Content-Type: application/json'; }
post() { curl -sS --fail-with-body -X POST "$API_URL$1" -H 'Content-Type: application/json' -d "${2:-{\}}"; }
post_d() { curl -sS --fail-with-body -X POST "$API_URL$1" -H 'Content-Type: application/json' -H "X-Distributor-Id: $3" -d "${2:-{\}}"; }

t_health() { [ "$(get /health | jq -r '.ok')" = "true" ]; }
t_credit() { [ "$(get /credit/v1/stop-list | jq '.rows | length')" -ge 1 ]; }
t_exposure() { [ "$(get /credit/v1/exposure | jq '.aging_buckets | length')" = "4" ]; }
t_zones() { [ "$(get '/geo/v1/curfew-zones?includeInactive=1' | jq '.zones | length')" -ge 3 ]; }
t_stations() { [ "$(get '/geo/v1/fuel-stations?includeInactive=1' | jq '.stations | length')" -ge 3 ]; }
t_orders() { [ "$(get /orders/v1/pending | jq '.orders | length')" -ge 2 ]; }
t_vehicles() { [ "$(get /routing/v1/vehicles | jq '.vehicles | length')" -ge 1 ]; }
t_routes() { [ "$(get /routing/v1/routes/today | jq '.routes | length')" -ge 1 ]; }
t_board() { [ "$(get /dispatch/v1/board | jq '.docks | length')" -ge 1 ]; }
t_catalog() { [ "$(get /portal/v1/catalog | jq '.items | length')" -ge 1 ]; }
t_me() { [ "$(get /portal/v1/me -H "X-Distributor-Id: $DIST_ID" | jq -r '.distributor_id')" = "$DIST_ID" ]; }
t_dashboard() { [ "$(get /analytics/v1/dashboard | jq '.tiles | length')" -ge 1 ]; }
t_audit() { [ "$(get /audit/v1/log | jq '.entries | length')" -ge 0 ]; }
t_notify() { [ "$(get /notify/v1/templates | jq '.templates | length')" -ge 1 ]; }
t_jobs() { [ "$(get /admin/jobs/v1/schedule | jq '.jobs | length')" = "3" ]; }
t_metrics() { get /metrics | grep -q 'tera_http_requests_total'; }

# Solve flow
t_sync_solve() {
  local ids
  ids=$(get /orders/v1/pending | jq -c '[.orders[].id] | .[0:3]')
  [ "$(echo "$ids" | jq 'length')" -ge 3 ] || { echo "need 3 pending orders"; return 1; }
  local result
  result=$(post /routing/v1/solve "{\"order_ids\":$ids,\"vehicle_id\":\"V-103\"}")
  [ "$(echo "$result" | jq '.optimized.stops | length')" -ge 3 ]
}

# Portal order flow
NEW_ORDER=""
t_place_order() {
  local cat sku
  cat=$(get /portal/v1/catalog); sku=$(echo "$cat" | jq -r '.items[0].sku_id')
  [ -n "$sku" ] || { echo "no SKUs"; return 1; }
  local resp
  resp=$(post_d /portal/v1/orders "{\"lines\":[{\"sku_id\":\"$sku\",\"quantity\":3}]}" "$DIST_ID")
  NEW_ORDER=$(echo "$resp" | jq -r '.order_id')
  [ -n "$NEW_ORDER" ] || { echo "no order_id"; return 1; }
}

# Full flow: pick on V-102, confirm, dispatch
t_pick_and_dispatch() {
  local board route slot status picked
  board=$(get /dispatch/v1/board)
  route=$(echo "$board" | jq -r '[.docks[].slots[] | select(.route.vehicle_id == "V-102")][0].route.id // empty')
  status=$(echo "$board" | jq -r '[.docks[].slots[] | select(.route.vehicle_id == "V-102")][0].status // empty')
  [ -n "$route" ] || { echo "V-102 route not in board"; return 1; }
  if [ "$status" = "ALLOCATED" ]; then
    local pickList stops
    pickList=$(get "/routing/v1/routes/$route/pick-list")
    stops=$(echo "$pickList" | jq -r '.stops[].stop_id')
    for sid in $stops; do post "/routing/v1/routes/$route/stops/$sid/picked" '{}' > /dev/null || return 1; done
    slot=$(echo "$board" | jq -r '[.docks[].slots[] | select(.route.vehicle_id == "V-102")][0].id')
    post "/dispatch/v1/slots/$slot/confirm" '{}' > /dev/null
  fi
  # dispatch
  post "/dispatch/v1/routes/$route/dispatch" '{}' | jq -e '.status == "DISPATCHED"' > /dev/null
}

t_metrics_after() { get /metrics | grep -q 'tera_pending_orders'; }

echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Tera OMS — End-to-end Smoke Test                             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GRAY}  API: $API_URL  |  Distributor: $DIST_ID${NC}"

section "1. Preflight"
require "API is reachable" t_health

section "2. Seed data"
require "Credit stop list" t_credit
require "Exposure with 4 aging buckets" t_exposure
require "Curfew zones (≥3)" t_zones
require "Fuel stations (≥3)" t_stations
require "Pending orders (≥2)" t_orders
require "Vehicles" t_vehicles
require "Today's routes" t_routes
require "Dispatch board" t_board

section "3. Solve"
require "Sync solve returns optimized route" t_sync_solve

section "4. Dispatch flow"
require "Pick all stops + dispatch V-102" t_pick_and_dispatch

section "5. Portal"
require "Catalog has SKUs" t_catalog
require "GET /me returns distributor" t_me
require "Place order via portal" t_place_order

section "6. Analytics + Observability"
require "Exec dashboard returns tiles" t_dashboard
require "Audit log endpoint responds" t_audit
require "Notify templates available" t_notify
require "Job schedule (3 jobs)" t_jobs
require "Prometheus /metrics contains counter" t_metrics
require "Prometheus /metrics contains business gauge" t_metrics_after

summary
SCRIPT
chmod +x scripts/e2e/smoke-test.sh

# package.json + Makefile e2e entries
node <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts.e2e = 'bash scripts/e2e/smoke-test.sh';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
const mk = fs.readFileSync('Makefile', 'utf8');
if (!mk.includes('\ne2e:')) fs.writeFileSync('Makefile', mk.trimEnd() + '\n\ne2e:\n\tbash scripts/e2e/smoke-test.sh\n');
console.log('  package.json + Makefile updated (+e2e)');
NODE

# Final README
W README.md <<'EOF'
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