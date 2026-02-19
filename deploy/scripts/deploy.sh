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
    command -v aws >/dev/null 2>&1       || missing+=("aws (AWS CLI)")
    command -v terraform >/dev/null 2>&1  || missing+=("terraform")
    command -v ssh >/dev/null 2>&1        || missing+=("ssh")
    command -v rsync >/dev/null 2>&1      || missing+=("rsync")

    if $DO_APP; then
        command -v flutter >/dev/null 2>&1 || missing+=("flutter")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing required tools: ${missing[*]}"
    fi

    # Check AWS credentials
    aws sts get-caller-identity >/dev/null 2>&1 || err "AWS credentials not configured. Run 'aws configure' first."

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
    info "Waiting 60s for EC2 instance to finish bootstrapping..."
    sleep 60
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
    S3_BUCKET=$(terraform output -raw frontend_bucket_name)
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name)
    API_URL=$(terraform output -raw api_url)

    # Get sensitive values from tfvars
    DB_PASSWORD=$(grep 'db_password' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/')
    DJANGO_SECRET=$(grep 'django_secret_key' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/')
    SSH_KEY_PUB=$(grep 'ssh_public_key_path' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/' || echo "~/.ssh/id_rsa.pub")
    SSH_KEY="${SSH_KEY_PUB%.pub}"
    # Expand tilde
    SSH_KEY="${SSH_KEY/#\~/$HOME}"

    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $SSH_KEY"
}

# ─── Deploy Application ──────────────────────────────────────

deploy_app() {
    get_outputs

    # Step 1: Build Flutter web with production API URL
    log "Building Flutter web (API_BASE_URL=$API_URL)..."
    cd "$PROJECT_ROOT"
    flutter build web --release \
        --dart-define="API_BASE_URL=$API_URL"

    # Step 2: Upload frontend to S3
    log "Uploading frontend to S3..."
    aws s3 sync build/web "s3://$S3_BUCKET" \
        --delete \
        --cache-control "max-age=3600"

    # Cache-bust index.html so users always get the latest version
    aws s3 cp build/web/index.html "s3://$S3_BUCKET/index.html" \
        --cache-control "no-cache, no-store, must-revalidate"

    # Step 3: Invalidate CloudFront cache
    log "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_ID" \
        --paths "/*" > /dev/null

    # Step 4: Create .env file on EC2
    log "Configuring environment on EC2..."
    ssh $SSH_OPTS "ec2-user@$EC2_IP" bash -s << ENV_EOF
cat > /opt/app/.env << 'DOTENV'
DJANGO_SECRET_KEY=$DJANGO_SECRET
DB_NAME=pedigree_db
DB_USER=pedigree_admin
DB_PASSWORD=$DB_PASSWORD
DB_HOST=db
DB_PORT=5432
DEBUG=False
ALLOWED_HOSTS=$EC2_IP,localhost
CORS_ALLOW_ALL=False
CORS_ALLOWED_ORIGINS=https://$CLOUDFRONT_DOMAIN
DOTENV
ENV_EOF

    # Step 5: Sync backend code to EC2
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

    # Step 6: Build and start containers on EC2
    log "Starting application containers..."
    ssh $SSH_OPTS "ec2-user@$EC2_IP" << 'REMOTE'
cd /opt/app
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --build
echo "Waiting for services to start..."
sleep 10
docker compose -f docker-compose.prod.yml ps
REMOTE

    # Done!
    echo ""
    log "========================================="
    log "  Deployment complete!"
    log "========================================="
    echo ""
    echo -e "  Frontend:  ${GREEN}https://$CLOUDFRONT_DOMAIN${NC}"
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
    echo "  EC2 t4g.small:    ~\$12.26"
    echo "  EBS 20GB gp3:     ~ \$1.60"
    echo "  S3 + CloudFront:  ~ \$0.10"
    echo "  ─────────────────────────"
    echo -e "  ${GREEN}Total:              ~\$14/month${NC}"
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
