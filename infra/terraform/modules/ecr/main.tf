###############################################################################
# ECR module — one repository per service.
#
# Lifecycle policy keeps the 10 most-recent untagged images plus anything
# explicitly tagged "staging" or "prod" (those are kept forever — they're
# the rollback targets).
###############################################################################

variable "repositories" {
  description = "List of repository names to create"
  type        = list(string)
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = each.key
  image_tag_mutability = "MUTABLE"  # we re-tag :staging on every deploy
  force_delete         = false      # safety — flip only when truly empty

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain images tagged staging or prod"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging", "prod"]
          countType     = "imageCountMoreThan"
          countNumber   = 9999
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 sha-tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "repository_urls" {
  description = "Map of repo name → repository URL"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repo name → repository ARN"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}
