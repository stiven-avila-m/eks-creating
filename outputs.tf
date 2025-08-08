/*
 * Outputs expose useful information about the created EKS cluster.  A
 * kubeconfig file can be used by `kubectl` or other clients to
 * connect to the cluster.  Exposing the Fargate profile ARN
 * allows referencing it from other modules if necessary.
 */

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster access"
  value       = module.eks.cluster_certificate_authority_data
}

output "kubeconfig" {
  description = "Kubeconfig file content for connecting to the cluster"
  value       = module.eks.kubeconfig
  sensitive   = true
}

output "fargate_profile_arn" {
  description = "Amazon Resource Name (ARN) of the Fargate profile"
  value       = module.eks.fargate_profiles["fargate"].fargate_profile_arn
}