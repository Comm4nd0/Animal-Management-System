#!/bin/bash
set -euo pipefail

# Sets up free Let's Encrypt SSL certificate for the API server.
# Usage: ./setup-ssl.sh your-domain.com

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 api.pedigree-manager.com"
    exit 1
fi

DOMAIN="$1"

cd "$TERRAFORM_DIR"
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null) || { echo -e "${RED}Run deploy.sh --infra first${NC}"; exit 1; }
SSH_KEY="$HOME/.ssh/p4td-key.pem"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $SSH_KEY"

echo -e "${GREEN}[SSL]${NC} Setting up Let's Encrypt certificate for $DOMAIN"
echo ""
echo "Make sure your DNS A record points to: $EC2_IP"
read -p "Press Enter when DNS is configured..."

# Install certbot and get certificate
ssh $SSH_OPTS "ec2-user@$EC2_IP" bash -s "$DOMAIN" << 'REMOTE'
DOMAIN=$1
sudo dnf install -y certbot

# Stop nginx temporarily for standalone verification
cd /opt/app
docker compose -f docker-compose.prod.yml stop nginx

# Get certificate
sudo certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN \
    -d $DOMAIN

# Copy certs to docker volume location
sudo cp -rL /etc/letsencrypt/live /opt/app/certs_live || true

# Update ALLOWED_HOSTS in .env
sed -i "s/ALLOWED_HOSTS=.*/ALLOWED_HOSTS=$DOMAIN,localhost/" /opt/app/.env

# Restart everything
docker compose -f docker-compose.prod.yml up -d

# Set up auto-renewal cron
echo "0 3 * * * certbot renew --quiet --deploy-hook 'cd /opt/app && docker compose -f docker-compose.prod.yml restart nginx'" | sudo crontab -
REMOTE

echo ""
echo -e "${GREEN}[SSL]${NC} Certificate installed!"
echo "Now update deploy/nginx/nginx.conf:"
echo "  1. Uncomment the HTTPS server block"
echo "  2. Replace YOUR_DOMAIN with $DOMAIN"
echo "  3. Re-run: deploy/scripts/deploy.sh --app"
