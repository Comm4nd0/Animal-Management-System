#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --infra       Provision AWS infrastructure only (terraform apply)"
    echo "  --app         Deploy application code only (skip terraform)"
    echo "  --destroy     Tear down all AWS infrastructure"
    echo "  --help        Show this help message"
    echo ""
    echo "With no options, runs both infrastructure and app deployment."
}

# Parse arguments
DO_INFRA=true
DO_APP=true
DO_DESTROY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --infra)   DO_INFRA=true; DO_APP=false; shift ;;
        --app)     DO_INFRA=false; DO_APP=true; shift ;;
        --destroy) DO_DESTROY=true; shift ;;
        --help)    usage; exit 0 ;;
        *)         err "Unknown option: $1" ;;
    esac
done

# ─── Prerequisite checks ─────────────────────────────────────

check_prereqs() {
    local missing=()
    command -v terraform >/dev/null 2>&1  || missing+=("terraform")
    command -v ssh >/dev/null 2>&1        || missing+=("ssh")
    command -v rsync >/dev/null 2>&1      || missing+=("rsync")

    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing required tools: ${missing[*]}"
    fi

    # Check terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        err "Missing $TERRAFORM_DIR/terraform.tfvars\nCopy the example and fill in your values:\n  cp $TERRAFORM_DIR/terraform.tfvars.example $TERRAFORM_DIR/terraform.tfvars"
    fi
}

# ─── Terraform: Provision Infrastructure ──────────────────────

provision_infra() {
    log "Provisioning AWS infrastructure..."
    cd "$TERRAFORM_DIR"

    terraform init -input=false
    terraform plan -out=tfplan
    terraform apply tfplan
    rm -f tfplan

    log "Infrastructure provisioned successfully!"
    echo ""
    info "Waiting 90s for EC2 instance to finish bootstrapping..."
    sleep 90
}

# ─── Terraform: Destroy Infrastructure ────────────────────────

destroy_infra() {
    warn "This will DESTROY all AWS resources and data!"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    cd "$TERRAFORM_DIR"
    terraform init -input=false
    terraform destroy
}

# ─── Get Terraform outputs ───────────────────────────────────

