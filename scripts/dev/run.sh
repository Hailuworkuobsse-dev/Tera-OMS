#!/usr/bin/env bash
###############################################################################
# Tera OMS — Run Script
# Starts the API and frontend dev servers after ensuring dependencies + DB.
#
# Usage:
#   chmod +x scripts/dev/run.sh
#   ./scripts/dev/run.sh
#
# Or run individual parts:
#   ./scripts/dev/run.sh --deps-only   # install + migrate only
#   ./scripts/dev/run.sh --api-only    # start only the API
#   ./scripts/dev/run.sh --web-only    # start only the dispatcher web app
###############################################################################
set -euo pipefail

# ── Colours ─────────────────────────────────────────────────────────────────
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_GREEN='\033[32m'
readonly C_YELLOW='\033[33m'
readonly C_RED='\033[31m'

info()  { printf "${C_BOLD}==>${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}✓${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_YELLOW}⚠${C_RESET} %s\n" "$*"; }
err()   { printf "${C_RED}✗${C_RESET} %s\n" "$*" >&2; }

# ── Detect project root (works from any directory) ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "${ROOT_DIR}"
info "Project root: $(pwd)"

# ── Parse arguments ─────────────────────────────────────────────────────────
MODE="full"
for arg in "$@"; do
  case "$arg" in
    --deps-only) MODE="deps" ;;
    --api-only)  MODE="api" ;;
    --web-only)  MODE="web" ;;
    --help|-h)
      echo "Usage: $0 [--deps-only|--api-only|--web-only|--help]"
      exit 0
      ;;
    *) err "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── 1. Prerequisites check ──────────────────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
  err "Node.js not found. Install from https://nodejs.org (>= 20 required)."
  exit 1
fi

NODE_MAJOR="$(node -v | sed 's/v//' | cut -d. -f1)"
if [[ "${NODE_MAJOR}" -lt 20 ]]; then
  err "Node.js $(node -v) detected. Tera OMS requires Node >= 20."
  exit 1
fi
ok "Node.js $(node -v)"

if ! command -v pnpm >/dev/null 2>&1; then
  info "Installing pnpm via corepack..."
  corepack enable
  corepack prepare pnpm@9.0.0 --activate
fi
ok "pnpm $(pnpm -v)"

# ── 2. Install dependencies ─────────────────────────────────────────────────
if [[ "${MODE}" == "deps" || "${MODE}" == "full" || "${MODE}" == "api" || "${MODE}" == "web" ]]; then
  info "Installing workspace dependencies..."
  pnpm install --ignore-scripts
  ok "Dependencies installed"
fi

# ── 3. Environment file ─────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    info "Creating .env from .env.example..."
    cp .env.example .env
  fi
fi

# Adjust for local MySQL if needed (uncomment/edit if your MySQL differs):
# sed -i 's|mysql://tera:tera@localhost:3306/tera|mysql://root:admin@localhost:3307/tera|' .env
# sed -i 's|redis://localhost:6379|redis://localhost:6379|' .env

ok ".env ready"

# ── 4. Start infrastructure (MySQL + Redis via Docker) ──────────────────────
if [[ "${MODE}" == "full" || "${MODE}" == "deps" ]]; then
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    info "Starting MySQL + Redis via docker compose..."
    docker compose up -d mysql redis

    info "Waiting for MySQL to become healthy..."
    for i in {1..60}; do
      if docker compose exec -T mysql mysqladmin ping -h localhost -utera -ptera >/dev/null 2>&1; then
        ok "MySQL is ready"
        break
      fi
      if [[ "${i}" -eq 60 ]]; then
        err "MySQL did not become ready in time."
        exit 1
      fi
      sleep 2
    done

    if docker compose exec -T redis redis-cli ping >/dev/null 2>&1; then
      ok "Redis is ready"
    else
      warn "Redis not responding (check: docker compose logs redis)"
    fi
  else
    warn "Docker not found — skipping container start."
    warn "Ensure MySQL (3306) and Redis (6379) are running manually."
  fi
fi

# ── 5. Prisma: generate + migrate ───────────────────────────────────────────
if [[ "${MODE}" == "full" || "${MODE}" == "deps" ]]; then
  info "Generating Prisma Client..."
  pnpm db:generate
  ok "Prisma Client generated"

  info "Running database migrations..."
  pnpm db:migrate
  ok "Migrations applied"

  read -r -p "Seed database with demo data? [y/N] " seed_answer
  if [[ "${seed_answer}" =~ ^[Yy]$ ]]; then
    info "Seeding database..."
    pnpm db:seed
    ok "Database seeded"
  fi
fi

# ── 6. Start application servers ────────────────────────────────────────────
if [[ "${MODE}" == "full" || "${MODE}" == "api" ]]; then
  info "Starting API server on :8000..."
  pnpm --filter @tera/api dev &
  API_PID=$!
  ok "API started (PID ${API_PID})"
fi

if [[ "${MODE}" == "full" || "${MODE}" == "web" ]]; then
  info "Starting dispatcher-web on :5173..."
  pnpm --filter dispatcher-web dev &
  WEB_PID=$!
  ok "Web app started (PID ${WEB_PID})"
fi

# ── 7. Wait for background processes ────────────────────────────────────────
if [[ "${MODE}" == "full" || "${MODE}" == "api" || "${MODE}" == "web" ]]; then
  info "All services running. Press Ctrl+C to stop."
  wait
fi
```

### Quick one-liner (if everything is already set up)

```bash
# From the project root directory
pnpm install --ignore-scripts
pnpm db:generate
pnpm db:migrate
pnpm --filter @tera/api dev & pnpm --filter dispatcher-web dev
```

### Environment notes for your Windows setup




