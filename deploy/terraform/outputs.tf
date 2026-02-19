output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (API endpoint)"
  value       = aws_eip.app.public_ip
}

output "frontend_url" {
  description = "CloudFront URL for the Flutter web frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_url" {
  description = "API base URL"
  value       = "http://${aws_eip.app.public_ip}/api/v1/"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_bucket_name" {
  description = "S3 bucket name for frontend files"
  value       = aws_s3_bucket.frontend.id
}

output "backup_bucket_name" {
  description = "S3 bucket name for database backups"
  value       = aws_s3_bucket.backups.id
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ec2-user@${aws_eip.app.public_ip}"
}

# ─── Cost Estimate ────────────────────────────────────────────
# EC2 t4g.small (on-demand):   ~$12.26/month
# EBS 20GB gp3:                ~$1.60/month
# Elastic IP:                  $0 (attached)
# S3 (frontend + backups):     ~$0.10/month
# CloudFront (free tier):      $0/month (first 1TB)
# ──────────────────────────────────────────────────────────────
# Estimated total:             ~$14/month
