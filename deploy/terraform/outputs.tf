output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (API endpoint)"
  value       = aws_eip.app.public_ip
}

output "api_url" {
  description = "API base URL"
  value       = "http://${aws_eip.app.public_ip}/api/v1/"
}

output "backup_bucket_name" {
  description = "S3 bucket name for database backups"
  value       = aws_s3_bucket.backups.id
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ~/.ssh/p4td-key.pem ec2-user@${aws_eip.app.public_ip}"
}

output "admin_url" {
  description = "Django admin URL"
  value       = "http://${aws_eip.app.public_ip}/admin/"
}

# ─── Cost Estimate ────────────────────────────────────────────
# EC2 t2.micro (free tier):    $0/month (first 12 months)
# EBS 30GB gp3 (free tier):    $0/month (first 12 months)
# Elastic IP:                  $0 (attached to running instance)
# S3 (backups):                ~$0.02/month
# ──────────────────────────────────────────────────────────────
# Estimated total:             ~$0/month (free tier)
