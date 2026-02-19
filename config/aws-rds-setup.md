# AWS RDS Setup Guide for Pedigree Manager

## 1. Create RDS PostgreSQL Instance

### Via AWS Console:
1. Go to AWS RDS Dashboard
2. Click "Create database"
3. Choose **PostgreSQL** engine (version 16.x recommended)
4. Select instance class:
   - **Development**: `db.t3.micro` (free tier eligible)
   - **Production**: `db.r6g.large` or higher
5. Configure:
   - DB instance identifier: `pedigree-manager-db`
   - Master username: `pedigree_admin`
   - Master password: (use a strong password)
   - DB name: `pedigree_db`

### Via AWS CLI:
```bash
aws rds create-db-instance \
  --db-instance-identifier pedigree-manager-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.4 \
  --master-username pedigree_admin \
  --master-user-password YOUR_STRONG_PASSWORD \
  --allocated-storage 20 \
  --storage-type gp3 \
  --db-name pedigree_db \
  --vpc-security-group-ids sg-xxxxxxxx \
  --backup-retention-period 7 \
  --multi-az false \
  --publicly-accessible false \
  --storage-encrypted true
```

## 2. Security Group Configuration

Create a security group that allows:
- **Inbound**: PostgreSQL (port 5432) from your application's security group
- **Outbound**: All traffic

```bash
aws ec2 create-security-group \
  --group-name pedigree-rds-sg \
  --description "Security group for Pedigree Manager RDS"

aws ec2 authorize-security-group-ingress \
  --group-name pedigree-rds-sg \
  --protocol tcp \
  --port 5432 \
  --source-group YOUR_APP_SECURITY_GROUP
```

## 3. Environment Configuration

After RDS is created, get the endpoint:
```bash
aws rds describe-db-instances \
  --db-instance-identifier pedigree-manager-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

Set in your `.env` or environment:
```
DB_HOST=pedigree-manager-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com
DB_NAME=pedigree_db
DB_USER=pedigree_admin
DB_PASSWORD=your-password
DB_PORT=5432
```

## 4. Run Migrations

```bash
python manage.py migrate
python manage.py createsuperuser
```

## 5. Deployment Options

### Option A: AWS Elastic Beanstalk
```bash
eb init -p docker pedigree-manager
eb create pedigree-prod
eb setenv DB_HOST=your-rds-endpoint DB_NAME=pedigree_db ...
```

### Option B: AWS ECS with Fargate
1. Push Docker image to ECR
2. Create ECS task definition with environment variables
3. Create ECS service behind an ALB

### Option C: AWS EC2 Direct
1. Launch EC2 instance
2. Install Docker
3. Run `docker-compose up -d` with production env vars

## 6. Production Checklist

- [ ] Set `DEBUG=False`
- [ ] Set strong `DJANGO_SECRET_KEY`
- [ ] Configure proper `ALLOWED_HOSTS`
- [ ] Enable RDS encryption at rest
- [ ] Enable RDS automated backups (7+ days)
- [ ] Set up CloudWatch monitoring
- [ ] Configure RDS Multi-AZ for production
- [ ] Set up S3 for media file storage (`USE_S3=True`)
- [ ] Configure CORS for your production domains
- [ ] Set up SSL/TLS with ACM + ALB
