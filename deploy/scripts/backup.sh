#!/bin/bash
set -euo pipefail

# Manual database backup to S3.
# This runs automatically via daily cron on the EC2 instance.
# Use this script to trigger an immediate backup from your local machine.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

GREEN='\033[0;32m'
NC='\033[0m'

cd "$TERRAFORM_DIR"
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null) || { echo "Run deploy.sh --infra first"; exit 1; }
BACKUP_BUCKET=$(terraform output -raw backup_bucket_name)
SSH_KEY="$HOME/.ssh/p4td-key.pem"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $SSH_KEY"

echo -e "${GREEN}[BACKUP]${NC} Running database backup on $EC2_IP..."

ssh $SSH_OPTS "ec2-user@$EC2_IP" bash -s "$BACKUP_BUCKET" << 'REMOTE'
BUCKET=$1
BACKUP_FILE="/tmp/pedigree_db_$(date +%Y%m%d_%H%M%S).sql.gz"

cd /opt/app

# Source .env to get DB credentials
set -a
source .env
set +a

# Dump database from external RDS
PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" | gzip > "$BACKUP_FILE"

FILESIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup size: $FILESIZE"

aws s3 cp "$BACKUP_FILE" "s3://$BUCKET/manual/$(date +%Y/%m)/" --quiet
rm -f "$BACKUP_FILE"

echo "Uploaded to s3://$BUCKET/manual/$(date +%Y/%m)/"
REMOTE

echo -e "${GREEN}[BACKUP]${NC} Done! View backups with: aws s3 ls s3://$BACKUP_BUCKET/ --recursive"
