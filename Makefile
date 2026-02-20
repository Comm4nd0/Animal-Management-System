# ─── Pedigree Animal Management System ─────────────────────
# Run `make help` to see all available commands

.PHONY: help dev down logs test test-backend test-frontend lint migrate shell seed deploy deploy-app setup clean

# ─── Configuration ─────────────────────────────────────────
DEV_COMPOSE  = docker compose -f docker-compose.dev.yml
PROD_COMPOSE = docker compose -f docker-compose.prod.yml

# ─── Help ──────────────────────────────────────────────────
help: ## Show this help
	@echo ""
	@echo "  Pedigree Animal Management System"
	@echo "  ─────────────────────────────────────────────"
	@echo ""
	@echo "  DEVELOPMENT"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ─── Development ───────────────────────────────────────────
setup: ## First-time setup: build containers, run migrations, create superuser
	@echo "── Building containers..."
	$(DEV_COMPOSE) build
	@echo "── Starting services..."
	$(DEV_COMPOSE) up -d
	@echo "── Waiting for database..."
	@sleep 5
	@echo "── Running migrations..."
	$(DEV_COMPOSE) exec web python manage.py migrate --noinput
	@echo ""
	@echo "── Create an admin account:"
	$(DEV_COMPOSE) exec web python manage.py createsuperuser
	@echo ""
	@echo "✓ Setup complete! API running at http://localhost:8000"

dev: ## Start the development environment
	$(DEV_COMPOSE) up -d --build
	@echo ""
	@echo "  Backend API:  http://localhost:8000/api/v1/"
	@echo "  Admin panel:  http://localhost:8000/admin/"
	@echo "  Database:     localhost:5432"
	@echo ""
	@echo "  Run 'make logs' to follow output"

down: ## Stop all development services
	$(DEV_COMPOSE) down

down-clean: ## Stop services and remove volumes (reset database)
	$(DEV_COMPOSE) down -v

logs: ## Follow development logs
	$(DEV_COMPOSE) logs -f

logs-web: ## Follow backend logs only
	$(DEV_COMPOSE) logs -f web

status: ## Show running containers
	$(DEV_COMPOSE) ps

# ─── Testing ───────────────────────────────────────────────
test: test-backend test-frontend ## Run all tests

test-backend: ## Run Django backend tests
	$(DEV_COMPOSE) exec web python manage.py test --verbosity=2

test-frontend: ## Run Flutter frontend tests
	cd "$(CURDIR)" && flutter test

lint: ## Run linting (backend + frontend)
	$(DEV_COMPOSE) exec web python -m py_compile pedigree_api/settings.py
	cd "$(CURDIR)" && flutter analyze

# ─── Database ──────────────────────────────────────────────
migrate: ## Run database migrations
	$(DEV_COMPOSE) exec web python manage.py migrate --noinput

makemigrations: ## Create new database migrations
	$(DEV_COMPOSE) exec web python manage.py makemigrations

shell: ## Open Django shell in running container
	$(DEV_COMPOSE) exec web python manage.py shell

dbshell: ## Open PostgreSQL shell
	$(DEV_COMPOSE) exec db psql -U pedigree_admin -d pedigree_db

# ─── Production ────────────────────────────────────────────
deploy: ## Full deploy: infrastructure + application
	bash deploy/scripts/deploy.sh

deploy-app: ## Deploy application code only (skip infrastructure)
	bash deploy/scripts/deploy.sh --app

deploy-infra: ## Provision infrastructure only
	bash deploy/scripts/deploy.sh --infra

prod-up: ## Start production containers locally (for testing prod config)
	$(PROD_COMPOSE) up -d --build

prod-down: ## Stop production containers
	$(PROD_COMPOSE) down

prod-logs: ## Follow production logs
	$(PROD_COMPOSE) logs -f

# ─── Utilities ─────────────────────────────────────────────
clean: ## Remove all containers, volumes, and build artifacts
	$(DEV_COMPOSE) down -v --remove-orphans 2>/dev/null || true
	$(PROD_COMPOSE) down -v --remove-orphans 2>/dev/null || true
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete 2>/dev/null || true
