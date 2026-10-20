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
