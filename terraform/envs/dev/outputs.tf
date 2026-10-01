output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "Put this in the GitHub secret AWS_ROLE_ARN"
  value       = module.github_oidc.role_arn
}

output "terraform_role_arn" {
  description = "Put this in the GitHub secret TF_ROLE_ARN"
  value       = module.github_oidc.terraform_role_arn
}
