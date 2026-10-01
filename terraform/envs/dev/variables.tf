variable "project" {
  type    = string
  default = "shopstack"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT (SPOT is ~70% cheaper, fine for dev)"
  type        = string
  default     = "SPOT"
}

variable "github_repo" {
  description = "GitHub repo allowed to deploy, e.g. dhruvit/shopstack"
  type        = string
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "install_argocd" {
  description = "Install Argo CD for GitOps deployments (advanced track)"
  type        = bool
  default     = true
}
