terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Skeleton: minimal VPC. Replace with terraform-aws-modules/vpc/aws or your
# organisation's network module before production use.

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

# Placeholder public subnet (first AZ only if provided). Expand for HA.
resource "aws_subnet" "public" {
  count = length(var.azs) > 0 ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 4, 0)
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.name}-public-0"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count = length(var.azs) > 0 ? 1 : 0

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, 4, 8)
  availability_zone = var.azs[0]

  tags = merge(var.tags, {
    Name                              = "${var.name}-private-0"
    "kubernetes.io/role/internal-elb" = "1"
  })
}
