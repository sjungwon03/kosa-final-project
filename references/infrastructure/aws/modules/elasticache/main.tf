variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

resource "aws_elasticache_subnet_group" "kosa_redis_subnet" {
  name       = "${var.cluster_name}-redis-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.environment
    Project     = "kosa"
  }
}

resource "aws_security_group" "elasticache_sg" {
  name        = "${var.cluster_name}-elasticache-sg"
  description = "Security Group for ElastiCache"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = var.security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = "kosa"
  }
}

resource "aws_elasticache_replication_group" "kosa_redis" {
  replication_group_id          = "${var.cluster_name}-redis"
  replication_group_description = "Redis cluster for KOSA"

  engine                        = "redis"
  engine_version                = "7.0"
  node_type                     = "cache.r5.large"
  number_cache_clusters         = 2
  port                          = 6379

  subnet_group_name             = aws_elasticache_subnet_group.kosa_redis_subnet.name
  security_group_ids            = [aws_security_group.elasticache_sg.id]

  automatic_failover_enabled    = true
  multi_az_enabled              = true

  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true

  tags = {
    Environment = var.environment
    Project     = "kosa"
  }
}

output "endpoint" {
  value = aws_elasticache_replication_group.kosa_redis.primary_endpoint_address
}

output "reader_endpoint" {
  value = aws_elasticache_replication_group.kosa_redis.reader_endpoint_address
}

output "cluster_id" {
  value = aws_elasticache_replication_group.kosa_redis.replication_group_id
}