get_outputs() {
    cd "$TERRAFORM_DIR"
    EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null) || err "No terraform outputs found. Run with --infra first."

    # Get values from tfvars
    RDS_ENDPOINT=$(grep 'rds_endpoint' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/')
    RDS_DB_NAME=$(grep 'rds_db_name' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/' || echo "pedigree_db")
    RDS_USERNAME=$(grep 'rds_username' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/' || echo "postgres")
    RDS_PASSWORD=$(grep 'rds_password' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/')
    DJANGO_SECRET=$(grep 'django_secret_key' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/')

    # Optional S3 media config
    AWS_KEY=$(grep 'aws_access_key_id' "$TERRAFORM_DIR/terraform.tfvars" | grep -v '#' | sed 's/.*=\s*"\(.*\)"/\1/' || echo "")
    AWS_SECRET=$(grep 'aws_secret_access_key' "$TERRAFORM_DIR/terraform.tfvars" | grep -v '#' | sed 's/.*=\s*"\(.*\)"/\1/' || echo "")
    S3_BUCKET=$(grep 's3_media_bucket' "$TERRAFORM_DIR/terraform.tfvars" | grep -v '#' | sed 's/.*=\s*"\(.*\)"/\1/' || echo "")

    SSH_KEY="$HOME/.ssh/p4td-key.pem"
    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $SSH_KEY"
}

# ─── Deploy Application ──────────────────────────────────────

deploy_app() {
    get_outputs

    # Step 1: Create database on RDS if it doesn't exist
    log "Ensuring database '$RDS_DB_NAME' exists on RDS..."
    PGPASSWORD="$RDS_PASSWORD" psql -h "$RDS_ENDPOINT" -U "$RDS_USERNAME" -d postgres -tc \
        "SELECT 1 FROM pg_database WHERE datname = '$RDS_DB_NAME'" | grep -q 1 || \
    PGPASSWORD="$RDS_PASSWORD" psql -h "$RDS_ENDPOINT" -U "$RDS_USERNAME" -d postgres -c \
        "CREATE DATABASE $RDS_DB_NAME OWNER $RDS_USERNAME;" && \
    log "Database '$RDS_DB_NAME' ready."

    # Step 2: Create .env file on EC2
    log "Configuring environment on EC2..."

    # Build S3 env vars only if configured
    S3_ENV=""
    if [ -n "$AWS_KEY" ] && [ -n "$S3_BUCKET" ]; then
        S3_ENV="USE_S3=True
AWS_ACCESS_KEY_ID=$AWS_KEY
AWS_SECRET_ACCESS_KEY=$AWS_SECRET
AWS_STORAGE_BUCKET_NAME=$S3_BUCKET
AWS_S3_REGION_NAME=eu-west-1"
    fi

    ssh $SSH_OPTS "ec2-user@$EC2_IP" bash -s <<ENV_EOF
cat > /opt/app/.env << 'DOTENV'
DJANGO_SECRET_KEY=$DJANGO_SECRET
DB_NAME=$RDS_DB_NAME
DB_USER=$RDS_USERNAME
DB_PASSWORD=$RDS_PASSWORD
DB_HOST=$RDS_ENDPOINT
DB_PORT=5432
DEBUG=False
ALLOWED_HOSTS=$EC2_IP,localhost
CORS_ALLOW_ALL=False
CORS_ALLOWED_ORIGINS=http://$EC2_IP
$S3_ENV
DOTENV
ENV_EOF

    # Step 3: Sync backend code to EC2
    log "Deploying backend to EC2..."
    rsync -az --delete \
        -e "ssh $SSH_OPTS" \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.git' \
        --exclude='db.sqlite3' \
        "$PROJECT_ROOT/backend/" \
        "ec2-user@$EC2_IP:/opt/app/backend/"

    # Sync production docker-compose
    rsync -az \
        -e "ssh $SSH_OPTS" \
        "$PROJECT_ROOT/docker-compose.prod.yml" \
        "ec2-user@$EC2_IP:/opt/app/"

    # Sync nginx config
    rsync -az --delete \
        -e "ssh $SSH_OPTS" \
        "$PROJECT_ROOT/deploy/nginx/" \
        "ec2-user@$EC2_IP:/opt/app/deploy/nginx/"

    # Step 4: Build and start containers on EC2
    log "Starting application containers..."
    ssh $SSH_OPTS "ec2-user@$EC2_IP" << 'REMOTE'
cd /opt/app
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --build
echo "Waiting for services to start..."
sleep 15
docker compose -f docker-compose.prod.yml ps
REMOTE

    # Done!
    echo ""
    log "========================================="
    log "  Deployment complete!"
    log "========================================="
    echo ""
    echo -e "  API:       ${GREEN}http://$EC2_IP/api/v1/${NC}"
    echo -e "  Admin:     ${GREEN}http://$EC2_IP/admin/${NC}"
    echo -e "  SSH:       ${BLUE}ssh -i $SSH_KEY ec2-user@$EC2_IP${NC}"
    echo ""
    info "To create a Django admin user:"
    echo "  ssh -i $SSH_KEY ec2-user@$EC2_IP"
    echo "  cd /opt/app && docker compose -f docker-compose.prod.yml exec web python manage.py createsuperuser"
    echo ""
    info "To enable HTTPS on the API, run: deploy/scripts/setup-ssl.sh YOUR_DOMAIN"
    echo ""

    # Cost summary
    echo -e "${BLUE}─── Estimated Monthly Cost ───${NC}"
    echo "  EC2 t2.micro:     Free (12 months)"
    echo "  EBS 30GB gp3:     Free (12 months)"
    echo "  RDS (existing):   Already running"
    echo "  S3 (backups):     ~\$0.02"
    echo "  ─────────────────────────"
    echo -e "  ${GREEN}Total:              ~\$0/month (free tier)${NC}"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────

if $DO_DESTROY; then
    check_prereqs
    destroy_infra
    exit 0
fi

check_prereqs

if $DO_INFRA; then
    provision_infra
fi

if $DO_APP; then
    deploy_app
fi
