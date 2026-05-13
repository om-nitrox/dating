###############################################################################
# Reverse Match — Staging environment root
#
# This file wires together the reusable modules under ../modules/. It is a
# STUB: variable values are intentionally placeholder, and a number of
# resources (Atlas peering, ALB+ACM, Route53 records) are not yet stubbed.
# See ../README.md for the apply order and what is intentionally missing.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Remote state in S3 + DynamoDB lock. The bucket and table must exist
  # BEFORE `terraform init` — see ../README.md "Bootstrap".
  backend "s3" {
    bucket         = "TODO-reverse-match-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "TODO-aws-region"
    dynamodb_table = "TODO-reverse-match-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "reverse-match"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

###############################################################################
# Inputs
###############################################################################

variable "aws_region" {
  description = "AWS region for staging (e.g. us-east-1)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the staging VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "atlas_peering_cidr" {
  description = "CIDR of the MongoDB Atlas peer VPC. TODO once Atlas project exists."
  type        = string
  default     = "192.168.248.0/21"
}

###############################################################################
# Network
###############################################################################

module "network" {
  source = "../modules/network"

  name               = "reverse-match-staging"
  vpc_cidr           = var.vpc_cidr
  azs                = ["${var.aws_region}a", "${var.aws_region}b"]
  atlas_peering_cidr = var.atlas_peering_cidr
}

###############################################################################
# Container registry
###############################################################################

module "ecr" {
  source = "../modules/ecr"

  repositories = ["reverse-match-api", "reverse-match-worker"]
}

###############################################################################
# Secrets (Secrets Manager entries — empty placeholders, see README)
###############################################################################

module "secrets" {
  source = "../modules/secrets"

  name_prefix = "reverse-match/staging"
}

###############################################################################
# Redis (ElastiCache, cluster-mode-disabled, single node)
###############################################################################

module "redis" {
  source = "../modules/elasticache"

  name               = "reverse-match-staging"
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.redis_sg_id]
}

###############################################################################
# ECS Fargate — api + worker services
###############################################################################

module "ecs" {
  source = "../modules/ecs-fargate"

  name               = "reverse-match-staging"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  api_sg_id          = module.network.api_sg_id
  worker_sg_id       = module.network.worker_sg_id

  api_image_repo_url    = module.ecr.repository_urls["reverse-match-api"]
  worker_image_repo_url = module.ecr.repository_urls["reverse-match-worker"]
  image_tag             = "staging"

  redis_endpoint = module.redis.primary_endpoint
  secrets_arns   = module.secrets.secret_arns
}

###############################################################################
# Outputs
###############################################################################

output "vpc_id" {
  value = module.network.vpc_id
}

output "ecr_api_url" {
  value = module.ecr.repository_urls["reverse-match-api"]
}

output "ecr_worker_url" {
  value = module.ecr.repository_urls["reverse-match-worker"]
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "api_service_name" {
  value = module.ecs.api_service_name
}

output "worker_service_name" {
  value = module.ecs.worker_service_name
}
