terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ─── EC2 Instance ─────────────────────────────────────────────
# Uses existing VPC, subnet, security group, and key pair.
# Free tier: t2.micro (x86_64), 30GB gp3 EBS.
# S3 access is provided via access keys in .env (not instance role).

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.existing_key_pair_name
  subnet_id              = var.existing_subnet_id
  vpc_security_group_ids = [var.existing_security_group_id]

  user_data = templatefile("${path.module}/user_data.sh", {
    backup_bucket = aws_s3_bucket.backups.id
    db_user       = var.rds_username
  })

  root_block_device {
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project_name}-app" }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}
