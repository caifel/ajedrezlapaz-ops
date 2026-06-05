COMPOSE=docker compose
COMPOSE_PROD=$(COMPOSE) -f docker-compose.prod.yml

.PHONY: build up down logs up-ws down-ws shell logs-ws api-types api-types-check api-test db-migration-refresh db-migrate db-seed db-reset db-rebuild shell-api sqlite-api logs-api status clean prod prod-ui prod-api smoke-test verify hooks-install help h

# @group Build

build: ## [dev] Build all development Docker images.
	$(COMPOSE) build

# @group WS

up-ws: ## [dev] Create and start the independent ws container.
	$(COMPOSE) up -d ws

down-ws: ## [dev] Stop and remove the independent ws container while keeping named volumes.
	$(COMPOSE) rm -sf ws

shell: ## [dev] Open a zsh shell in the ws container.
	$(COMPOSE) exec ws zsh

logs-ws: ## [dev] Follow ws container logs.
	$(COMPOSE) logs -f ws

# @group Dev App

up: ## [dev] Start dev-api + dev-ui, then refresh ui API types.
	@scripts/sync-api-types.sh

down: ## [dev] Stop and remove dev-ui + dev-api while keeping named volumes.
	$(COMPOSE) rm -sf dev-ui dev-api

logs: ## [dev] Follow dev-ui + dev-api logs.
	$(COMPOSE) logs -f dev-api dev-ui

# @group API

api-types: ## [dev] Regenerate ui API types from the running dev-api Swagger schema.
	@scripts/sync-api-types.sh

api-types-check: ## [dev] Check that generated ui API types match the running dev-api Swagger schema.
	@scripts/sync-api-types.sh --check

api-test: ## [dev] Run the API test suite inside dev-api.
	$(COMPOSE) exec -T dev-api bun test --max-concurrency=1

db-migration-refresh: ## [dev] Recreate the current API migration snapshot from schema.ts.
	$(COMPOSE) run --rm dev-api sh -lc "bun install && bun run db:recreate-migration"

db-migrate: ## [dev] Apply API database migrations in the dev SQLite volume.
	$(COMPOSE) run --rm dev-api sh -lc "bun install && bun run db:migrate"

db-seed: ## [dev] Seed the dev API database; this replaces fixture-owned data.
	$(COMPOSE) run --rm dev-api sh -lc "bun install && bun run db:seed"

db-reset: ## [dev] Delete dev SQLite files, then migrate and seed from current migration.
	$(COMPOSE) rm -sf dev-api
	$(COMPOSE) run --rm dev-api sh -lc "rm -f /alp/api/data/app.db /alp/api/data/app.db-* && bun install && bun run db:migrate && bun run db:seed"

db-rebuild: ## [dev] Recreate migration, delete dev SQLite files, then migrate and seed.
	$(COMPOSE) rm -sf dev-api
	$(COMPOSE) run --rm dev-api sh -lc "rm -f /alp/api/data/app.db /alp/api/data/app.db-* && bun install && bun run db:recreate-migration && bun run db:migrate && bun run db:seed"

shell-api: ## [dev] Open a shell in the dev-api container.
	$(COMPOSE) exec dev-api sh

sqlite-api: ## [dev] Open the dev-api SQLite database.
	$(COMPOSE) exec dev-api sqlite3 /alp/api/data/app.db

logs-api: ## [dev] Follow dev-api container logs.
	$(COMPOSE) logs -f dev-api

# @group Utilities

smoke-test: ## [dev] Start dev-api if needed, then run a quick health check.
	$(COMPOSE) up -d dev-api
	$(COMPOSE) run --rm ws sh /alp/ops/scripts/smoke-test.sh --api-url http://dev-api:4000

verify: ## [dev] Rebuild DB, refresh/check types, then smoke-test.
	$(MAKE) db-rebuild && $(MAKE) api-types && $(MAKE) api-types-check && $(MAKE) smoke-test

hooks-install: ## [dev] Install the API types pre-commit hook into .git/hooks.
	@mkdir -p .git/hooks
	@cp .githooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed (api-types-check)."

status: ## [dev] Show development Compose service status.
	$(COMPOSE) ps

clean: ## [dev] Stop all dev containers and delete development named volumes.
	$(COMPOSE) down -v

# @group Production-Like Local Testing

prod: ## [prod] Build and run production ui and API containers.
	$(COMPOSE_PROD) up --build prod-ui prod-api

prod-ui: ## [prod] Build and run the production ui container.
	$(COMPOSE_PROD) up --build prod-ui

prod-api: ## [prod] Build and run the production API container.
	$(COMPOSE_PROD) up --build prod-api

# @group Helpers

help: ## Display development targets with descriptions and commands.
	@scripts/make-help.sh

h: help
