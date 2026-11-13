output "repository_urls" {
  description = "Map of repository name → repository URL"
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "registry_id" {
  value = values(aws_ecr_repository.service)[0].registry_id
}
