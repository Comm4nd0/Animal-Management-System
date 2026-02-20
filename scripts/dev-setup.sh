#!/usr/bin/env bash
set -euo pipefail

# ─── Pedigree Manager — Development Setup ─────────────────
# Run once to set up your local development environment.
# Usage: bash scripts/dev-setup.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# ─── Check prerequisites ──────────────────────────────────
log "Checking prerequisites..."

missing=()
command -v docker >/dev/null 2>&1   || missing+=("docker")
command -v flutter >/dev/null 2>&1  || missing+=("flutter (optional, for frontend)")

if ! docker compose version >/dev/null 2>&1; then
    missing+=("docker compose (v2)")
fi

if [ ${#missing[@]} -gt 0 ]; then
    warn "Missing tools: ${missing[*]}"
    warn "Docker is required. Flutter is optional if you only work on the backend."
    echo ""
fi

# ─── Build and start containers ───────────────────────────
log "Building Docker containers..."
docker compose -f docker-compose.dev.yml build

log "Starting services (PostgreSQL + Django)..."
docker compose -f docker-compose.dev.yml up -d

log "Waiting for database to be ready..."
for i in {1..30}; do
    if docker compose -f docker-compose.dev.yml exec -T db pg_isready -U pedigree_admin -d pedigree_db >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# ─── Run migrations ──────────────────────────────────────
log "Running database migrations..."
docker compose -f docker-compose.dev.yml exec -T web python manage.py migrate --noinput

# ─── Create superuser ────────────────────────────────────
echo ""
log "Create a Django admin account (you can skip with Ctrl+C):"
docker compose -f docker-compose.dev.yml exec web python manage.py createsuperuser || true

# ─── Install Flutter dependencies ─────────────────────────
if command -v flutter >/dev/null 2>&1; then
    log "Installing Flutter dependencies..."
    flutter pub get
else
    warn "Flutter not found — skipping frontend dependency install."
fi

# ─── Done ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Development environment ready!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  Backend API:   http://localhost:8000/api/v1/"
echo "  Admin panel:   http://localhost:8000/admin/"
echo "  Database:      localhost:5432 (pedigree_db)"
echo ""
echo "  Useful commands:"
echo "    make dev           Start development containers"
echo "    make down          Stop containers"
echo "    make test          Run all tests"
echo "    make logs          Follow container logs"
echo "    make migrate       Run database migrations"
echo "    make shell         Open Django shell"
echo "    flutter run -d chrome   Run Flutter web locally"
echo ""
echo "  Workflow: develop → test → PR → auto-deploy on merge"
echo ""
