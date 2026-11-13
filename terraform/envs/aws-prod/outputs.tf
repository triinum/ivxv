output "region" {
  value = var.region
}

output "ecr_registry" {
  description = "Pass to Ansible as ecr_registry"
  value       = "${module.ecr.registry_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "configure_kubectl" {
  value = module.eks.configure_kubectl
}
