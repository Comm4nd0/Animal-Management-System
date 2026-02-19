variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pedigree-manager"
}

variable "instance_type" {
  description = "EC2 instance type (ARM). t4g.small = 2 vCPU, 2GB RAM (~$12/mo)"
  type        = string
  default     = "t4g.small"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "db_password" {
  description = "PostgreSQL password for the application database"
  type        = string
  sensitive   = true
}

variable "django_secret_key" {
  description = "Django SECRET_KEY for production"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the EC2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict to your IP in production
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}
