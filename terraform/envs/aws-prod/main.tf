terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # backend "s3" {
  #   bucket = "ivxv-terraform-state"
  #   key    = "aws-prod/terraform.tfstate"
  #   region = "eu-north-1"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "ivxv"
      Environment = "aws-prod"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  services = [
    "proxy",
    "choices",
    "voting",
    "verification",
    "storage",
    "sessionstatus",
    "mid",
    "smartid",
    "webeid",
    "votesorder",
    "xroad-service",
    "collector-admin",
  ]

  ecr_names = [for s in local.services : "ivxv/${s}"]
}

module "network" {
  source = "../../modules/network"

  name = "${var.name_prefix}-prod"
  cidr = var.vpc_cidr
  azs  = var.azs

  tags = {
    Environment = "aws-prod"
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names     = local.ecr_names
  image_tag_mutability = "IMMUTABLE"

  tags = {
    Environment = "aws-prod"
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${var.name_prefix}-prod"
  cluster_version = var.cluster_version
  vpc_id          = module.network.vpc_id
  subnet_ids      = concat(module.network.private_subnet_ids, module.network.public_subnet_ids)

  tags = {
    Environment = "aws-prod"
  }
}
