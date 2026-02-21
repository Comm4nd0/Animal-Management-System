variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pedigree-manager"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro = free tier eligible (2 vCPU, 1GB RAM)"
  type        = string
  default     = "t3.micro"
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GB (free tier: up to 30GB)"
  type        = number
  default     = 30
}

# ─── Existing Infrastructure ─────────────────────────────────
# These reference resources that already exist in your AWS account.

variable "existing_vpc_id" {
  description = "ID of the existing VPC to deploy into"
  type        = string
}

variable "existing_subnet_id" {
  description = "ID of the existing public subnet"
  type        = string
}

variable "existing_security_group_id" {
  description = "ID of the existing security group (must allow SSH, HTTP, HTTPS inbound)"
  type        = string
}

variable "existing_key_pair_name" {
  description = "Name of the existing EC2 key pair for SSH access"
  type        = string
  default     = "p4td-key"
}

# ─── Database (Existing RDS) ─────────────────────────────────

variable "rds_endpoint" {
  description = "Endpoint of the existing RDS PostgreSQL instance"
  type        = string
}

variable "rds_db_name" {
  description = "Database name to create/use on the RDS instance"
  type        = string
  default     = "pedigree_db"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

# ─── Application Secrets ─────────────────────────────────────

variable "django_secret_key" {
  description = "Django SECRET_KEY for production"
  type        = string
  sensitive   = true
}

# ─── AWS S3 (Media Storage) ──────────────────────────────────

variable "aws_access_key_id" {
  description = "AWS access key for S3 media uploads"
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS secret key for S3 media uploads"
  type        = string
  sensitive   = true
  default     = ""
}

variable "s3_media_bucket" {
  description = "Existing S3 bucket name for media files"
  type        = string
  default     = ""
}
