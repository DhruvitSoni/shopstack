data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
}

# ---------------------------------------------------------------- Networking
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name            = local.name
  cidr            = var.vpc_cidr
  azs             = local.azs
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 48 + i)]

  enable_nat_gateway = true
  single_nat_gateway = true # one NAT for dev saves ~$65/month; use one per AZ in prod

  # Tags that let Kubernetes place load balancers in the right subnets
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

# ---------------------------------------------------------------- EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = {}
    aws-ebs-csi-driver     = { service_account_role_arn = module.ebs_csi_irsa.iam_role_arn }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      min_size       = 2
      max_size       = 5
      desired_size   = 2
    }
  }

  # Allow the GitHub Actions role to deploy into the cluster
  access_entries = {
    github_actions = {
      principal_arn = module.github_oidc.role_arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    github_terraform = {
      principal_arn = module.github_oidc.terraform_role_arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name             = "${local.name}-ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# gp3 default StorageClass (used by Postgres and Prometheus volumes)
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name        = "gp3"
    annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  parameters             = { type = "gp3", encrypted = "true" }

  depends_on = [module.eks]
}

# ---------------------------------------------------------------- Registry + CI access
module "ecr" {
  source       = "../../modules/ecr"
  project      = var.project
  repositories = ["frontend", "product-service", "order-service"]
}

module "github_oidc" {
  source              = "../../modules/github-oidc"
  project             = "${var.project}-${var.environment}"
  github_repo         = var.github_repo
  ecr_repository_arns = module.ecr.repository_arns
  eks_cluster_arn     = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.name}"
}

data "aws_caller_identity" "current" {}
