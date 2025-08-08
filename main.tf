terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.8.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs =             slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Terraform   = "true"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.kubernetes_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = data.aws_caller_identity.current.arn
      username = "admin"
      groups   = ["system:masters"]
    }
  ]

  enable_irsa = true

  eks_managed_node_groups = {
    node_group = {
      desired_size   = 2
      min_size       = 1
      max_size       = 2
      instance_types = ["t3.medium"]

      labels = {
        Environment = var.environment
        NodeGroup   = "managed"
      }
    }
  }

  fargate_profiles = {
    fargate = {
      selectors = [
        {
          namespace = "fargate"
          labels = {
            Env = "fargate"
          }
        }
      ]
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Cluster     = var.cluster_name
  }
}
