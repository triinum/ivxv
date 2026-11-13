output "cluster_name" {
  description = "EKS cluster name (wire to real aws_eks_cluster when module is completed)"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Placeholder until real EKS resource exists"
  value       = null
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${var.cluster_name}"
}
