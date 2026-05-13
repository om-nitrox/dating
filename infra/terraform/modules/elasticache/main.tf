###############################################################################
# ElastiCache module — Redis, cluster-mode-disabled, single node.
#
# Sized for staging (cache.t4g.micro). Production sizing is a Phase-1.16
# decision once we have real socket connection counts.
###############################################################################

variable "name"               { type = string }
variable "subnet_ids"         { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "node_type" {
  type    = string
  default = "cache.t4g.micro"
}
variable "engine_version" {
  type    = string
  default = "7.1"
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id        = "${var.name}-redis"
  description                 = "Reverse Match staging Redis (single node)"
  engine                      = "redis"
  engine_version              = var.engine_version
  node_type                   = var.node_type
  num_cache_clusters          = 1
  parameter_group_name        = "default.redis7"
  port                        = 6379
  subnet_group_name           = aws_elasticache_subnet_group.this.name
  security_group_ids          = var.security_group_ids
  automatic_failover_enabled  = false
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = false  # staging only; flip to true for prod
  apply_immediately           = true
  snapshot_retention_limit    = 1

  # TODO(Phase-1.16): enable transit encryption, set auth_token, bump to
  # multi-AZ + 2 nodes for production.
}

output "primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "replication_group_id" {
  value = aws_elasticache_replication_group.this.id
}
