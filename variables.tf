variable "cluster_name" {
  description = "Name of the EKS cluster and associated resources"
  type        = string
}

variable "region" {
  description = "AWS region in which to deploy the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS control plane"
  type        = string
  default     = "1.29"
}

variable "environment" {
  description = "Deployment environment tag (e.g. dev, test, prod)"
  type        = string
  default     = "dev"
}