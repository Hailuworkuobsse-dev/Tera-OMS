#!/usr/bin/env bash
###############################################################################
# tera-oms/scripts/dev/bootstrap.sh
#
# One-shot setup for Tera OMS (Node 20 + pnpm monorepo).
#
# What it does:
#   1. Verifies Node >= 20 and pnpm (installs pnpm via corepack if missing).
#   2. Copies .env.example -> .env if .env is absent.
#   3. Installs all workspace dependencies with pnpm.
#   4. Starts MySQL 8 + Redis via docker compose.
#   5. Waits for MySQL to become healthy.
#   6. Runs Prisma generate, migrate, and seed.
#
# Usage:
#   chmod +x scripts/dev/bootstrap.sh
#   ./scripts/dev/bootstrap.sh
#
# Prerequisites (must be installed on the host):
#   - Node.js >= 20  (https://nodejs.org)
#   - Docker + Docker Compose  (https://docs.docker.com/compose/install/)
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

# ── Root detection ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "${ROOT_DIR}"
info "Working directory: $(pwd)"

# ── 1. Node.js check ────────────────────────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
  err "Node.js is not installed. Install it from https://nodejs.org (>= 20 required)."
  exit 1
fi

NODE_VERSION="$(node -v | sed 's/v//')"
NODE_MAJOR="$(echo "${NODE_VERSION}" | cut -d. -f1)"
if [[ "${NODE_MAJOR}" -lt 20 ]]; then
  err "Node.js ${NODE_VERSION} detected, but Tera OMS requires Node >= 20."
  exit 1
fi
ok "Node.js ${NODE_VERSION}"

# ── 2. pnpm check / install via corepack ────────────────────────────────────
if ! command -v pnpm >/dev/null 2>&1; then
  info "pnpm not found. Enabling via corepack..."
  if ! command -v corepack >/dev/null 2>&1; then
    err "corepack is not available (it ships with Node >= 16.14). Please install pnpm manually: npm i -g pnpm@9"
    exit 1
  fi
  corepack enable
  corepack prepare pnpm@9.0.0 --activate
fi

PNPM_VERSION="$(pnpm -v)"
ok "pnpm ${PNPM_VERSION}"

# ── 3. Environment file ─────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    info "Creating .env from .env.example..."
    cp .env.example .env
    ok ".env created"
  else
    warn ".env.example not found — skipping .env creation."
  fi
else
  ok ".env already present"
fi

# ── 4. Install dependencies ─────────────────────────────────────────────────
info "Installing workspace dependencies (pnpm install)…"
pnpm install
ok "Dependencies installed"

# ── 5. Start infrastructure (MySQL + Redis) ─────────────────────────────────
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  info "Starting MySQL + Redis via docker compose…"
  docker compose up -d mysql redis

  info "Waiting for MySQL to become healthy…"
  for i in {1..60}; do
    if docker compose exec -T mysql mysqladmin ping -h localhost -utera -ptera >/dev/null 2>&1; then
      ok "MySQL is ready"
      break
    fi
    if [[ "${i}" -eq 60 ]]; then
      err "MySQL did not become ready in time. Check: docker compose logs mysql"
      exit 1
    fi
    sleep 2
  done

  info "Verifying Redis…"
  if docker compose exec -T redis redis-cli ping >/dev/null 2>&1; then
    ok "Redis is ready"
  else
    warn "Redis did not respond to PING. Check: docker compose logs redis"
  fi
else
  warn "Docker / docker compose not found — skipping infrastructure start."
  warn "Make sure MySQL (3306) and Redis (6379) are running before running Prisma commands."
fi

# ── 6. Prisma: generate, migrate, seed ──────────────────────────────────────
info "Running Prisma generate…"
pnpm db:generate
ok "Prisma client generated"

info "Running Prisma migrate…"
pnpm db:migrate
ok "Database migrations applied"

info "Seeding database…"
pnpm db:seed
ok "Database seeded"

# ── Done ────────────────────────────────────────────────────────────────────
echo
ok "Tera OMS is ready!"
info "Next steps:"
info "  - Terminal 1: pnpm --filter @tera/api dev          (API on :8000)"
info "  - Terminal 2: pnpm --filter dispatcher-web dev    (Web on :5173)"
info "  - Or run everything: pnpm dev"
echo

