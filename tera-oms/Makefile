.PHONY: bootstrap up down migrate seed studio api worker optimizer lint test boundaries dev

bootstrap:
	pnpm install
	pnpm db:generate
	pnpm db:migrate
	pnpm db:seed

up:
	docker compose up -d mysql redis

down:
	docker compose down

migrate:
	pnpm db:migrate

seed:
	pnpm db:seed

studio:
	pnpm db:studio

dev:
	pnpm dev

api:
	pnpm --filter @tera/api dev

worker:
	pnpm --filter @tera/worker dev

optimizer:
	pnpm --filter @tera/optimizer dev

lint:
	pnpm -r lint
	pnpm boundaries

test:
	pnpm -r test

boundaries:
	pnpm boundaries
