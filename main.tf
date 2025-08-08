/*
 * Terraform configuration to provision an Amazon EKS cluster using
 * community modules.  This example creates a basic VPC, an EKS
 * control plane, an Amazon‑managed node group and a Fargate profile.
 *
 * The configuration makes use of the `terraform‑aws‑modules/vpc/aws`
 * module to build networking and the `terraform‑aws‑modules/eks/aws`
 * module to manage the Kubernetes control plane, worker nodes and
 * Fargate.  Creating an EKS cluster with Fargate reduces the
 * operational overhead of managing EC2 instance fleets – AWS runs
 * and scales the underlying compute so you only need to define pod
 * CPU/memory requests【45524217774765†L84-L92】【45524217774765†L165-L171】.  Fargate nodes are
 * fully managed; you don’t choose instance types or AMIs because
 * AWS provisions appropriately sized compute based on pod resource
 * requests【45524217774765†L157-L170】.
 */

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

/*
 * Configure the AWS provider.  The region is parameterised via
 * variables so that you can easily deploy to different regions.
 */
provider "aws" {
  region = var.region
}

/*
 * Retrieve a list of availability zones in the target region.  The
 * VPC module expects a list of AZs when you specify custom subnet
 * CIDR blocks.  Using a data source ensures your configuration
 * adapts automatically to the selected region.
 */
data "aws_availability_zones" "available" {}

/*
 * Networking: create a VPC with public and private subnets.  The
 * EKS control plane and managed node groups will use the private
 * subnets.  NAT gateways are enabled to allow outgoing internet
 * access from private subnets.  Adjust the CIDR ranges as
 * necessary for your environment.
 */
module "vpc" {
  source  = "terraform‑aws‑modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names[0:3]
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

/*
 * EKS cluster: create the control plane, managed node group and
 * optional Fargate profile.  The `terraform‑aws‑modules/eks/aws`
 * module provides sensible defaults and simplifies the creation
 * of EKS clusters.  We set `manage_aws_auth_configmap` to true so
 * Terraform writes the ConfigMap that gives the current IAM
 * identity cluster admin rights.  Node groups specify instance
 * types and sizes; in this example we create a single managed
 * node group with two `t3.medium` instances.  A Fargate profile is
 * defined for the `fargate` namespace with a `Env = "fargate"`
 * label so that pods using this namespace/label are scheduled on
 * Fargate rather than EC2 instances【45524217774765†L176-L184】.
 */
data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform‑aws‑modules/eks/aws"
  version = "~> 19.0"

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

  /*
   * Managed node groups: one group with two t3.medium instances.
   * `desired_size` determines how many nodes are provisioned at
   * cluster creation.  `min_size` and `max_size` control auto
   * scaling boundaries.  Labels are arbitrary key/value pairs
   * applied to the Kubernetes nodes.
   */
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

  /*
   * Fargate profile: defines how pods are selected for Fargate.
   * Only pods running in the `fargate` namespace with the
   * `Env = "fargate"` label will be scheduled onto Fargate.
   */
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
