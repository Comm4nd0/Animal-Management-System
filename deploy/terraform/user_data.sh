#!/bin/bash
set -e

# Log output for debugging
exec > /var/log/user-data.log 2>&1

echo "=== Starting EC2 bootstrap ==="

# Update system
dnf update -y

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Install Docker Compose v2 (ARM64)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Symlink for docker-compose command
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install git for deployments
dnf install -y git

# Create app directory
mkdir -p /opt/app/deploy/nginx
chown -R ec2-user:ec2-user /opt/app

# Set up daily database backup cron
cat > /etc/cron.daily/db-backup << 'CRON'
#!/bin/bash
BACKUP_FILE="/tmp/pedigree_db_$(date +%%Y%%m%%d_%%H%%M%%S).sql.gz"
cd /opt/app

# Dump database
docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U ${db_user} pedigree_db | gzip > "$BACKUP_FILE"

# Upload to S3
aws s3 cp "$BACKUP_FILE" "s3://${backup_bucket}/$(date +%%Y/%%m)/" --quiet

# Clean up
rm -f "$BACKUP_FILE"

echo "$(date): Backup completed" >> /var/log/db-backup.log
CRON
chmod +x /etc/cron.daily/db-backup

echo "=== Bootstrap complete ==="
