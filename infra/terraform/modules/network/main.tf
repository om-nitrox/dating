###############################################################################
# Network module — VPC + public/private subnets + NAT + security groups.
#
# Status: STUB. The shape is real but values (CIDR, AZ list) are minimal.
# Atlas connectivity is left as a TODO — choose between PrivateLink and
# VPC peering once the Atlas project exists.
###############################################################################

variable "name" {
  description = "Name prefix for all network resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to use (need at least 2)"
  type        = list(string)
}

variable "atlas_peering_cidr" {
  description = "CIDR of the MongoDB Atlas peer VPC. Used in egress rules."
  type        = string
}

###############################################################################
# VPC + subnets
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${var.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name}-private-${var.azs[count.index]}"
    Tier = "private"
  }
}

###############################################################################
# Internet + NAT
###############################################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

# Single NAT for staging cost control. Use one-per-AZ in production.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# Security groups
#
# api  — ingress :5000 from the ALB SG (ALB itself is NOT in this module yet)
# worker — no ingress; egress only
# redis — ingress :6379 from api SG + worker SG
###############################################################################

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB ingress 443/80 from the internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirect to HTTPS at the listener)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb-sg" }
}

resource "aws_security_group" "api" {
  name        = "${var.name}-api"
  description = "API service — ingress from ALB only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "From ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-api-sg" }
}

resource "aws_security_group" "worker" {
  name        = "${var.name}-worker"
  description = "Worker service — egress only, no ingress"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-worker-sg" }
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis"
  description = "Redis — ingress from api + worker only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "From api"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  ingress {
    description     = "From worker"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.worker.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-redis-sg" }
}

###############################################################################
# TODO(Phase-1.16): MongoDB Atlas connectivity.
#
# Atlas connects in one of two ways:
#   (a) VPC peering — cheaper, requires the atlas_peering_cidr input above
#       plus an aws_vpc_peering_connection resource and route table entries.
#   (b) PrivateLink — more expensive but no overlapping-CIDR headaches.
#
# Either way: this is not stubbed yet. Pick one in Phase 1 and wire it.
###############################################################################

###############################################################################
# Outputs
###############################################################################

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "api_sg_id" {
  value = aws_security_group.api.id
}

output "worker_sg_id" {
  value = aws_security_group.worker.id
}

output "redis_sg_id" {
  value = aws_security_group.redis.id
}
