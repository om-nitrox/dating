###############################################################################
# ECS Fargate module — cluster + api service + worker service.
#
# Status: STUB. Task definitions are minimal — they reference Secrets Manager
# entries by ARN but do NOT contain a complete environment variable list yet.
# The ALB / target groups / listener / ACM cert are NOT in this module.
#
# What's intentionally missing (Phase-1.16):
#   - ALB + target group + HTTPS listener (needs ACM cert + Route53)
#   - Autoscaling policies (target tracking on CPU/mem)
#   - CloudWatch alarms (5xx rate, queue depth, deploy circuit breaker)
#   - X-Ray / OpenTelemetry sidecar
###############################################################################

variable "name"                    { type = string }
variable "vpc_id"                  { type = string }
variable "private_subnet_ids"      { type = list(string) }
variable "public_subnet_ids"       { type = list(string) }
variable "api_sg_id"               { type = string }
variable "worker_sg_id"            { type = string }
variable "api_image_repo_url"      { type = string }
variable "worker_image_repo_url"   { type = string }
variable "image_tag"               { type = string }
variable "redis_endpoint"          { type = string }
variable "secrets_arns"            { type = map(string) }  # name → arn

###############################################################################
# Cluster
###############################################################################

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

###############################################################################
# CloudWatch log groups
###############################################################################

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.name}-api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.name}-worker"
  retention_in_days = 30
}

###############################################################################
# IAM — execution role (ECR pull + Secrets Manager) and task role.
###############################################################################

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow execution role to read the Secrets Manager entries we reference.
resource "aws_iam_role_policy" "execution_secrets" {
  name = "${var.name}-execution-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = values(var.secrets_arns)
    }]
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# TODO(Phase-1.16): attach least-privilege task-role policies for whatever
# AWS services the running container needs (S3, SES, etc.). Right now,
# nothing — Cloudinary/Stripe/Atlas are all external HTTPS.

###############################################################################
# Helper — build the `secrets` block for the task definition from the
# secrets_arns map. The container reads them as plain env vars at start.
###############################################################################

locals {
  secret_env = [
    for name, arn in var.secrets_arns : {
      name      = name
      valueFrom = arn
    }
  ]

  common_env = [
    { name = "NODE_ENV",   value = "production" },
    { name = "REDIS_URL",  value = "redis://${var.redis_endpoint}:6379" },
    { name = "PORT",       value = "5000" },
  ]
}

###############################################################################
# Task definition — api
###############################################################################

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name}-api"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${var.api_image_repo_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]

    environment = local.common_env
    secrets     = local.secret_env

    healthCheck = {
      command  = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5000/health || exit 1"]
      interval = 30
      timeout  = 5
      retries  = 3
      startPeriod = 15
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

###############################################################################
# Task definition — worker
#
# No port mapping. Exposes :9091 internally for /metrics if the worker image
# adds it; that's discoverable via service discovery, not load-balanced.
###############################################################################

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.name}-worker"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "${var.worker_image_repo_url}:${var.image_tag}"
    essential = true

    environment = local.common_env
    secrets     = local.secret_env

    # Metrics port (internal only). Surfaced for future Prometheus scrape.
    portMappings = [{
      containerPort = 9091
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.worker.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "worker"
      }
    }
  }])
}

data "aws_region" "current" {}

###############################################################################
# Services
###############################################################################

resource "aws_ecs_service" "api" {
  name            = "${var.name}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.api_sg_id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # TODO(Phase-1.16): attach to ALB target group via load_balancer block.
  # Until then the service runs but is unreachable from the internet.

  lifecycle {
    # Force-new-deployment from CI shouldn't fight Terraform.
    ignore_changes = [desired_count, task_definition]
  }
}

resource "aws_ecs_service" "worker" {
  name            = "${var.name}-worker"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.worker_sg_id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}

###############################################################################
# Outputs
###############################################################################

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "api_service_name" {
  value = aws_ecs_service.api.name
}

output "worker_service_name" {
  value = aws_ecs_service.worker.name
}

output "api_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "worker_log_group" {
  value = aws_cloudwatch_log_group.worker.name
}
