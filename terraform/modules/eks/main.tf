terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Skeleton only — do not use this as a production EKS definition.
#
# Replace the body of this module with e.g. terraform-aws-modules/eks/aws
# (managed node groups, cluster add-ons, OIDC provider, IRSA for the AWS
# Load Balancer Controller and ECR pull).
#
# Expected end state for IVXV:
#   - private worker nodes
#   - public NLB only in front of the proxy Service (see k8s/overlays/aws)
#   - node/IRSA rights to pull from ECR repositories created by modules/ecr

locals {
  # Kept so terraform plan still evaluates inputs while the real cluster
  # resources are being filled in.
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids
}
