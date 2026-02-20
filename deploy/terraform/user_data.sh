#!/bin/bash
set -e

# Log output for debugging
exec > /var/log/user-data.log 2>&1

echo "=== Starting EC2 bootstrap ==="

# Update system
dnf update -y

# ─── Swap (1GB) ───────────────────────────────────────────────
# t2.micro has only 1GB RAM; swap prevents OOM when running
# Gunicorn + Nginx containers.
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# ─── Docker ───────────────────────────────────────────────────
dnf install -y docker
systemctl enable docker
systemctl start docker

# Install Docker Compose v2 (x86_64)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Symlink for docker-compose command
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install git, rsync, and PostgreSQL client (for DB creation)
dnf install -y git rsync postgresql16

# ─── App directory ────────────────────────────────────────────
mkdir -p /opt/app/deploy/nginx
chown -R ec2-user:ec2-user /opt/app

# ─── Daily database backup cron ──────────────────────────────
cat > /etc/cron.daily/db-backup << 'CRON'
#!/bin/bash
BACKUP_FILE="/tmp/pedigree_db_$(date +%%Y%%m%%d_%%H%%M%%S).sql.gz"
cd /opt/app

# Dump database via Docker
docker compose -f docker-compose.prod.yml exec -T web \
  python -c "
import subprocess, os
subprocess.run([
    'pg_dump', '-h', os.environ['DB_HOST'],
    '-U', os.environ['DB_USER'], '-d', os.environ['DB_NAME']
], check=True)" | gzip > "$BACKUP_FILE"

# Upload to S3
aws s3 cp "$BACKUP_FILE" "s3://${backup_bucket}/$(date +%%Y/%%m)/" --quiet

# Clean up
rm -f "$BACKUP_FILE"

echo "$(date): Backup completed" >> /var/log/db-backup.log
CRON
chmod +x /etc/cron.daily/db-backup

echo "=== Bootstrap complete ==="
