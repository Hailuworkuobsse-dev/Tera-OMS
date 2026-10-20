.PHONY: up down migrate seed studio dev api optimizer worker web e2e bootstrap lint test boundaries

bootstrap:
	npm install

up: ; docker compose up -d
down: ; docker compose down
dev: ; npm run dev
api: ; npm run dev --workspace=@tera/api
optimizer: ; npm run dev --workspace=@tera/optimizer
worker: ; npm run dev --workspace=@tera/worker
web: ; npm run dev --workspace=dispatcher-web
e2e: ; bash scripts/e2e/smoke-test.sh
lint: ; npm run lint
test: ; npm run test
boundaries: ; npx depcruise --config .dependency-cruiser.cjs services/api/src

