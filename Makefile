# Convenience wrapper around docker compose. Set PROXY to layer a reverse proxy:
#   make up                 # bare quickstart (localhost)
#   make up PROXY=traefik   # with the Traefik overlay (also: caddy, nginx, apache)
#   make seed PROXY=traefik  # create the first admin + demo site (run once)
#
# All targets read ./.env. Start from .env.example and run `make secrets`.

PROXY ?=
COMPOSE := docker compose -f docker-compose.yml $(if $(PROXY),-f compose/$(PROXY).yml,)

.PHONY: help secrets up down logs ps pull seed backup config

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

secrets: ## Create .env from .env.example with fresh random secrets
	./scripts/generate-secrets.sh --write

up: ## Start the stack (PROXY=traefik|caddy|nginx|apache to add a proxy)
	$(COMPOSE) up -d

down: ## Stop the stack (keeps data volumes)
	$(COMPOSE) down

logs: ## Follow logs (make logs S=cms-api for one service)
	$(COMPOSE) logs -f $(S)

ps: ## Show service status
	$(COMPOSE) ps

pull: ## Pull the images pinned by ZCMS_VERSION
	$(COMPOSE) pull

seed: ## Create the first admin user + demo site (run once, after `up`)
	./scripts/first-run-seed.sh $(if $(PROXY),-f docker-compose.yml -f compose/$(PROXY).yml,)

backup: ## Dump the database to ./zcms-backup.sql
	$(COMPOSE) exec -T postgres pg_dump -U zcms zcms > zcms-backup.sql

config: ## Validate the merged compose configuration
	$(COMPOSE) config -q && echo "compose config OK"
