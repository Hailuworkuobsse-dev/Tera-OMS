#!/usr/bin/env bash
set -euo pipefail
[[ -f .env ]] || cp .env.example .env
pnpm install
pnpm db:generate
pnpm db:migrate
pnpm db:seed
echo "✓ ready — run: make up && make dev"
