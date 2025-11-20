########################################
# IAM ROLES
########################################

# EC2 General Role
resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_full" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


########################################
# VPC MODULE
########################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  name = "${var.project}-vpc"
  cidr = "10.10.0.0/16"

  azs             = ["us-west-1a", "us-west-1c"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.3.0/24", "10.10.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Project = var.project
  }
}

########################################
# EKS IAM ROLES
########################################

# Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_VPCResourceController" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_VPC_ResourceController"
}


# Worker Node Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ReadOnlyECR" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


########################################
# IRSA FOR EBS CSI DRIVER
########################################

module "irsa_ebs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name               = "${var.project}-ebs-csi-role"
  attach_ebs_csi_policy   = true
  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


########################################
# EKS MODULE
########################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_role_arn = aws_iam_role.eks_cluster_role.arn

  eks_managed_node_group_defaults = {
    instance_types = ["t3.small"]
    iam_role_arn   = aws_iam_role.eks_node_role.arn
  }

  eks_managed_node_groups = {
    node_group_1 = {
      desired_size = 2
      min_size     = 1
      max_size     = 3
    }

    node_group_2 = {
      desired_size = 1
      min_size     = 1
      max_size     = 2
    }
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa_ebs_csi.iam_role_arn
    }
  }
}


########################################
# ECR Repository
########################################

resource "aws_ecr_repository" "repo" {
  name                 = "${var.project}-repo"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_tag_mutability_exclusion_filter {
    filter      = "latest*"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "dev-*"
    filter_type = "WILDCARD"
  }
}


########################################
# DynamoDB Table With Replication
########################################

resource "aws_dynamodb_table" "example" {
  name             = "${var.project}-ddb"
  hash_key         = "TestKey"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "TestKey"
    type = "S"
  }

  replica {
    region_name = "us-west-1"
  }

  replica {
    region_name = "us-east-1"
  }
}


########################################
# CLOUDWATCH OBSERVABILITY ADDON
########################################

resource "aws_iam_role" "cloudwatch_role" {
  name = "${var.project}-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cw_policy" {
  role       = aws_iam_role.cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  pod_identity_associations {
    roleArn        = aws_iam_role.cloudwatch_role.arn
    serviceAccount = "cloudwatch-agent"
  }
}
